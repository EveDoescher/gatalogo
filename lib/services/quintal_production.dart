part of 'habitat_service.dart';

extension QuintalProduction on HabitatService {
  List<Map<String, dynamic>> get pendingProductionRewards => [
    for (final value
        in lastProductionProgress['celebrations'] as List? ?? const [])
      if (value is Map && value['id'] is String)
        Map<String, dynamic>.from(value),
  ];

  Future<void> acknowledgeProductionReward(String id) async {
    await produce('ack_rewards', 'quintal', {
      'event_ids': [id],
    });
  }

  List<Map<String, dynamic>> productionRows(
    String name, {
    bool catalog = false,
  }) => productionState.rows(name, catalog: catalog);
  Map<String, int> get productionStock => productionState.stock;
  int facilityLevel(String kind) => productionState.facilityLevel(kind);
  Map<String, dynamic> productionCat(String id) => productionState.cat(id);
  int? foodPreference(String id, String recipe) =>
      productionState.preference(id, recipe);
  String get productionDay => productionState.calendarDay;

  Future<void> refreshProduction() async {
    if (!session.isSignedIn || _disposed || productionBusy || caring) return;
    final owner = _ownerId;
    final generation = ++_productionGeneration;
    try {
      final response = await _repository.production();
      _verifyCareOwner(owner);
      if (generation != _productionGeneration || productionBusy || caring) {
        return;
      }
      if (response['production'] is! Map) {
        throw const ProductApiException(
          'Atualize a API para carregar a produção.',
          statusCode: 404,
        );
      }
      production = Map<String, dynamic>.from(response['production'] as Map);
      lastProductionProgress = Map<String, dynamic>.from(
        response['progress'] as Map? ?? const {},
      );
      if (!hasDraft) {
        if (response['habitat'] case final Map snapshot) {
          _readSnapshot(Map<String, dynamic>.from(snapshot));
        }
      }
      if (productionState.serverNow case final clock?) {
        _clockOffset = clock.difference(DateTime.now().toUtc());
      }
      productionOffline = false;
      await _persistSnapshot();
    } on ProductApiException {
      if (owner == _ownerId && generation == _productionGeneration) {
        productionOffline = true;
      }
    } finally {
      if (!_disposed && owner == _ownerId) _notifyVisitors();
    }
  }

  Future<Map<String, dynamic>> produce(
    String action,
    String target, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!session.isSignedIn || offline || productionBusy || caring) {
      throw const ProductApiException(
        'Conecte-se e aguarde a ação atual para continuar.',
      );
    }
    productionBusy = true;
    ++_productionGeneration;
    _notifyVisitors();
    final owner = _ownerId;
    final fingerprint = jsonEncode([action, target, data]);
    try {
      if (hasDraft) await syncLayout();
      _verifyCareOwner(owner);
      final key = _pendingProduction.putIfAbsent(
        fingerprint,
        () => const Uuid().v4(),
      );
      await _persistSnapshot();
      _verifyCareOwner(owner);
      final response = await _repository.produce({
        'action': action,
        'target': target,
        'data': data,
        'idempotency_key': key,
      });
      _verifyCareOwner(owner);
      production = Map<String, dynamic>.from(response['production'] as Map);
      lastProductionProgress = Map<String, dynamic>.from(
        response['progress'] as Map? ?? const {},
      );
      if (productionState.serverNow case final clock?) {
        _clockOffset = clock.difference(DateTime.now().toUtc());
      }
      if (response['habitat'] case final Map snapshot) {
        _readSnapshot(Map<String, dynamic>.from(snapshot));
      }
      _pendingProduction.remove(fingerprint);
      productionOffline = false;
      await _persistSnapshot();
      unawaited(catStore.refreshGamification());
      return Map<String, dynamic>.from(response['outcome'] as Map? ?? const {});
    } on ProductApiException catch (error) {
      if (owner == _ownerId &&
          error.statusCode != null &&
          error.statusCode! >= 400 &&
          error.statusCode! < 500) {
        _pendingProduction.remove(fingerprint);
        await _persistSnapshot();
      }
      rethrow;
    } on HabitatConflictException {
      throw const ProductApiException(
        'A organização mudou em outro dispositivo. Conclua a sincronização no modo edição para continuar.',
      );
    } finally {
      productionBusy = false;
      if (!_disposed && owner == _ownerId) _notifyVisitors();
    }
  }
}
