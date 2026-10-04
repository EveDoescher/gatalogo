class Cat {
  final bool isOwned;
  final String? individualId;
  String get displayName => name?.trim().isNotEmpty == true
      ? name!.trim()
      : 'Gato #${captureNumber.toString().padLeft(3, '0')}';
  final String id;
  final int captureNumber;

  final String? name;

  final String photoPath;
  final DateTime capturedAt;

  final double? latitude;
  final double? longitude;
  final String? locationName;

  final String status;
  final int automaticRetryCount;
  final String? ownerId;
  final String syncState;
  final DateTime localUpdatedAt;
  final String? syncDeviceId;
  final int syncRevision;
  final DateTime? deletedAt;
  final String? microchip;
  final String? collar;
  final String? distinguishingMarks;
  final bool isFavorite;
  final String? notes;

  const Cat({
    this.isOwned = false,
    this.individualId,
    required this.id,
    required this.captureNumber,
    required this.photoPath,
    required this.capturedAt,
    this.name,
    this.latitude,
    this.longitude,
    this.locationName,
    this.status = 'pending_analysis',
    this.automaticRetryCount = 0,
    this.ownerId,
    this.syncState = 'dirty',
    DateTime? localUpdatedAt,
    this.syncDeviceId,
    this.syncRevision = 0,
    this.deletedAt,
    this.microchip,
    this.collar,
    this.distinguishingMarks,
    this.isFavorite = false,
    this.notes,
  }) : localUpdatedAt = localUpdatedAt ?? capturedAt;

  Map<String, dynamic> toMap() {
    return {
      'is_owned': isOwned ? 1 : 0,
      'individual_id': individualId,
      'id': id,
      'capture_number': captureNumber,
      'name': name,
      'photo_path': photoPath,
      'captured_at': capturedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
      'status': status,
      'automatic_retry_count': automaticRetryCount,
      'owner_id': ownerId,
      'sync_state': syncState,
      'local_updated_at': localUpdatedAt.toUtc().toIso8601String(),
      'sync_device_id': syncDeviceId,
      'sync_revision': syncRevision,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
      'microchip': microchip,
      'collar': collar,
      'distinguishing_marks': distinguishingMarks,
      'is_favorite': isFavorite ? 1 : 0,
      'notes': notes,
    };
  }

  factory Cat.fromMap(Map<String, dynamic> map) {
    return Cat(
      isOwned: map['is_owned'] == 1 || map['is_owned'] == true,
      individualId: map['individual_id'] as String?,
      id: map['id'],
      captureNumber: map['capture_number'] ?? 0,
      name: map['name'],
      photoPath: map['photo_path'],
      capturedAt: DateTime.parse(map['captured_at']),
      latitude: map['latitude'],
      longitude: map['longitude'],
      locationName: map['location_name'],
      status: map['status'],
      automaticRetryCount: map['automatic_retry_count'] ?? 0,
      ownerId: map['owner_id'] as String?,
      syncState: map['sync_state'] as String? ?? 'dirty',
      localUpdatedAt: map['local_updated_at'] == null
          ? DateTime.parse(map['captured_at'] as String).toUtc()
          : DateTime.parse(map['local_updated_at'] as String).toUtc(),
      syncDeviceId: map['sync_device_id'] as String?,
      syncRevision: map['sync_revision'] as int? ?? 0,
      deletedAt: map['deleted_at'] == null
          ? null
          : DateTime.parse(map['deleted_at'] as String).toUtc(),
      microchip: map['microchip'] as String?,
      collar: map['collar'] as String?,
      distinguishingMarks: map['distinguishing_marks'] as String?,
      isFavorite: map['is_favorite'] == 1 || map['is_favorite'] == true,
      notes: map['notes'] as String?,
    );
  }

  Cat withFavorite(bool favorite) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: name,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip,
      collar: collar,
      distinguishingMarks: distinguishingMarks,
      isFavorite: favorite,
      notes: notes,
    );
  }

  Cat withNotes(String? newNotes) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: name,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip,
      collar: collar,
      distinguishingMarks: distinguishingMarks,
      isFavorite: isFavorite,
      notes: newNotes,
    );
  }

  Cat withName(String? newName) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: newName,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip,
      collar: collar,
      distinguishingMarks: distinguishingMarks,
      isFavorite: isFavorite,
      notes: notes,
    );
  }

  Cat withDetails({
    String? name,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
    String? notes,
    bool? isFavorite,
  }) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: name ?? this.name,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip ?? this.microchip,
      collar: collar ?? this.collar,
      distinguishingMarks: distinguishingMarks ?? this.distinguishingMarks,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
    );
  }

  Cat withStatus(
    String newStatus, {
    int? automaticRetryCount,
    bool markDirty = true,
  }) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: name,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: newStatus,
      automaticRetryCount: automaticRetryCount ?? this.automaticRetryCount,
      ownerId: ownerId,
      syncState: markDirty ? 'dirty' : syncState,
      localUpdatedAt: markDirty ? DateTime.now().toUtc() : localUpdatedAt,
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip,
      collar: collar,
      distinguishingMarks: distinguishingMarks,
      isFavorite: isFavorite,
      notes: notes,
    );
  }

  Cat withLocation({
    required double latitude,
    required double longitude,
    String? locationName,
  }) {
    return Cat(
      isOwned: isOwned,
      individualId: individualId,
      id: id,
      captureNumber: captureNumber,
      name: name,
      photoPath: photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
      syncDeviceId: syncDeviceId,
      syncRevision: syncRevision,
      deletedAt: deletedAt,
      microchip: microchip,
      collar: collar,
      distinguishingMarks: distinguishingMarks,
      isFavorite: isFavorite,
      notes: notes,
    );
  }

  Cat withSync({
    String? ownerId,
    String? syncState,
    DateTime? localUpdatedAt,
    String? syncDeviceId,
    int? syncRevision,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? photoPath,
    String? name,
    String? status,
    bool? isOwned,
    String? individualId,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
    bool? isFavorite,
    String? notes,
  }) {
    return Cat(
      isOwned: isOwned ?? this.isOwned,
      individualId: individualId ?? this.individualId,
      id: id,
      captureNumber: captureNumber,
      name: name ?? this.name,
      photoPath: photoPath ?? this.photoPath,
      capturedAt: capturedAt,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: status ?? this.status,
      automaticRetryCount: automaticRetryCount,
      ownerId: ownerId ?? this.ownerId,
      syncState: syncState ?? this.syncState,
      localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
      syncDeviceId: syncDeviceId ?? this.syncDeviceId,
      syncRevision: syncRevision ?? this.syncRevision,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      microchip: microchip ?? this.microchip,
      collar: collar ?? this.collar,
      distinguishingMarks: distinguishingMarks ?? this.distinguishingMarks,
      isFavorite: isFavorite ?? this.isFavorite,
      notes: notes ?? this.notes,
    );
  }
}
