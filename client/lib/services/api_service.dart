import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../config.dart';
import '../models/problem.dart';

class ApiService {
  final Dio _dio;

  ApiService() : _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<List<Problem>> getProblems({String? difficulty, String? tag}) async {
    final params = <String, dynamic>{};
    if (difficulty != null && difficulty.isNotEmpty) params['difficulty'] = difficulty;
    if (tag != null && tag.isNotEmpty) params['tag'] = tag;

    final resp = await _dio.get('/api/v1/problems', queryParameters: params);
    return (resp.data as List).map((j) => Problem.fromJson(j)).toList();
  }

  Future<Problem> getProblemDetail(String id) async {
    final resp = await _dio.get('/api/v1/problems/$id');
    return Problem.fromJson(resp.data);
  }

  Stream<Map<String, dynamic>> analyzeStream(String text) async* {
    final resp = await _dio.post(
      '/api/v1/analyze',
      data: {'text': text},
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    final stream = resp.data.stream as Stream<List<int>>;
    String buffer = '';
    String currentEvent = '';

    await for (final chunk in stream) {
      buffer += utf8.decode(chunk);
      while (buffer.contains('\n')) {
        final newline = buffer.indexOf('\n');
        final line = buffer.substring(0, newline).trim();
        buffer = buffer.substring(newline + 1);

        if (line.startsWith('event:')) {
          currentEvent = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          final data = jsonDecode(line.substring(5).trim());
          data['_event'] = currentEvent;
          yield data;
          currentEvent = '';
        }
      }
    }
  }

  Future<String> transcribeAudio(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
    });

    final resp = await _dio.post(
      '/api/v1/transcribe',
      data: formData,
      options: Options(responseType: ResponseType.json),
    );

    if (resp.data is Map && resp.data['text'] != null) {
      return resp.data['text'] as String;
    }
    if (resp.data is Map && resp.data['error'] != null) {
      throw Exception(resp.data['error'] as String);
    }
    throw Exception('Transcription failed');
  }

  Future<Map<String, dynamic>> analyzeAudio(String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
    });

    final resp = await _dio.post(
      '/api/v1/analyze/audio',
      data: formData,
      options: Options(responseType: ResponseType.json),
    );

    // If it's a direct JSON response (error), return it
    if (resp.data is Map && resp.data['error'] != null) {
      return resp.data;
    }

    // If ASR returned text, start SSE analysis
    if (resp.data is Map && resp.data['text'] != null) {
      return {'status': 'transcribed', 'text': resp.data['text']};
    }

    return {'status': 'ok'};
  }

  Stream<Map<String, dynamic>> analyzeAudioStream(String filePath) async* {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'recording.m4a'),
    });

    final resp = await _dio.post(
      '/api/v1/analyze/audio',
      data: formData,
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
    );

    // If SSE stream, parse it
    if (resp.headers.value('content-type')?.contains('text/event-stream') == true) {
      final stream = resp.data.stream as Stream<List<int>>;
      String buffer = '';
      String currentEvent = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        while (buffer.contains('\n')) {
          final newline = buffer.indexOf('\n');
          final line = buffer.substring(0, newline).trim();
          buffer = buffer.substring(newline + 1);

          if (line.startsWith('event:')) {
            currentEvent = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            final data = jsonDecode(line.substring(5).trim());
            data['_event'] = currentEvent;
            yield data;
            currentEvent = '';
          }
        }
      }
    } else {
      // Error response
      yield {'_event': 'error', 'error': 'ASR failed'};
    }
  }

  Future<Map<String, dynamic>> healthCheck() async {
    final resp = await _dio.get('/api/v1/health');
    return resp.data;
  }
}
