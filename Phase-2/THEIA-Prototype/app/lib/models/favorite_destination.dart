class FavoriteDestination {
  final String id;
  final String name;
  final String building;
  final String room;
  final int sortIndex;
  final bool isActive;

  const FavoriteDestination({
    required this.id,
    required this.name,
    required this.building,
    required this.room,
    required this.sortIndex,
    required this.isActive,
  });

  FavoriteDestination copyWith({
    String? id,
    String? name,
    String? building,
    String? room,
    int? sortIndex,
    bool? isActive,
  }) {
    return FavoriteDestination(
      id: id ?? this.id,
      name: name ?? this.name,
      building: building ?? this.building,
      room: room ?? this.room,
      sortIndex: sortIndex ?? this.sortIndex,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'building': building,
      'room': room,
      'sortIndex': sortIndex,
      'isActive': isActive ? 1 : 0,
    };
  }

  factory FavoriteDestination.fromMap(Map<String, dynamic> map) {
    return FavoriteDestination(
      id: map['id'] as String,
      name: map['name'] as String,
      building: map['building'] as String? ?? '',
      room: map['room'] as String? ?? '',
      sortIndex: (map['sortIndex'] as int?) ?? 0,
      isActive: (map['isActive'] as int?) == 1,
    );
  }
}
