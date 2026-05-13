class DimensionScore {
  final String name;
  final String nameEn;
  final int score;
  final int maxScore;
  final int weight;
  final String comment;
  final String suggestion;

  const DimensionScore({
    required this.name,
    required this.nameEn,
    required this.score,
    required this.maxScore,
    required this.weight,
    required this.comment,
    required this.suggestion,
  });

  factory DimensionScore.fromJson(Map<String, dynamic> json) => DimensionScore(
        name: json['name'] as String? ?? '',
        nameEn: json['name_en'] as String? ?? '',
        score: (json['score'] as num?)?.toInt() ?? 0,
        maxScore: (json['max_score'] as num?)?.toInt() ?? 10,
        weight: (json['weight'] as num?)?.toInt() ?? 20,
        comment: json['comment'] as String? ?? '',
        suggestion: json['suggestion'] as String? ?? '',
      );
}

class AnalysisResult {
  final double overallScore;
  final String summary;
  final List<DimensionScore> dimensions;
  final String? problemTitle;
  final String? problemDifficulty;
  final double? similarity;

  const AnalysisResult({
    required this.overallScore,
    required this.summary,
    required this.dimensions,
    this.problemTitle,
    this.problemDifficulty,
    this.similarity,
  });

  static AnalysisResult empty() => const AnalysisResult(
        overallScore: 0,
        summary: '',
        dimensions: [],
      );
}
