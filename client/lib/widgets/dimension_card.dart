import 'package:flutter/material.dart';

class DimensionCard extends StatelessWidget {
  final String name;
  final int score;
  final int maxScore;
  final int weight;
  final String comment;
  final String suggestion;

  const DimensionCard({
    super.key,
    required this.name,
    required this.score,
    required this.maxScore,
    required this.weight,
    required this.comment,
    required this.suggestion,
  });

  Color _color(double ratio) {
    if (ratio >= 0.7) return Colors.green;
    if (ratio >= 0.4) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = score / maxScore;
    final color = _color(ratio);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Text('Weight: $weight%', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 12,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$score/$maxScore',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ]),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Comment', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(comment, style: const TextStyle(fontSize: 13, height: 1.4)),
              ]),
            ),
          ],
          if (suggestion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, size: 14, color: Colors.amber.shade700),
              const SizedBox(width: 4),
              Expanded(child: Text(suggestion, style: TextStyle(fontSize: 12, color: Colors.amber.shade800, height: 1.4))),
            ]),
          ],
        ]),
      ),
    );
  }
}
