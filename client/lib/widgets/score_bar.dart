import 'package:flutter/material.dart';

class ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final int maxScore;

  const ScoreBar({super.key, required this.label, required this.score, this.maxScore = 10});

  @override
  Widget build(BuildContext context) {
    final ratio = score / maxScore;
    final color = ratio >= 0.7 ? Colors.green : (ratio >= 0.4 ? Colors.orange : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 16,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$score/$maxScore', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
