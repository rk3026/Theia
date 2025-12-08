class PathInstructions {
  const PathInstructions({
    required this.pathType,
    required this.estimatedTimeMin,
    required this.instructions,
  });

  final String pathType;
  final int estimatedTimeMin;
  final List<String> instructions;

  factory PathInstructions.fromJson(Map<String, dynamic> json) {
    return PathInstructions(
      pathType: json['pathType'] as String? ?? 'Route',
      estimatedTimeMin: (json['estimatedTimeMin'] as num?)?.toInt() ?? 0,
      instructions: (json['instructions'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}
