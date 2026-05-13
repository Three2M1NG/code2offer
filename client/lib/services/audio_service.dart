import 'dart:async';
import 'dart:io';

import 'package:record/record.dart' as record;

class AudioRecorder {
  final _recorder = record.AudioRecorder();
  StreamSubscription<record.Amplitude>? _ampSub;

  double currentAmplitude = 0.0;
  bool isRecording = false;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start({
    void Function(double amplitude)? onAmplitude,
  }) async {
    if (await _recorder.hasPermission()) {
      final config = const record.RecordConfig(
        encoder: record.AudioEncoder.aacLc,
        sampleRate: 16000,
        numChannels: 1,
      );

      final tempDir = Directory.systemTemp;
      final path = '${tempDir.path}/code2offer_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(config, path: path);

      _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((amp) {
        currentAmplitude = (amp.current + amp.max) / 2;
        onAmplitude?.call(currentAmplitude);
      });

      isRecording = true;
    }
  }

  Future<String?> stop() async {
    isRecording = false;
    _ampSub?.cancel();
    final path = await _recorder.stop();
    return path;
  }

  Future<void> dispose() async {
    _ampSub?.cancel();
    await _recorder.dispose();
  }
}
