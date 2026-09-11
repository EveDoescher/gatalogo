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
import '../services/analysis_api_service.dart';
import '../services/catalog_sync_service.dart';
import '../services/location_service.dart';
import '../services/vision_api_service.dart';
import 'session_store.dart';

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

  CatStore(this._sessionStore) {
    _analysisApi = AnalysisApiService(
      accessToken: _sessionStore.accessToken,
      refreshAccessToken: () => _sessionStore.accessToken(refresh: true),
    );
    _catalogSync = CatalogSyncService(_sessionStore);
    _visionApi = VisionApiService(_sessionStore);
    _sessionStore.addListener(_onSessionChanged);
  }

  final SessionStore _sessionStore;
  late final AnalysisApiService _analysisApi;
  late final CatalogSyncService _catalogSync;
  late final VisionApiService _visionApi;
  final Connectivity _connectivity = Connectivity();

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
  List<Cat> get pets => cats.where((cat) => cat.isOwned).toList();
  SessionStore get sessionStore => _sessionStore;

  bool get isLoading => _isLoading;

  bool get isSynchronizing => _isSynchronizing;

  CatAnalysis? analysisFor(String catId) {
    return _analyses[catId];
  }

  List<CatReferencePhoto> referencePhotosFor(String catId) =>
      List.unmodifiable(_referencePhotos[catId] ?? const []);

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

    _startPendingAnalysisSync();
    unawaited(syncCatalog());
    unawaited(syncPendingAnalyses());
    unawaited(resolvePendingLocations());
  }

  Future<SavedCatResult> addFromTempPhoto(
    String tempPhotoPath, {
    double? latitude,
    double? longitude,
    String? locationName,
    bool isOwned = false,
    String? name,
    DateTime? capturedAt,
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
    );

    final analysis = CatAnalysis(catId: id, status: AnalysisStatus.pending);

    await _database.insertCatWithAnalysis(cat, analysis);

    _cats.insert(0, cat);

    _analyses[id] = analysis;

    notifyListeners();

    // O envio acontece em segundo plano. Assim, a foto fica segura no banco
    // mesmo quando a rede cai durante a captura ou a API está indisponível.
    unawaited(syncPendingAnalyses());
    unawaited(syncCatalog());

    return SavedCatResult(cat: cat, awaitingConnection: awaitingConnection);
  }

  Future<void> syncPendingAnalyses() async {
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
    });
  }

  Future<bool> _hasNetworkTransport() async {
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
    await syncPendingAnalyses();
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

  Future<void> syncCatalog() async {
    try {
      if (_isLoading ||
          _sessionStore.session == null ||
          !await _hasNetworkTransport()) {
        return;
      }
      final synced = await _catalogSync.sync();
      if (!synced) return;
      await _sendQueuedSightings();
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
      debugPrint('Sincronização do catálogo adiada: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _onSessionChanged() {
    if (_loadedOwnerId != _sessionStore.session?.userId) {
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
    _disposed = true;
    _sessionStore.removeListener(_onSessionChanged);
    _connectivitySubscription?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
