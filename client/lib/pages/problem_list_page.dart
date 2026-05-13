import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/problem_provider.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/shimmer_loading.dart';

class ProblemListPage extends ConsumerWidget {
  const ProblemListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(problemFilterProvider);
    final problemsAsync = ref.watch(problemListProvider(filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Algorithm Coach'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _FilterBar(filter: filter),
          Expanded(child: problemsAsync.when(
            loading: () => ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: 8,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, _) => const ShimmerProblemTile(),
            ),
            error: (e, _) => _EmptyState(
              icon: Icons.cloud_off,
              title: 'Failed to load problems',
              subtitle: e.toString(),
              action: ElevatedButton.icon(
                onPressed: () => ref.invalidate(problemListProvider(filter)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ),
            data: (problems) => problems.isEmpty
                ? _EmptyState(
                    icon: Icons.search_off,
                    title: 'No problems found',
                    subtitle: filter.difficulty != null || filter.tag != null
                        ? 'Try removing filters to see more problems'
                        : 'The problem library will be updated soon',
                    action: (filter.difficulty != null || filter.tag != null)
                        ? TextButton.icon(
                            onPressed: () =>
                                ref.read(problemFilterProvider.notifier).state = const ProblemFilter(),
                            icon: const Icon(Icons.clear_all, size: 18),
                            label: const Text('Clear Filters'),
                          )
                        : null,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: problems.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (_, i) => _ProblemTile(problem: problems[i]),
                  ),
          )),
        ],
      ),
    );
  }
}

class _ProblemTile extends ConsumerWidget {
  final dynamic problem;
  const _ProblemTile({required this.problem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      title: Text(problem.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Row(
        children: [
          DifficultyBadge(difficulty: problem.difficulty),
          const SizedBox(width: 8),
          ...(problem.tags as List).take(3).map((tag) => Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text(tag.toString(), style: const TextStyle(fontSize: 10)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              )),
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.pushNamed(context, '/problem', arguments: problem.id),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  final dynamic filter;
  const _FilterBar({required this.filter});

  static const _tags = ['Array', 'Linked List', 'Tree', 'DP', 'String', 'Hash Table'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade50,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _FilterChip(
            label: 'All',
            selected: filter.difficulty == null,
            onTap: () => ref.read(problemFilterProvider.notifier).state = filter.copyWith(clearDifficulty: true),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Easy',
            selected: filter.difficulty == 'easy',
            color: Colors.green,
            onTap: () => ref.read(problemFilterProvider.notifier).state = filter.copyWith(difficulty: 'easy'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Medium',
            selected: filter.difficulty == 'medium',
            color: Colors.orange,
            onTap: () => ref.read(problemFilterProvider.notifier).state = filter.copyWith(difficulty: 'medium'),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Hard',
            selected: filter.difficulty == 'hard',
            color: Colors.red,
            onTap: () => ref.read(problemFilterProvider.notifier).state = filter.copyWith(difficulty: 'hard'),
          ),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _FilterChip(
              label: 'All Tags',
              selected: filter.tag == null,
              onTap: () => ref.read(problemFilterProvider.notifier).state = filter.copyWith(clearTag: true),
            ),
            ..._tags.map((tag) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _FilterChip(
                    label: tag,
                    selected: filter.tag == tag,
                    color: Colors.blue,
                    onTap: () => ref.read(problemFilterProvider.notifier).state =
                        filter.copyWith(tag: filter.tag == tag ? null : tag),
                  ),
                )),
          ]),
        ),
      ]),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? (color ?? Colors.blue).withAlpha(30) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? (color ?? Colors.blue) : Colors.grey.shade300),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 13), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      ),
    );
  }
}
