import 'dart:convert';

class MusicPlaylist {
  const MusicPlaylist({
    required this.id,
    required this.name,
    required this.trackIds,
    required this.createdAt,
  });

  final String id;
  final String name;
  final List<String> trackIds;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'trackIds': trackIds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory MusicPlaylist.fromJson(Map<String, Object?> json) {
    final trackIds = json['trackIds'];
    if (trackIds is! List || trackIds.any((id) => id is! String)) {
      throw const FormatException('Playlist track IDs are invalid.');
    }
    return MusicPlaylist(
      id: json['id']! as String,
      name: json['name']! as String,
      trackIds: List.unmodifiable(trackIds.cast<String>()),
      createdAt: DateTime.parse(json['createdAt']! as String),
    );
  }

  static List<MusicPlaylist> decodeList(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! List) {
      throw const FormatException('Stored playlists are not a list.');
    }
    return decoded
        .map((item) {
          if (item is! Map) {
            throw const FormatException('Stored playlist is not an object.');
          }
          return MusicPlaylist.fromJson(Map<String, Object?>.from(item));
        })
        .toList(growable: false);
  }
}
