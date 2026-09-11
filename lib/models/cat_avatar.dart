import 'dart:convert';

class CatAvatar {
  const CatAvatar({
    required this.catId,
    required this.version,
    required this.status,
    this.previewPath,
    this.texturePaths = const {},
    this.coatMap,
    this.errorMessage,
    required this.updatedAt,
  });

  final String catId;
  final int version;
  final String status;
  final String? previewPath;
  final Map<String, String> texturePaths;
  final Map<String, dynamic>? coatMap;
  final String? errorMessage;
  final DateTime updatedAt;

  bool get isReady => status == 'ready' && previewPath != null;

  Map<String, dynamic> toMap() => {
    'cat_id': catId,
    'version': version,
    'status': status,
    'preview_path': previewPath,
    'texture_paths_json': jsonEncode(texturePaths),
    'coat_map_json': coatMap == null ? null : jsonEncode(coatMap),
    'error_message': errorMessage,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory CatAvatar.fromMap(Map<String, dynamic> map) => CatAvatar(
    catId: map['cat_id'] as String,
    version: (map['version'] as num?)?.toInt() ?? 0,
    status: map['status'] as String? ?? 'pending',
    previewPath: map['preview_path'] as String?,
    texturePaths: Map<String, String>.from(
      jsonDecode(map['texture_paths_json'] as String? ?? '{}') as Map,
    ),
    coatMap: map['coat_map_json'] == null
        ? null
        : Map<String, dynamic>.from(
            jsonDecode(map['coat_map_json'] as String) as Map,
          ),
    errorMessage: map['error_message'] as String?,
    updatedAt:
        DateTime.tryParse(map['updated_at'] as String? ?? '')?.toUtc() ??
        DateTime.now().toUtc(),
  );
}
