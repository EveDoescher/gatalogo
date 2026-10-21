import 'package:sqflite/sqflite.dart';

import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../models/cat_reference_photo.dart';

import 'cat_database_schema.dart';
import 'repositories/habitat_cache_repository.dart';
import 'repositories/sync_metadata_repository.dart';
import 'repositories/reference_photo_repository.dart';
import 'repositories/catalog_repository.dart';

class CatDatabase {
  CatDatabase() : _open = null;
  CatDatabase.withConnection(this._open);
  final Future<Database> Function()? _open;
  Future<Database>? _opening;

  static final CatDatabase instance = CatDatabase();

  Database? _database;

  Future<Database> get database {
    if (_database case final db?) return Future.value(db);
    return _opening ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    try {
      final db = await Future<Database>.sync(_open ?? _initDatabase);
      _database = db;
      return db;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() => CatDatabaseSchema().open();
  late final HabitatCacheRepository habitatCacheRepository =
      HabitatCacheRepository(() => database);
  late final SyncMetadataRepository syncMetadataRepository =
      SyncMetadataRepository(() => database);
  late final ReferencePhotoRepository referencePhotoRepository =
      ReferencePhotoRepository(() => database);
  late final CatalogRepository catalogRepository = CatalogRepository(
    () => database,
  );
  Future<Map<String, dynamic>?> readHabitatCache(String ownerId) =>
      habitatCacheRepository.readHabitatCache(ownerId);

  Future<void> saveHabitatSnapshot(
    String ownerId,
    Map<String, dynamic> snapshot,
  ) => habitatCacheRepository.saveHabitatSnapshot(ownerId, snapshot);

  Future<void> saveHabitatDraft(String ownerId, Map<String, dynamic>? draft) =>
      habitatCacheRepository.saveHabitatDraft(ownerId, draft);

  Future<void> saveHabitatPendingPurchases(
    String ownerId,
    Map<String, String> pendingPurchases,
  ) => habitatCacheRepository.saveHabitatPendingPurchases(
    ownerId,
    pendingPurchases,
  );

  Future<void> insertCat(Cat cat) => catalogRepository.insertCat(cat);

  Future<void> insertCatWithAnalysis(Cat cat, CatAnalysis analysis) =>
      catalogRepository.insertCatWithAnalysis(cat, analysis);

  Future<List<Cat>> getCats({String? ownerId}) =>
      catalogRepository.getCats(ownerId: ownerId);

  Future<void> queueSighting(Map<String, dynamic> payload) =>
      syncMetadataRepository.queueSighting(payload);

  Future<List<Map<String, dynamic>>> queuedSightings() =>
      syncMetadataRepository.queuedSightings();

  Future<void> removeQueuedSighting(String key) =>
      syncMetadataRepository.removeQueuedSighting(key);

  Future<int> getNextCaptureNumber() =>
      catalogRepository.getNextCaptureNumber();

  Future<void> updateCatName(String id, String? name) =>
      catalogRepository.updateCatName(id, name);

  Future<void> updateCatDetails(
    String id, {
    String? name,
    String? microchip,
    String? collar,
    String? distinguishingMarks,
  }) => catalogRepository.updateCatDetails(
    id,
    name: name,
    microchip: microchip,
    collar: collar,
    distinguishingMarks: distinguishingMarks,
  );

  Future<void> updateCatLocation(
    String id, {
    required double latitude,
    required double longitude,
    String? locationName,
  }) => catalogRepository.updateCatLocation(
    id,
    latitude: latitude,
    longitude: longitude,
    locationName: locationName,
  );

  Future<void> updateCatStatus(
    String id,
    String status, {
    int? automaticRetryCount,
  }) => catalogRepository.updateCatStatus(
    id,
    status,
    automaticRetryCount: automaticRetryCount,
  );

  Future<void> updateCatFavorite(String id, bool isFavorite) =>
      catalogRepository.updateCatFavorite(id, isFavorite);

  Future<void> updateCatNotes(String id, String? notes) =>
      catalogRepository.updateCatNotes(id, notes);

  Future<void> deleteCatWithAnalysis(String catId) =>
      catalogRepository.deleteCatWithAnalysis(catId);

  Future<void> upsertAnalysis(CatAnalysis analysis) =>
      catalogRepository.upsertAnalysis(analysis);

  Future<String> getOrCreateDeviceId() =>
      syncMetadataRepository.getOrCreateDeviceId();

  Future<void> bindUnownedCatsToAccount(String ownerId, String deviceId) =>
      syncMetadataRepository.bindUnownedCatsToAccount(ownerId, deviceId);

  Future<List<Cat>> getCatsForSync(String ownerId) =>
      syncMetadataRepository.getCatsForSync(ownerId);

  Future<void> markSynced(String id, int revision) =>
      syncMetadataRepository.markSynced(id, revision);

  Future<void> markDeleted(String id, String ownerId, String deviceId) =>
      syncMetadataRepository.markDeleted(id, ownerId, deviceId);

  Future<String> getSyncCursor(String ownerId) =>
      syncMetadataRepository.getSyncCursor(ownerId);

  Future<void> setSyncCursor(String ownerId, int cursor) =>
      syncMetadataRepository.setSyncCursor(ownerId, cursor);

  Future<List<CatAnalysis>> getAnalyses() => catalogRepository.getAnalyses();

  Future<List<CatAnalysis>> getAnalysesForCats(Iterable<String> catIds) =>
      catalogRepository.getAnalysesForCats(catIds);

  Future<Map<String, List<CatReferencePhoto>>> getReferencePhotosForCats(
    Iterable<String> catIds,
  ) => referencePhotoRepository.getReferencePhotosForCats(catIds);

  Future<CatAnalysis?> getAnalysisByCatId(String catId) =>
      catalogRepository.getAnalysisByCatId(catId);

  Future<Cat?> getCatById(String id) => catalogRepository.getCatById(id);

  Future<void> replaceCatFromSync(Cat cat, {CatAnalysis? analysis}) =>
      catalogRepository.replaceCatFromSync(cat, analysis: analysis);

  Future<List<CatReferencePhoto>> getReferencePhotos(String catId) =>
      referencePhotoRepository.getReferencePhotos(catId);

  Future<List<CatReferencePhoto>> getDirtyReferencePhotos(String ownerId) =>
      referencePhotoRepository.getDirtyReferencePhotos(ownerId);

  Future<void> upsertReferencePhoto(CatReferencePhoto photo) =>
      referencePhotoRepository.upsertReferencePhoto(photo);

  Future<void> markReferenceSynced(
    String catId,
    String kind, {
    String status = 'ready',
  }) =>
      referencePhotoRepository.markReferenceSynced(catId, kind, status: status);

  Future<void> markReferenceDeleted(String catId, String kind) =>
      referencePhotoRepository.markReferenceDeleted(catId, kind);

  Future<void> deleteReferencePhotoRecord(String catId, String kind) =>
      referencePhotoRepository.deleteReferencePhotoRecord(catId, kind);
}
