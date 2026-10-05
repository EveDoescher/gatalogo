part of 'habitat_service.dart';

extension HabitatCare on HabitatService {
  DateTime get serverNow => DateTime.now().toUtc().add(_clockOffset);
  String get careDay => serverNow.toIso8601String().substring(0, 10);
  int get freePortions => care['day'] == careDay
      ? (care['free_portions'] as num?)?.toInt() ?? catCapacity
      : catCapacity + ((care['bonus_portions'] as num?)?.toInt() ?? 0);
  int get treatPrice => (care['treat_price'] as num?)?.toInt() ?? 4;
  int affinity(String catId) =>
      ((care['cats'] as Map?)?[catId]?['affinity'] as num?)?.toInt() ?? 0;
  bool caredToday(String catId, String action) =>
      (care['cats'] as Map?)?[catId]?['${action}_day'] == careDay;
  bool isGrowingPlant(HabitatItem item) =>
      const {'leaf_garden', 'bamboo_garden'}.contains(item.sku);
  DateTime? growsAt(HabitatItem item) =>
      DateTime.tryParse(item.careState['grow_at']?.toString() ?? '');
  bool isMature(HabitatItem item) => growsAt(item)?.isAfter(serverNow) == false;
  bool canWater(HabitatItem item) {
    if (!isGrowingPlant(item) || isMature(item)) return false;
    final last = DateTime.tryParse(
      item.careState['last_watered_at']?.toString() ?? '',
    );
    return last == null ||
        serverNow.difference(last) >= const Duration(hours: 6);
  }

  String spriteFor(HabitatItem item) {
    final sprite = definition(item.sku).sprite;
    return isGrowingPlant(item) && isMature(item)
        ? sprite.replaceAll('StageA', 'StageB')
        : sprite;
  }

  Future<void> interact(
    String action,
    String targetId, {
    String? bowlId,
  }) async {
    if (_disposed || !session.isSignedIn || offline) {
      throw const ProductApiException(
        'Conecte sua conta para registrar os cuidados.',
      );
    }
    if (caring) {
      throw const ProductApiException('Aguarde o cuidado em andamento.');
    }
    _setCaring(true);
    final pendingId = '$action:$targetId:${bowlId ?? ''}';
    final owner = _ownerId;
    try {
      if (hasDraft) await syncLayout();
      _verifyCareOwner(owner);
      final key = _pendingInteractions.putIfAbsent(
        pendingId,
        () => const Uuid().v4(),
      );
      await _persistSnapshot();
      _verifyCareOwner(owner);
      final result = await _api.post('/app/habitat/interactions', {
        'action': action,
        'target_id': targetId,
        'bowl_id': bowlId,
        'idempotency_key': key,
      });
      _verifyCareOwner(owner);
      final draft = hasDraft ? _draft() : null;
      _readSnapshot(result);
      if (draft != null) _applyDraft(draft);
      _pendingInteractions.remove(pendingId);
      await _persistSnapshot();
    } on ProductApiException catch (error) {
      if (!_disposed &&
          owner == _ownerId &&
          error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        _pendingInteractions.remove(pendingId);
        await _persistSnapshot();
      }
      rethrow;
    } finally {
      _setCaring(false);
    }
  }

  void _verifyCareOwner(String owner) {
    if (_disposed || owner != _ownerId) {
      throw const ProductApiException(
        'O cuidado foi interrompido. Abra o Quintal novamente.',
      );
    }
  }
}
