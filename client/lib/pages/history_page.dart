import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/history_provider.dart';
import '../services/history_service.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/shimmer_loading.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyState = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          if (historyState.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmClear(context, ref),
            ),
        ],
      ),
      body: historyState.loading
          ? ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, _) => const _HistoryShimmer(),
            )
          : historyState.entries.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.history, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('No practice history yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                  const SizedBox(height: 8),
                  const Text('Your practice sessions will appear here',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: historyState.entries.length,
                  itemBuilder: (_, i) => _HistoryCard(entry: historyState.entries[i]),
                ),
    );
  }

  void _confirmClear(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All practice records will be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(historyProvider.notifier).clear();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = entry.overallScore >= 7
        ? Colors.green
        : (entry.overallScore >= 4 ? Colors.orange : Colors.red);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(entry.problemTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ),
            if (entry.problemDifficulty != null)
              DifficultyBadge(difficulty: entry.problemDifficulty!),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${entry.overallScore.toStringAsFixed(1)}/10',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ),
          ]),
          if (entry.summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(entry.summary, style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 4),
          Text(
            '${entry.createdAt.month}/${entry.createdAt.day} ${entry.createdAt.hour}:${entry.createdAt.minute.toString().padLeft(2, '0')}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
          ),
        ]),
      ),
    );
  }
}

class _HistoryShimmer extends StatelessWidget {
  const _HistoryShimmer();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: ShimmerLoading(width: 160, height: 16)),
            ShimmerLoading(width: 48, height: 22, radius: 10),
            const SizedBox(width: 8),
            ShimmerLoading(width: 48, height: 22, radius: 10),
          ]),
          const SizedBox(height: 12),
          const ShimmerLoading(height: 13),
          const SizedBox(height: 6),
          const ShimmerLoading(width: 100, height: 11),
        ]),
      ),
    );
  }
}
