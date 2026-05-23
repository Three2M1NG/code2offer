import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis_result.dart';
import '../services/api_service.dart';
import 'problem_provider.dart';

class AnalysisState {
  final bool loading;
  final String? error;
  final String? matchedProblem;
  final String? problemDifficulty;
  final double? similarity;
  final String streamedText;
  final AnalysisResult? result;

  const AnalysisState({
    this.loading = false,
    this.error,
    this.matchedProblem,
    this.problemDifficulty,
    this.similarity,
    this.streamedText = '',
    this.result,
  });

  AnalysisState copyWith({
    bool? loading,
    String? error,
    String? matchedProblem,
    String? problemDifficulty,
    double? similarity,
    String? streamedText,
    AnalysisResult? result,
    bool clearError = false,
    bool clearResult = false,
  }) {
    return AnalysisState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      matchedProblem: matchedProblem ?? this.matchedProblem,
      problemDifficulty: problemDifficulty ?? this.problemDifficulty,
      similarity: similarity ?? this.similarity,
      streamedText: streamedText ?? this.streamedText,
      result: clearResult ? null : (result ?? this.result),
    );
  }
}

class AnalysisNotifier extends StateNotifier<AnalysisState> {
  final ApiService _api;

  AnalysisNotifier(this._api) : super(const AnalysisState());

  Future<void> analyze(String text, {String? problemId}) async {
    state = const AnalysisState(loading: true, streamedText: '');
    final dimensions = <DimensionScore>[];
    String summary = '';
    double overallScore = 0;

    try {
      final stream = _api.analyzeStream(text, problemId: problemId);
      await for (final event in stream) {
        final type = event['_event'] as String? ?? '';

        switch (type) {
          case 'match':
            state = state.copyWith(
              matchedProblem: event['problem'] as String?,
              similarity: (event['similarity'] as num?)?.toDouble(),
              problemDifficulty: event['difficulty'] as String?,
            );
            break;
          case 'info':
            state = state.copyWith(
              loading: false,
              error: event['message'] as String? ?? 'No matching problem found',
            );
            return;
          case 'chunk':
            state = state.copyWith(
              streamedText: state.streamedText + (event['content'] as String? ?? ''),
            );
            break;
          case 'dimension':
            dimensions.add(DimensionScore.fromJson(event));
            break;
          case 'done':
            overallScore = (event['overall_score'] as num?)?.toDouble() ?? 0;
            summary = event['summary'] as String? ?? '';
            break;
          case 'error':
            state = state.copyWith(
              loading: false,
              error: event['error'] as String? ?? 'Unknown error',
              clearResult: true,
            );
            return;
        }
      }

      state = state.copyWith(
        loading: false,
        result: AnalysisResult(
          overallScore: overallScore,
          summary: summary,
          dimensions: dimensions.isNotEmpty ? dimensions : _parseFromText(state.streamedText),
          problemTitle: state.matchedProblem,
          problemDifficulty: state.problemDifficulty,
        ),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: 'Network error: ${e.toString()}',
        clearResult: true,
      );
    }
  }

  List<DimensionScore> _parseFromText(String text) {
    // Fallback: try to find scores in raw text
    final dimensions = <DimensionScore>[];
    final patterns = {
      'correctness': 'Correctness',
      'complexity': 'Complexity',
      'clarity': 'Clarity',
      'edge_cases': 'Edge Cases',
      'delivery': 'Delivery',
    };
    for (final entry in patterns.entries) {
      final regex = RegExp(r'"' + entry.key + r'".*?"score"\s*:\s*(\d+)', multiLine: true);
      final match = regex.firstMatch(text);
      if (match != null) {
        dimensions.add(DimensionScore(
          name: entry.value,
          nameEn: entry.key,
          score: int.parse(match.group(1)!),
          maxScore: 10,
          weight: 20,
          comment: '',
          suggestion: '',
        ));
      }
    }
    return dimensions;
  }

  Future<void> analyzeAudio(String filePath, {String? problemId}) async {
    state = const AnalysisState(loading: true, streamedText: '');
    final dimensions = <DimensionScore>[];
    String summary = '';
    double overallScore = 0;

    try {
      final stream = _api.analyzeAudioStream(filePath, problemId: problemId);
      await for (final event in stream) {
        final type = event['_event'] as String? ?? '';

        switch (type) {
          case 'match':
            state = state.copyWith(
              matchedProblem: event['problem'] as String?,
              similarity: (event['similarity'] as num?)?.toDouble(),
              problemDifficulty: event['difficulty'] as String?,
            );
            break;
          case 'info':
            state = state.copyWith(
              loading: false,
              error: event['message'] as String? ?? 'No matching problem found',
            );
            return;
          case 'chunk':
            state = state.copyWith(
              streamedText: state.streamedText + (event['content'] as String? ?? ''),
            );
            break;
          case 'dimension':
            dimensions.add(DimensionScore.fromJson(event));
            break;
          case 'done':
            overallScore = (event['overall_score'] as num?)?.toDouble() ?? 0;
            summary = event['summary'] as String? ?? '';
            break;
          case 'error':
            state = state.copyWith(loading: false, error: event['error'] as String? ?? 'ASR failed', clearResult: true);
            return;
        }
      }

      state = state.copyWith(
        loading: false,
        result: AnalysisResult(
          overallScore: overallScore,
          summary: summary,
          dimensions: dimensions.isNotEmpty ? dimensions : _parseFromText(state.streamedText),
          problemTitle: state.matchedProblem,
          problemDifficulty: state.problemDifficulty,
        ),
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: 'Audio upload failed: ${e.toString()}', clearResult: true);
    }
  }

  void reset() {
    state = const AnalysisState();
  }
}

final analysisProvider = StateNotifierProvider.autoDispose<AnalysisNotifier, AnalysisState>((ref) {
  final api = ref.watch(apiServiceProvider);
  return AnalysisNotifier(api);
});
