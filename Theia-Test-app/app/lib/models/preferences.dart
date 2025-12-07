class Preferences {
  final String id;
  final double ttsVolume;
  final bool hapticsEnabled;
  final bool avoidStairs;
  final DateTime updatedAt;

  const Preferences({
    required this.id,
    required this.ttsVolume,
    required this.hapticsEnabled,
    required this.avoidStairs,
    required this.updatedAt,
  });

  factory Preferences.defaults() {
    return Preferences(
      id: 'preferences-default',
      ttsVolume: 0.8,
      hapticsEnabled: true,
      avoidStairs: false,
      updatedAt: DateTime.now(),
    );
  }

  Preferences copyWith({
    String? id,
    double? ttsVolume,
    bool? hapticsEnabled,
    bool? avoidStairs,
    DateTime? updatedAt,
  }) {
    return Preferences(
      id: id ?? this.id,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      avoidStairs: avoidStairs ?? this.avoidStairs,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ttsVolume': ttsVolume,
      'hapticsEnabled': hapticsEnabled ? 1 : 0,
      'avoidStairs': avoidStairs ? 1 : 0,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Preferences.fromMap(Map<String, dynamic> map) {
    return Preferences(
      id: map['id'] as String,
      ttsVolume: (map['ttsVolume'] as num?)?.toDouble() ?? 0.8,
      hapticsEnabled: (map['hapticsEnabled'] as int?) == 1,
      avoidStairs: (map['avoidStairs'] as int?) == 1,
      updatedAt: DateTime.tryParse(map['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
