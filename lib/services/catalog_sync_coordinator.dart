import '../data/cat_database.dart';
import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../models/cat_reference_photo.dart';
import '../stores/session_store.dart';
import 'catalog_sync_service.dart';
import 'vision_api_service.dart';
import 'favorites_manager.dart';

class CatalogSnapshot {
  CatalogSnapshot(this.ownerId, this.cats, this.analyses, this.references);
  final String? ownerId;
  final List<Cat> cats;
  final List<CatAnalysis> analyses;
  final Map<String, List<CatReferencePhoto>> references;
}

class CatalogSyncCoordinator {
  CatalogSyncCoordinator(
    this.session,
    this.database,
    this.syncService,
    this.vision,
  );
  final SessionStore session;
  final CatDatabase database;
  final CatalogSyncService syncService;
  final VisionApiService vision;
  Future<CatalogSnapshot?> synchronize() async {
    final owner = session.session?.userId;
    if (owner == null ||
        !await syncService.sync() ||
        owner != session.session?.userId) {
      return null;
    }
    await sendQueuedSightings();
    if (owner != session.session?.userId) return null;
    await FavoritesManager.instance.syncWithServer(session);
    final snapshot = await read(owner);
    return owner == session.session?.userId ? snapshot : null;
  }

  Future<CatalogSnapshot> read(String? owner) async {
    final cats = await database.getCats(ownerId: owner);
    final ids = cats.map((cat) => cat.id).toSet();
    final analyses = await database.getAnalysesForCats(ids);
    final references = await database.getReferencePhotosForCats(ids);
    return CatalogSnapshot(owner, cats, analyses, references);
  }

  bool _sendingSightings = false;
  Future<void> sendQueuedSightings() async {
    if (_sendingSightings || !session.isSignedIn) return;
    _sendingSightings = true;
    try {
      for (final item in await database.queuedSightings()) {
        final cat = await database.getCatById(item['cat_client_id'] as String);
        if (cat == null || cat.deletedAt != null) {
          await database.removeQueuedSighting(item['queue_key'] as String);
          continue;
        }
        if (cat.ownerId != session.session?.userId) continue;
        await vision.createSighting(
          catId: cat.id,
          clientEventId: item['queue_key'] as String,
          latitude: (item['latitude'] as num).toDouble(),
          longitude: (item['longitude'] as num).toDouble(),
          note: item['note'] as String?,
          observedAt: DateTime.parse(item['observed_at'] as String),
        );
        await database.removeQueuedSighting(item['queue_key'] as String);
      }
    } catch (_) {
      /* Persisted entries retry on the next successful sync. */
    } finally {
      _sendingSightings = false;
    }
  }
}
