import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/problem.dart';
import '../services/api_service.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

final problemListProvider = FutureProvider.autoDispose.family<List<Problem>, ProblemFilter>((ref, filter) async {
  final api = ref.watch(apiServiceProvider);
  return api.getProblems(difficulty: filter.difficulty, tag: filter.tag);
});

final problemDetailProvider = FutureProvider.autoDispose.family<Problem, String>((ref, id) async {
  final api = ref.watch(apiServiceProvider);
  return api.getProblemDetail(id);
});

class ProblemFilter {
  final String? difficulty;
  final String? tag;

  const ProblemFilter({this.difficulty, this.tag});

  ProblemFilter copyWith({String? difficulty, String? tag, bool clearDifficulty = false, bool clearTag = false}) {
    return ProblemFilter(
      difficulty: clearDifficulty ? null : (difficulty ?? this.difficulty),
      tag: clearTag ? null : (tag ?? this.tag),
    );
  }
}

final problemFilterProvider = StateProvider<ProblemFilter>((ref) => const ProblemFilter());
