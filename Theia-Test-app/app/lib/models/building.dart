import 'destination.dart';

class Building {
  Building({
    required this.buildingId,
    required this.name,
    required this.floors,
    required this.destinations,
  });

  final String buildingId;
  final String name;
  final List<int> floors;
  final List<Destination> destinations;

  factory Building.fromJson(Map<String, dynamic> json) {
    return Building(
      buildingId: json['buildingId'] as String,
      name: json['name'] as String,
      floors: (json['floors'] as List<dynamic>? ?? const [])
          .map((entry) => entry as int)
          .toList(),
      destinations: (json['destinations'] as List<dynamic>? ?? const [])
          .map(
            (entry) => Destination.fromJson(entry as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
