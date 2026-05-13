import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/analysis_provider.dart';
import '../providers/history_provider.dart';
import '../providers/problem_provider.dart';
import '../services/audio_service.dart';
import '../services/connectivity_service.dart';
import '../services/history_service.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/dimension_card.dart';
import '../widgets/shimmer_loading.dart';

class AnalysisPage extends ConsumerStatefulWidget {
  final String problemId;

  const AnalysisPage({super.key, required this.problemId});

  @override
  ConsumerState<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends ConsumerState<AnalysisPage> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  final _audioRecorder = AudioRecorder();
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFlipped = false;
  bool _isRecording = false;
  bool _awaitingTranscribe = false;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(duration: const Duration(milliseconds: 400), vsync: this);
    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _flipController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _textController.dispose();
    _flipController.dispose();
    unawaited(_audioRecorder.dispose());
    super.dispose();
  }

  void _flipCard() {
    if (_isFlipped) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    _isFlipped = !_isFlipped;
  }

  void _saveToHistory(WidgetRef ref, AnalysisState state) {
    final result = state.result;
    if (result == null) return;
    final entry = HistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      problemTitle: result.problemTitle ?? state.matchedProblem ?? 'Unknown',
      problemDifficulty: result.problemDifficulty,
      overallScore: result.overallScore,
      summary: result.summary,
      dimensions: result.dimensions,
      userInput: _textController.text.trim(),
      createdAt: DateTime.now(),
    );
    ref.read(historyProvider.notifier).addEntry(entry);
  }

  void _shareResult(AnalysisState state) {
    final result = state.result;
    if (result == null) return;
    final buffer = StringBuffer();
    buffer.writeln('code2offer - AI Algorithm Coach');
    buffer.writeln('${result.problemTitle ?? "Problem"} (${result.problemDifficulty ?? ""})');
    buffer.writeln('Overall Score: ${result.overallScore.toStringAsFixed(1)}/10');
    buffer.writeln();
    for (final d in result.dimensions) {
      buffer.writeln('${d.name}: ${d.score}/${d.maxScore} (weight: ${d.weight}%)');
      if (d.comment.isNotEmpty) buffer.writeln('  ${d.comment}');
      if (d.suggestion.isNotEmpty) buffer.writeln('  ${d.suggestion}');
    }
    if (result.summary.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(result.summary);
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Evaluation copied to clipboard'), duration: Duration(seconds: 2)),
    );
  }

  Future<void> _submit() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(analysisProvider.notifier).analyze(text);
    if (!_isFlipped) _flipCard();
  }

  Future<void> _startRecording() async {
    final ok = await _audioRecorder.hasPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
      return;
    }
    setState(() => _isRecording = true);
    await _audioRecorder.start(onAmplitude: (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _awaitingTranscribe = true;
    });

    final path = await _audioRecorder.stop();
    if (path == null) {
      setState(() => _awaitingTranscribe = false);
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      final text = await api.transcribeAudio(path);
      try { await File(path).delete(); } catch (_) {}
      if (mounted) {
        _textController.text = text;
        _textController.selection = TextSelection.collapsed(offset: text.length);
        setState(() => _awaitingTranscribe = false);
      }
    } catch (e) {
      try { await File(path).delete(); } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transcription failed: $e'), backgroundColor: Colors.red),
        );
        setState(() => _awaitingTranscribe = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final problemAsync = ref.watch(problemDetailProvider(widget.problemId));
    final analysisState = ref.watch(analysisProvider);
    final isOnline = ref.watch(connectivityProvider).valueOrNull ?? true;

    ref.listen(analysisProvider, (prev, next) {
      if (prev?.result == null && next.result != null) {
        _saveToHistory(ref, next);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Problem')),
      body: Column(children: [
        if (!isOnline)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Colors.orange.shade100,
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.wifi_off, size: 16, color: Colors.orange),
              SizedBox(width: 6),
              Text('No internet connection', style: TextStyle(color: Colors.orange, fontSize: 13)),
            ]),
          ),
        Expanded(child: problemAsync.when(
        loading: () => const Center(child: _ProblemLoadingSkeleton()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (problem) => SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _buildCard(problem, analysisState),
              const SizedBox(height: 16),

              // Input area
              if (!analysisState.loading && analysisState.result == null) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 4,
                      minLines: 2,
                      decoration: InputDecoration(
                        hintText: _awaitingTranscribe ? 'Transcribing...' : 'Describe your solution...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _textController.text.trim().isNotEmpty ? _submit : null,
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mic button
                  _MicButton(
                    isRecording: _isRecording,
                    amplitude: _audioRecorder.currentAmplitude,
                    onStart: _startRecording,
                    onStop: _stopRecording,
                  ),
                ]),
              ],

              // Loading
              if (analysisState.loading) ...[
                const SizedBox(height: 16),
                ShimmerLoading(height: 4, radius: 2),
                const SizedBox(height: 8),
                if (analysisState.streamedText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text(analysisState.streamedText, style: const TextStyle(fontSize: 13, height: 1.5)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('AI is evaluating...', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ]),
                  ),
              ],

              // Error
              if (analysisState.error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text(analysisState.error!, style: const TextStyle(color: Colors.red))),
                    TextButton(onPressed: _submit, child: const Text('Retry')),
                  ]),
                ),
              ],

              // Action buttons
              if (analysisState.result != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ref.read(analysisProvider.notifier).reset();
                          _textController.clear();
                          if (_isFlipped) _flipCard();
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Try Another'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _shareResult(analysisState),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      )),
    ]),
    );
  }

  Widget _buildCard(dynamic problem, AnalysisState state) {
    return GestureDetector(
      onTap: state.loading ? null : _flipCard,
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, child) {
          final angle = _flipAnimation.value * 3.14159;
          final isFront = _flipAnimation.value < 0.5;
          return SizedBox(
            height: 360,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateY(angle),
              child: isFront
                  ? _buildFront(problem)
                  : Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..rotateY(3.14159),
                      child: _buildBack(state),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFront(dynamic problem) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(problem.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
            DifficultyBadge(difficulty: problem.difficulty),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 4, children: (problem.tags as List).map((t) => Chip(label: Text(t.toString(), style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap)).toList()),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Text(problem.descriptionCn ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap to flip', style: TextStyle(color: Colors.grey, fontSize: 12))),
        ]),
      ),
    );
  }

  Widget _buildBack(AnalysisState state) {
    if (state.result == null && state.streamedText.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(height: 360, child: Center(child: Text('Submit your answer to see AI feedback'))),
      );
    }

    if (state.result == null) return const SizedBox.shrink();

    final result = state.result!;
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.auto_awesome, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('AI Evaluation', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _scoreColor(result.overallScore).withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${result.overallScore.toStringAsFixed(1)}/10',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _scoreColor(result.overallScore)),
                ),
              ),
            ]),
            if (result.summary.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text(result.summary, style: const TextStyle(fontSize: 13, height: 1.5)),
              ),
            ],
            if (result.dimensions.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text('Dimension Breakdown', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              ...result.dimensions.map((d) => DimensionCard(
                    name: d.name,
                    score: d.score,
                    maxScore: d.maxScore,
                    weight: d.weight,
                    comment: d.comment,
                    suggestion: d.suggestion,
                  )),
            ],
          ]),
        ),
      ),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 7) return Colors.green;
    if (score >= 4) return Colors.orange;
    return Colors.red;
  }
}

class _ProblemLoadingSkeleton extends StatelessWidget {
  const _ProblemLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          height: 360,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(child: ShimmerLoading(width: 180, height: 22)),
                const SizedBox(width: 8),
                ShimmerLoading(width: 48, height: 22, radius: 10),
              ]),
              const SizedBox(height: 14),
              Row(children: const [
                ShimmerLoading(width: 60, height: 22, radius: 10),
                SizedBox(width: 8),
                ShimmerLoading(width: 72, height: 22, radius: 10),
              ]),
              const SizedBox(height: 20),
              const ShimmerLoading(height: 14),
              const SizedBox(height: 8),
              const ShimmerLoading(height: 14),
              const SizedBox(height: 8),
              const ShimmerLoading(width: 200, height: 14),
              const Spacer(),
              const Center(child: ShimmerLoading(width: 80, height: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final bool isRecording;
  final double amplitude;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _MicButton({
    required this.isRecording,
    required this.amplitude,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final size = 56.0 + amplitude * 20;

    return GestureDetector(
      onLongPressStart: (_) => onStart(),
      onLongPressEnd: (_) => onStop(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.red : Colors.blue,
          boxShadow: isRecording
              ? [BoxShadow(color: Colors.red.withAlpha(80), blurRadius: amplitude * 30, spreadRadius: amplitude * 5)]
              : null,
        ),
        child: Icon(
          isRecording ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
