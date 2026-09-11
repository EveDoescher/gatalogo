class CatReferencePhoto {
  const CatReferencePhoto({
    required this.catId,
    required this.kind,
    required this.localPath,
    required this.status,
    required this.updatedAt,
    this.syncState = 'dirty',
    this.deletedAt,
  });

  final String catId;
  final String kind;
  final String localPath;
  final String status;
  final DateTime updatedAt;
  final String syncState;
  final DateTime? deletedAt;

  Map<String, dynamic> toMap() => {
    'cat_id': catId,
    'kind': kind,
    'local_path': localPath,
    'status': status,
    'updated_at': updatedAt.toUtc().toIso8601String(),
    'sync_state': syncState,
    'deleted_at': deletedAt?.toUtc().toIso8601String(),
  };

  factory CatReferencePhoto.fromMap(Map<String, dynamic> map) =>
      CatReferencePhoto(
        catId: map['cat_id'] as String,
        kind: map['kind'] as String,
        localPath: map['local_path'] as String,
        status: map['status'] as String? ?? 'ready',
        updatedAt:
            DateTime.tryParse(map['updated_at'] as String? ?? '')?.toUtc() ??
            DateTime.now().toUtc(),
        syncState: map['sync_state'] as String? ?? 'dirty',
        deletedAt: map['deleted_at'] == null
            ? null
            : DateTime.tryParse(map['deleted_at'] as String),
      );
}
