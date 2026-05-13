class Problem {
  final String id;
  final String title;
  final String difficulty;
  final List<String> tags;
  final String? descriptionCn;
  final String? solutionApproach;
  final String? solutionCode;
  final String? complexityTime;
  final String? complexitySpace;
  final List<String>? keyPoints;
  final List<String>? commonMistakes;

  const Problem({
    required this.id,
    required this.title,
    required this.difficulty,
    required this.tags,
    this.descriptionCn,
    this.solutionApproach,
    this.solutionCode,
    this.complexityTime,
    this.complexitySpace,
    this.keyPoints,
    this.commonMistakes,
  });

  factory Problem.fromJson(Map<String, dynamic> json) => Problem(
        id: json['id'] as String,
        title: json['title'] as String,
        difficulty: json['difficulty'] as String,
        tags: List<String>.from(json['tags'] ?? []),
        descriptionCn: json['description_cn'] as String?,
        solutionApproach: json['solution_approach'] as String?,
        solutionCode: json['solution_code'] as String?,
        complexityTime: json['complexity_time'] as String?,
        complexitySpace: json['complexity_space'] as String?,
        keyPoints: json['key_points'] != null
            ? List<String>.from(json['key_points'])
            : null,
        commonMistakes: json['common_mistakes'] != null
            ? List<String>.from(json['common_mistakes'])
            : null,
      );

  Problem.empty()
      : id = '',
        title = '',
        difficulty = 'easy',
        tags = [],
        descriptionCn = null,
        solutionApproach = null,
        solutionCode = null,
        complexityTime = null,
        complexitySpace = null,
        keyPoints = null,
        commonMistakes = null;
}
