import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis_result.dart';

class HistoryService {
  static const _key = 'analysis_history';

  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((j) => HistoryEntry.fromJson(jsonDecode(j)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(HistoryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    raw.insert(0, jsonEncode(entry.toJson()));
    if (raw.length > 50) raw.removeRange(50, raw.length);
    await prefs.setStringList(_key, raw);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

class HistoryEntry {
  final String id;
  final String problemTitle;
  final String? problemDifficulty;
  final double overallScore;
  final String summary;
  final List<DimensionScore> dimensions;
  final String? userInput;
  final DateTime createdAt;

  const HistoryEntry({
    required this.id,
    required this.problemTitle,
    this.problemDifficulty,
    required this.overallScore,
    required this.summary,
    required this.dimensions,
    this.userInput,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        problemTitle: json['problem_title'] as String,
        problemDifficulty: json['problem_difficulty'] as String?,
        overallScore: (json['overall_score'] as num).toDouble(),
        summary: json['summary'] as String? ?? '',
        dimensions: (json['dimensions'] as List?)
                ?.map((d) => DimensionScore.fromJson(d))
                .toList() ??
            [],
        userInput: json['user_input'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'problem_title': problemTitle,
        'problem_difficulty': problemDifficulty,
        'overall_score': overallScore,
        'summary': summary,
        'dimensions': dimensions
            .map((d) => {
                  'name': d.name,
                  'name_en': d.nameEn,
                  'score': d.score,
                  'max_score': d.maxScore,
                  'weight': d.weight,
                  'comment': d.comment,
                  'suggestion': d.suggestion,
                })
            .toList(),
        'user_input': userInput,
        'created_at': createdAt.toIso8601String(),
      };
}
