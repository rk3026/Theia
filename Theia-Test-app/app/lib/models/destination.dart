class Destination {
  Destination({
    required this.id,
    required this.name,
    required this.floor,
    required this.type,
    required this.keywords,
  });

  final String id;
  final String name;
  final int floor;
  final String type;
  final List<String> keywords;

  factory Destination.fromJson(Map<String, dynamic> json) {
    return Destination(
      id: json['id'] as String,
      name: json['name'] as String,
      floor: json['floor'] as int,
      type: json['type'] as String,
      keywords: (json['keywords'] as List<dynamic>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}
