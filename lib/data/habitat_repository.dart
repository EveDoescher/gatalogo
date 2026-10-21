import 'cat_database.dart';
import '../services/product_api_service.dart';

/// Owns cache and transport; state reconciliation and command keys belong to the service.
class HabitatRepository {
  HabitatRepository(this.database, this.api);
  final CatDatabase database;
  final ProductApiService api;
  Future<Map<String, dynamic>?> readCache(String owner) =>
      database.readHabitatCache(owner);
  Future<void> saveDraft(String owner, Map<String, dynamic>? draft) =>
      database.saveHabitatDraft(owner, draft);
  Future<void> saveSnapshot(String owner, Map<String, dynamic> snapshot) =>
      database.saveHabitatSnapshot(owner, snapshot);
  Future<void> savePurchases(String owner, Map<String, String> pending) =>
      database.saveHabitatPendingPurchases(owner, pending);
  Future<Map<String, dynamic>> snapshot() => api.get('/app/habitat');
  Future<Map<String, dynamic>> catalog() => api.get('/app/habitat/shop');
  Future<Map<String, dynamic>> layout(Map<String, dynamic> draft) =>
      api.put('/app/habitat/layout', draft);
  Future<Map<String, dynamic>> purchase(Map<String, dynamic> command) =>
      api.post('/app/habitat/purchases', command);
  Future<Map<String, dynamic>> expand(Map<String, dynamic> command) =>
      api.post('/app/habitat/expansions', command);
  Future<Map<String, dynamic>> interact(Map<String, dynamic> command) =>
      api.post('/app/habitat/interactions', command);
  Future<Map<String, dynamic>> visitors() =>
      api.post('/app/habitat/encounters', {});
  Future<Map<String, dynamic>> gift(String id, String action) =>
      api.post('/app/habitat/gifts/$id/$action', {});
  Future<Map<String, dynamic>> production() => api.get('/app/quintal');
  Future<Map<String, dynamic>> produce(Map<String, dynamic> command) =>
      api.post('/app/quintal/operations', command);
}
