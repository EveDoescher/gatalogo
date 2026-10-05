import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../data/cat_database.dart';
import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../models/cat_reference_photo.dart';
import '../models/gamification.dart';
import '../services/analysis_api_service.dart';
import '../services/catalog_sync_service.dart';
import '../services/favorites_manager.dart';
import '../services/gamification_service.dart';
import '../services/progress_service.dart';
import '../services/location_service.dart';
import '../services/vision_api_service.dart';
import 'session_store.dart';
import 'notification_store.dart';
import '../services/product_api_service.dart';

class SavedCatResult {
  const SavedCatResult({required this.cat, required this.awaitingConnection});

  final Cat cat;
  final bool awaitingConnection;
}

class CatStore extends ChangeNotifier {
  static const _maxAutomaticAttempts = 2;
  final CatDatabase _database = CatDatabase.instance;

  final List<Cat> _cats = [];

  final Map<String, CatAnalysis> _analyses = {};
  final Map<String, List<CatReferencePhoto>> _referencePhotos = {};
  final Set<String> _deletedCatIds = {};

  CatStore(
    this._sessionStore, {
    CatalogSyncService? catalogSync,
    this.networkAvailable,
  }) {
    _analysisApi = AnalysisApiService(
      accessToken: _sessionStore.accessToken,
      refreshAccessToken: () => _sessionStore.accessToken(refresh: true),
    );
    _catalogSync = catalogSync ?? CatalogSyncService(_sessionStore);
    _visionApi = VisionApiService(_sessionStore);
    _gamificationService = GamificationService(_sessionStore);
    progress = ProgressService(_sessionStore)..addListener(notifyListeners);
    final productApi = ProductApiService(_sessionStore);
    notifications = NotificationStore(
      loadItems: () async => _sessionStore.isSignedIn
          ? productApi.list('/vision/notifications')
          : [],
      saveRead: (id) async {
        await productApi.post('/app/notifications/$id/read');
      },
    );
    _notificationSubscription = _sessionStore.webSocket.onNotification.listen((
      _,
    ) {
      unawaited(refreshNotifications());
      unawaited(refreshGamification());
    });
    _pushSubscription = _sessionStore.pushNotifications.onNotification.listen((
      _,
    ) {
      unawaited(refreshNotifications());
      unawaited(refreshGamification());
    });
    _sessionStore.addListener(_onSessionChanged);
  }

  late final NotificationStore notifications;
  late final ProgressService progress;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _pushSubscription;

  Future<void> refreshNotifications() async {
    try {
      await notifications.refresh();
    } catch (_) {
      // Retain the shared snapshot when offline.
    }
  }

  final SessionStore _sessionStore;
  late final AnalysisApiService _analysisApi;
  late final CatalogSyncService _catalogSync;
  late final VisionApiService _visionApi;
  late final GamificationService _gamificationService;
  final Connectivity _connectivity = Connectivity();
  final Future<bool> Function()? networkAvailable;

  GamificationState get gamification => progress.summary.isNotEmpty
      ? GamificationState.fromMap(progress.summary)
      : GamificationState.initial();

  bool _isLoading = false;
  bool _disposed = false;
  String? _loadedOwnerId;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  bool _isSynchronizing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  Timer? _retryTimer;

  List<Cat> get cats => List.unmodifiable(_cats);
  List<Cat> get discoveries => cats.where((cat) => !cat.isOwned).toList();

  List<Cat> get individuals {
    final groups = <String, Cat>{};
    for (final cat in discoveries.where((c) => c.individualId != 'pending')) {
      final key = cat.individualId ?? cat.id;
      if (!groups.containsKey(key) || cat.id == key) groups[key] = cat;
    }
    return groups.values.toList();
  }

  List<Cat> photosOf(Cat cat) => cat.individualId == 'pending'
      ? [cat]
      : cats
            .where(
              (photo) =>
                  (photo.individualId ?? photo.id) ==
                  (cat.individualId ?? cat.id),
            )
            .toList();

  List<Cat> get pets => cats.where((cat) => cat.isOwned).toList();
  SessionStore get sessionStore => _sessionStore;

  bool get isLoading => _isLoading;

  bool get isSynchronizing => _isSynchronizing;

  CatAnalysis? analysisFor(String catId) {
    return _analyses[catId];
  }

  List<CatReferencePhoto> referencePhotosFor(String catId) =>
      List.unmodifiable(_referencePhotos[catId] ?? const []);

  Future<List<CatReferencePhoto>> loadReferencePhotos(String catId) async {
    final photos = await _database.getReferencePhotos(catId);
    _referencePhotos[catId] = photos;
    notifyListeners();
    return photos;
  }

  Future<void> loadCats() async {
    _isLoading = true;
    notifyListeners();

    _loadedOwnerId = _sessionStore.session?.userId;
    final cats = await _database.getCats(ownerId: _loadedOwnerId);
    for (final cat in cats.where((cat) => cat.status == 'analyzing')) {
      await _database.updateCatStatus(cat.id, 'pending_analysis');
    }
    final analyses = await _database.getAnalyses();

    _cats
      ..clear()
      ..addAll(
        cats.map(
          (cat) => cat.status == 'analyzing'
              ? cat.withStatus('pending_analysis', markDirty: false)
              : cat,
        ),
      );

    _analyses.clear();

    for (final analysis in analyses) {
      _analyses[analysis.catId] = analysis;
    }
    _referencePhotos.clear();
    for (final cat in cats) {
      _referencePhotos[cat.id] = await _database.getReferencePhotos(cat.id);
    }

    _isLoading = false;
    notifyListeners();

    unawaited(progress.refresh());
    _startPendingAnalysisSync();
    unawaited(refreshNotifications());
    unawaited(syncCatalog());
    unawaited(syncPendingAnalyses());
    unawaited(resolvePendingLocations());
  }

  Future<GamificationActionResult> recordGamificationAction(
    String action, {
    String? contextId,
  }) async {
    await refreshGamification();
    return GamificationActionResult(
      state: gamification,
      earnedXp: 0,
      multiplier: 1,
      levelUp: false,
      level: gamification.level,
      levelTitle: gamification.levelTitle,
      missionsCompleted: const [],
    );
  }

  Future<void> identifyRecord(
    String catId,
    String individualId, {
    String contributionType = 'encounter',
  }) async {
    if (_sessionStore.isSignedIn) {
      await syncCatalog();
      await ProductApiService(_sessionStore).put(
        '/app/progress/records/$catId/identity',
        {'individual_id': individualId, 'contribution_type': contributionType},
      );
    }
    final cat = _cats.firstWhere((c) => c.id == catId);
    final updated = cat.withSync(
      individualId: individualId,
      syncState: 'dirty',
      localUpdatedAt: DateTime.now().toUtc(),
    );
    await _database.insertCatWithAnalysis(
      updated,
      _analyses[catId] ??
          CatAnalysis(catId: catId, status: AnalysisStatus.pending),
    );
    _replaceCat(catId, (_) => updated);
    notifyListeners();
    await syncCatalog();
    await progress.refresh();
  }

  Future<void> refreshGamification() async {
    await progress.refresh();
    notifyListeners();
  }

  Future<void> recordHabitatAction(
    String action, {
    String? targetType,
    String? targetId,
  }) async {
    if (!_sessionStore.isSignedIn) return;
    try {
      await ProductApiService(_sessionStore).post('/app/habitat/actions', {
        'action': action,
        'target_type': targetType,
        'target_id': targetId,
      });
    } catch (_) {
      // A moeda só aparece após confirmação no servidor.
    }
  }

  Future<SavedCatResult> addFromTempPhoto(
    String tempPhotoPath, {
    double? latitude,
    double? longitude,
    String? locationName,
    bool isOwned = false,
    String? individualId,
    String? name,
    DateTime? capturedAt,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
  }) async {
    const uuid = Uuid();

    final id = uuid.v4();
    final awaitingConnection = !await _hasNetworkTransport();

    final captureNumber = await _database.getNextCaptureNumber();

    final documentsDirectory = await getApplicationDocumentsDirectory();

    final catsDirectory = Directory(p.join(documentsDirectory.path, 'cats'));

    if (!await catsDirectory.exists()) {
      await catsDirectory.create(recursive: true);
    }

    final originalExtension = p.extension(tempPhotoPath);

    final extension = originalExtension.isEmpty ? '.jpg' : originalExtension;

    final permanentPath = p.join(catsDirectory.path, '$id$extension');

    await File(tempPhotoPath).copy(permanentPath);

    final ownerId = _sessionStore.session?.userId;
    final deviceId = await _database.getOrCreateDeviceId();
    final cat = Cat(
      isOwned: isOwned,
      individualId: individualId,
      name: name?.trim(),
      id: id,
      captureNumber: captureNumber,
      photoPath: permanentPath,
      capturedAt: capturedAt ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
      status: 'pending_analysis',
      ownerId: ownerId,
      syncDeviceId: deviceId,
      microchip: microchip?.trim().isEmpty == true ? null : microchip?.trim(),
      collar: collar?.trim().isEmpty == true ? null : collar?.trim(),
      distinguishingMarks: distinguishingMarks?.trim().isEmpty == true
          ? null
          : distinguishingMarks?.trim(),
    );

    final analysis = CatAnalysis(catId: id, status: AnalysisStatus.pending);

    await _database.insertCatWithAnalysis(cat, analysis);

    _cats.insert(0, cat);
    unawaited(progress.track('capture_saved'));

    _analyses[id] = analysis;

    notifyListeners();

    // O envio acontece em segundo plano. Assim, a foto fica segura no banco
    // mesmo quando a rede cai durante a captura ou a API está indisponível.
    unawaited(syncPendingAnalyses());
    unawaited(syncCatalog());

    return SavedCatResult(cat: cat, awaitingConnection: awaitingConnection);
  }

  Future<void> syncPendingAnalyses({bool manual = false}) async {
    if (!manual && !_sessionStore.autoSyncEnabled) return;
    if (_sessionStore.session == null ||
        _isSynchronizing ||
        _isLoading ||
        !await _hasNetworkTransport()) {
      return;
    }

    _isSynchronizing = true;
    notifyListeners();

    try {
      // Registra primeiro os metadados e a foto privada. Assim a análise não
      // cria no servidor um gato sem os dados capturados localmente.
      await _catalogSync.sync();
      final pendingCats = List<Cat>.from(
        _cats.where((cat) => cat.status == 'pending_analysis'),
      );

      for (final cat in pendingCats) {
        final shouldContinue = await _analyzePendingCat(cat);
        if (!shouldContinue) {
          break;
        }
      }
    } finally {
      _isSynchronizing = false;
      notifyListeners();
    }
  }

  bool _isCurrentPhoto(Cat cat) =>
      !_disposed &&
      _cats.any(
        (current) => current.id == cat.id && current.photoPath == cat.photoPath,
      );

  Future<bool> _analyzePendingCat(Cat cat) async {
    if (_deletedCatIds.contains(cat.id) || !_isCurrentPhoto(cat)) {
      return true;
    }

    final photo = File(cat.photoPath);
    if (!await photo.exists()) {
      await _setAnalysisState(cat.id, AnalysisStatus.failed, 'failed');
      return true;
    }

    await _setAnalysisState(cat.id, AnalysisStatus.analyzing, 'analyzing');

    try {
      final analysis = await _analysisApi.analyze(
        catId: cat.id,
        imagePath: cat.photoPath,
      );
      if (_deletedCatIds.contains(cat.id) || !_isCurrentPhoto(cat)) {
        return true;
      }
      await _database.upsertAnalysis(analysis);
      await _database.updateCatStatus(cat.id, 'completed');

      _analyses[cat.id] = analysis;
      _replaceCat(cat.id, (current) => current.withStatus('completed'));
      notifyListeners();
      unawaited(syncCatalog());
      unawaited(refreshGamification());
      return true;
    } on AnalysisConnectionException {
      await _scheduleAutomaticRetry(cat);
      return false;
    } on AnalysisApiException catch (error) {
      if (error.retryable) {
        await _scheduleAutomaticRetry(cat);
        return false;
      }

      await _setAnalysisState(cat.id, AnalysisStatus.failed, 'failed');
      return true;
    } on AnalysisRejectedException {
      await _setAnalysisState(cat.id, AnalysisStatus.failed, 'failed');
      return true;
    } catch (error, stackTrace) {
      debugPrint('Erro ao sincronizar análise pendente: $error');
      debugPrintStack(stackTrace: stackTrace);
      await _scheduleAutomaticRetry(cat);
      return false;
    }
  }

  Future<void> _scheduleAutomaticRetry(Cat cat) async {
    if (!_isCurrentPhoto(cat)) return;
    final nextAttempt = cat.automaticRetryCount + 1;
    final hasReachedLimit = nextAttempt >= _maxAutomaticAttempts;

    await _setAnalysisState(
      cat.id,
      hasReachedLimit ? AnalysisStatus.failed : AnalysisStatus.pending,
      hasReachedLimit ? 'failed' : 'pending_analysis',
      automaticRetryCount: nextAttempt,
    );
  }

  Future<void> _setAnalysisState(
    String catId,
    AnalysisStatus analysisStatus,
    String catStatus, {
    int? automaticRetryCount,
  }) async {
    if (_deletedCatIds.contains(catId)) {
      return;
    }

    final current =
        _analyses[catId] ??
        CatAnalysis(catId: catId, status: AnalysisStatus.pending);
    final updated = current.withStatus(analysisStatus);

    await _database.upsertAnalysis(updated);
    await _database.updateCatStatus(
      catId,
      catStatus,
      automaticRetryCount: automaticRetryCount,
    );

    _analyses[catId] = updated;
    _replaceCat(
      catId,
      (cat) =>
          cat.withStatus(catStatus, automaticRetryCount: automaticRetryCount),
    );
    notifyListeners();
  }

  void _replaceCat(String id, Cat Function(Cat cat) update) {
    final index = _cats.indexWhere((cat) => cat.id == id);
    if (index != -1) {
      _cats[index] = update(_cats[index]);
    }
  }

  void _startPendingAnalysisSync() {
    _connectivitySubscription ??= _connectivity.onConnectivityChanged.listen((
      results,
    ) {
      if (_hasNetworkTransportResults(results)) {
        unawaited(syncPendingAnalyses());
        unawaited(syncCatalog());
        unawaited(resolvePendingLocations());
      }
    });
    _retryTimer ??= Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(syncPendingAnalyses());
      unawaited(syncCatalog());
      unawaited(resolvePendingLocations());
      unawaited(refreshNotifications());
    });
  }

  Future<bool> _hasNetworkTransport() async {
    if (networkAvailable != null) return networkAvailable!();
    try {
      final results = await _connectivity.checkConnectivity().timeout(
        const Duration(seconds: 2),
      );
      return _hasNetworkTransportResults(results);
    } on TimeoutException {
      return false;
    }
  }

  bool _hasNetworkTransportResults(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  Future<void> retryAnalysis(String catId) async {
    final index = _cats.indexWhere((cat) => cat.id == catId);
    if (index == -1 || _cats[index].status == 'completed') {
      return;
    }

    await _setAnalysisState(
      catId,
      AnalysisStatus.pending,
      'pending_analysis',
      automaticRetryCount: 0,
    );
    await syncPendingAnalyses(manual: true);
  }

  Future<void> deleteCat(String catId) async {
    final index = _cats.indexWhere((cat) => cat.id == catId);
    if (index == -1) {
      return;
    }

    final cat = _cats[index];
    if (cat.status == 'analyzing') {
      throw StateError(
        'A análise está em andamento. Tente novamente em breve.',
      );
    }

    _deletedCatIds.add(catId);
    final signedInUser = _sessionStore.session;
    try {
      if (signedInUser != null) {
        await _database.markDeleted(
          catId,
          signedInUser.userId,
          await _database.getOrCreateDeviceId(),
        );
      } else {
        await _database.deleteCatWithAnalysis(catId);
      }
    } catch (_) {
      _deletedCatIds.remove(catId);
      rethrow;
    }

    _cats.removeAt(index);
    _analyses.remove(catId);
    notifyListeners();

    if (signedInUser != null) {
      unawaited(syncCatalog());
      return;
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final catsDirectory = p.join(documentsDirectory.path, 'cats');
    final photoPath = p.normalize(cat.photoPath);

    if (!p.isWithin(catsDirectory, photoPath)) {
      return;
    }

    try {
      final photo = File(photoPath);
      if (await photo.exists()) {
        await photo.delete();
      }
    } on FileSystemException catch (error) {
      debugPrint('Não foi possível remover a foto local excluída: $error');
    }
  }

  Future<void> updateCatName(String id, String? name) async {
    final normalizedName = name?.trim();

    final savedName = normalizedName == null || normalizedName.isEmpty
        ? null
        : normalizedName;

    await _database.updateCatName(id, savedName);

    final index = _cats.indexWhere((cat) => cat.id == id);

    if (index == -1) {
      return;
    }

    _cats[index] = _cats[index].withName(savedName);

    notifyListeners();
    unawaited(syncCatalog());
  }

  Future<void> updateCatDetails(
    String id, {
    String? name,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
  }) async {
    final normalizedName = name?.trim();
    final savedName = normalizedName == null || normalizedName.isEmpty
        ? null
        : normalizedName;
    final savedMicrochip = microchip?.trim().isEmpty == true
        ? null
        : microchip?.trim();
    final savedCollar = collar?.trim().isEmpty == true ? null : collar?.trim();
    final savedMarks = distinguishingMarks?.trim().isEmpty == true
        ? null
        : distinguishingMarks?.trim();

    await _database.updateCatDetails(
      id,
      name: savedName,
      microchip: savedMicrochip,
      collar: savedCollar,
      distinguishingMarks: savedMarks,
    );

    final index = _cats.indexWhere((cat) => cat.id == id);
    if (index != -1) {
      _cats[index] = _cats[index].withDetails(
        name: savedName,
        microchip: savedMicrochip,
        collar: savedCollar,
        distinguishingMarks: savedMarks,
      );
      notifyListeners();
      unawaited(syncCatalog());
    }
  }

  Future<void> updateCatLocation(
    String id, {
    required double latitude,
    required double longitude,
    String? locationName,
  }) async {
    await _database.updateCatLocation(
      id,
      latitude: latitude,
      longitude: longitude,
      locationName: locationName,
    );
    _replaceCat(
      id,
      (cat) => cat.withLocation(
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
      ),
    );
    notifyListeners();
    unawaited(syncCatalog());
  }

  Future<void> recordSighting(
    String catId, {
    double? latitude,
    double? longitude,
    String? note,
    DateTime? observedAt,
  }) async {
    final matches = _cats.where((item) => item.id == catId).toList();
    final cat = matches.isEmpty ? null : matches.first;
    if (cat == null) throw StateError('Gato não encontrado.');
    if ((latitude ?? cat.latitude) == null ||
        (longitude ?? cat.longitude) == null) {
      throw StateError(
        'Esta foto não possui localização para registrar o avistamento.',
      );
    }
    await _database.queueSighting({
      'cat_client_id': cat.id,
      'latitude': latitude ?? cat.latitude!,
      'longitude': longitude ?? cat.longitude!,
      'note': note,
      'observed_at': (observedAt ?? DateTime.now()).toUtc().toIso8601String(),
    });
    unawaited(syncCatalog());
  }

  bool _sendingSightings = false;
  Future<void> _sendQueuedSightings() async {
    if (_sendingSightings || !_sessionStore.isSignedIn) return;
    _sendingSightings = true;
    try {
      for (final item in await _database.queuedSightings()) {
        final cat = await _database.getCatById(item['cat_client_id'] as String);
        if (cat == null || cat.deletedAt != null) {
          await _database.removeQueuedSighting(item['queue_key'] as String);
          continue;
        }
        if (cat.ownerId != _sessionStore.session?.userId) continue;
        await _visionApi.createSighting(
          catId: cat.id,
          clientEventId: item['queue_key'] as String,
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          note: item['note'] as String?,
          observedAt: DateTime.parse(item['observed_at'] as String),
        );
        await _database.removeQueuedSighting(item['queue_key'] as String);
      }
    } catch (_) {
      /* Persisted entries retry on the next successful sync. */
    } finally {
      _sendingSightings = false;
    }
  }

  Future<void> addReferencePhoto(
    String catId,
    String kind,
    String temporaryPath,
  ) async {
    await _addReferencePhoto(catId, kind, temporaryPath);
  }

  Future<void> replacePrimaryPhoto(String catId, String temporaryPath) async {
    final cat = _cats.firstWhere((cat) => cat.id == catId);
    final docs = await getApplicationDocumentsDirectory();
    final target = File(
      p.join(docs.path, 'cats', '${catId}_${const Uuid().v4()}.jpg'),
    );
    await target.parent.create(recursive: true);
    await File(temporaryPath).copy(target.path);
    final updated = cat
        .withSync(
          photoPath: target.path,
          syncState: 'dirty',
          localUpdatedAt: DateTime.now().toUtc(),
        )
        .withStatus('pending_analysis', automaticRetryCount: 0);
    final analysis = CatAnalysis(catId: catId, status: AnalysisStatus.pending);
    await _database.insertCatWithAnalysis(updated, analysis);
    _replaceCat(catId, (_) => updated);
    _analyses[catId] = analysis;
    notifyListeners();
    unawaited(syncCatalog());
    unawaited(syncPendingAnalyses());
  }

  Future<void> _addReferencePhoto(
    String catId,
    String kind,
    String temporaryPath,
  ) async {
    const allowed = {'front', 'left', 'right', 'back'};
    if (!allowed.contains(kind)) throw ArgumentError.value(kind, 'kind');
    final matchingCats = _cats.where((item) => item.id == catId);
    final cat = matchingCats.isEmpty ? null : matchingCats.first;
    if (cat == null) throw StateError('Gato não encontrado.');
    final documents = await getApplicationDocumentsDirectory();
    final destination = p.join(
      documents.path,
      'cats',
      catId,
      'references',
      '$kind.jpg',
    );
    final file = File(destination);
    await file.parent.create(recursive: true);
    await File(temporaryPath).copy(destination);
    final photo = CatReferencePhoto(
      catId: catId,
      kind: kind,
      localPath: destination,
      status: 'pending',
      updatedAt: DateTime.now().toUtc(),
    );
    await _database.upsertReferencePhoto(photo);
    final existing = await _database.getReferencePhotos(catId);
    _referencePhotos[catId] = existing;
    notifyListeners();
    unawaited(syncCatalog());
  }

  Future<void> deleteReferencePhoto(String catId, String kind) async {
    final matchingPhotos = (await _database.getReferencePhotos(catId))
        .where((item) => item.kind == kind);
    final photo = matchingPhotos.isEmpty ? null : matchingPhotos.first;
    if (photo == null) return;
    await _database.markReferenceDeleted(catId, kind);
    _referencePhotos[catId] = await _database.getReferencePhotos(catId);
    notifyListeners();
    unawaited(syncCatalog());
  }

  Future<void> resolvePendingLocations() async {
    if (!await _hasNetworkTransport()) {
      return;
    }
    final catsWithoutAddress = _cats.where(
      (cat) =>
          cat.latitude != null &&
          cat.longitude != null &&
          (cat.locationName == null || cat.locationName!.trim().isEmpty),
    );
    for (final cat in catsWithoutAddress) {
      final name = await LocationService.getLocationName(
        cat.latitude!,
        cat.longitude!,
      ).timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (name == null) {
        continue;
      }
      await updateCatLocation(
        cat.id,
        latitude: cat.latitude!,
        longitude: cat.longitude!,
        locationName: name,
      );
    }
  }

  Future<void> toggleFavorite(String catId) async {
    await FavoritesManager.instance.toggleFavorite(
      catId,
      sessionStore: _sessionStore,
    );
    final index = _cats.indexWhere((c) => c.id == catId);
    if (index != -1) {
      final isFav = FavoritesManager.instance.isFavorite(catId);
      _cats[index] = _cats[index].withFavorite(isFav);
      notifyListeners();
    }
  }

  Future<void> updateCatNotes(String catId, String? notes) async {
    await _database.updateCatNotes(catId, notes);
    final index = _cats.indexWhere((c) => c.id == catId);
    if (index != -1) {
      _cats[index] = _cats[index].withNotes(notes);
      notifyListeners();
    }
  }

  Future<void> syncCatalog({bool manual = false}) async {
    if (!manual && !_sessionStore.autoSyncEnabled) return;
    try {
      if (_isLoading ||
          _sessionStore.session == null ||
          !await _hasNetworkTransport()) {
        return;
      }
      final synced = await _catalogSync.sync();
      if (!synced) return;
      await _sendQueuedSightings();
      await FavoritesManager.instance.syncWithServer(_sessionStore);
      final cats = await _database.getCats(
        ownerId: _sessionStore.session?.userId,
      );
      final analyses = await _database.getAnalyses();
      _cats
        ..clear()
        ..addAll(cats);
      _analyses
        ..clear()
        ..addEntries(
          analyses.map((analysis) => MapEntry(analysis.catId, analysis)),
        );
      _referencePhotos.clear();
      for (final cat in cats) {
        _referencePhotos[cat.id] = await _database.getReferencePhotos(cat.id);
      }
      notifyListeners();
    } catch (error, stackTrace) {
      debugPrint('Sincronizacao do catalogo adiada: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onSessionChanged() {
    if (_loadedOwnerId != _sessionStore.session?.userId) {
      notifications.clear();
      _gamificationService.reset();
      progress.reset();
      _cats.clear();
      _analyses.clear();
      _referencePhotos.clear();
      notifyListeners();
      unawaited(loadCats());
      return;
    }
    if (_sessionStore.isSignedIn) {
      unawaited(syncCatalog());
      unawaited(syncPendingAnalyses());
    }
  }

  @override
  void dispose() {
    progress.removeListener(notifyListeners);
    progress.dispose();
    _disposed = true;
    _sessionStore.removeListener(_onSessionChanged);
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    _notificationSubscription?.cancel();
    _pushSubscription?.cancel();
    notifications.dispose();
    super.dispose();
  }
}
