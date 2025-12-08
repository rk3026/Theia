import 'path_instructions.dart';

class MapData {
  const MapData({
    required this.mapId,
    required this.paths,
    this.comment,
  });

  final String mapId;
  final String? comment;
  final Map<String, PathInstructions> paths;

  factory MapData.fromJson(Map<String, dynamic> json) {
    final rawPaths = json['paths'] as Map<String, dynamic>? ?? const {};
    final parsedPaths = rawPaths.map(
      (key, value) => MapEntry(
        key,
        PathInstructions.fromJson(value as Map<String, dynamic>),
      ),
    );

    return MapData(
      mapId: json['mapID'] as String? ?? '',
      comment: json['comment'] as String?,
      paths: parsedPaths,
    );
  }
}
