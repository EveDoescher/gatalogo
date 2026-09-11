import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import '../data/cat_database.dart';
import '../models/cat.dart';
import '../models/cat_analysis.dart';
import '../models/cat_reference_photo.dart';
import '../stores/session_store.dart';

class CatalogSyncService {
  CatalogSyncService(this._sessionStore, {CatDatabase? database})
    : _database = database ?? CatDatabase.instance;

  final SessionStore _sessionStore;
  final CatDatabase _database;

  Future<bool>? _inFlight;
  Future<bool> sync() =>
      _inFlight ??= _sync().whenComplete(() => _inFlight = null);

  Future<bool> _sync() async {
    final session = _sessionStore.session;
    if (session == null) return false;
    final deviceId = await _sessionStore.deviceId();
    await _database.bindUnownedCatsToAccount(session.userId, deviceId);
    final token = await _sessionStore.accessToken();
    if (token == null) return false;
    try {
      await _pushDirtyCats(session.userId, deviceId, token);
      await _pushDirtyReferencePhotos(session.userId, token);
      await _pullChanges(session.userId, deviceId, token);
      return true;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on TimeoutException {
      return false;
    } on HttpException {
      return false;
    }
  }

  Future<void> _pushDirtyCats(
    String ownerId,
    String deviceId,
    String token, {
    bool retried = false,
  }) async {
    final cats = await _database.getCatsForSync(ownerId);
    if (cats.isEmpty) return;
    final analyses = <String, CatAnalysis?>{};
    for (final cat in cats) {
      analyses[cat.id] = await _database.getAnalysisByCatId(cat.id);
    }
    final response = await _authorizedPost('/sync/push', token, {
      'operations': cats
          .map(
            (cat) => {
              'client_id': cat.id,
              'updated_at': cat.localUpdatedAt.toUtc().toIso8601String(),
              'device_id': cat.syncDeviceId ?? deviceId,
              'deleted_at': cat.deletedAt?.toUtc().toIso8601String(),
              'payload': _payloadFor(cat),
              'analysis': analyses[cat.id]?.toApiJson(),
            },
          )
          .toList(),
    });
    if (response.statusCode == 401 && !retried) {
      final refreshed = await _sessionStore.accessToken(refresh: true);
      if (refreshed != null) {
        return _pushDirtyCats(ownerId, deviceId, refreshed, retried: true);
      }
    }
    if (response.statusCode >= 300) {
      throw const HttpException('Envio dos registros adiado.');
    }
    for (final cat in cats.where((cat) => cat.deletedAt == null)) {
      final photo = File(cat.photoPath);
      if (!await photo.exists()) continue;
      await _uploadPhoto(cat, deviceId, token);
    }
  }

  Future<void> _pushDirtyReferencePhotos(String ownerId, String token) async {
    final photos = await _database.getDirtyReferencePhotos(ownerId);
    for (final photo in photos) {
      if (photo.deletedAt != null) {
        final response = await http.delete(
          Uri.parse(
            '${ApiConfig.baseUrl}/sync/cats/${photo.catId}/reference-photos/${photo.kind}',
          ),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 204 || response.statusCode == 404) {
          await _database.deleteReferencePhotoRecord(photo.catId, photo.kind);
        } else {
          throw const HttpException('Remoção da foto adiada.');
        }
        continue;
      }
      final file = File(photo.localPath);
      if (!await file.exists()) continue;
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(
          '${ApiConfig.baseUrl}/sync/cats/${photo.catId}/reference-photos/${photo.kind}',
        ),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(
        await http.MultipartFile.fromPath('image', photo.localPath),
      );
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 202 || response.statusCode == 200) {
        await _database.markReferenceSynced(
          photo.catId,
          photo.kind,
          status: 'analyzing',
        );
      } else {
        throw const HttpException('Envio da foto complementar adiado.');
      }
    }
  }

  Future<void> _uploadPhoto(
    Cat cat,
    String deviceId,
    String token, {
    bool retried = false,
  }) async {
    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('${ApiConfig.baseUrl}/sync/cats/${cat.id}/photo'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['updated_at'] = cat.localUpdatedAt.toUtc().toIso8601String();
    request.fields['device_id'] = cat.syncDeviceId ?? deviceId;
    request.files.add(
      await http.MultipartFile.fromPath('image', cat.photoPath),
    );
    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 30)),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode == 401 && !retried) {
      final refreshed = await _sessionStore.accessToken(refresh: true);
      if (refreshed != null) {
        return _uploadPhoto(cat, deviceId, refreshed, retried: true);
      }
    }
    if (response.statusCode >= 300) {
      throw const HttpException('Envio da foto adiado.');
    }
  }

  Future<void> _pullChanges(
    String ownerId,
    String deviceId,
    String token, {
    bool retried = false,
  }) async {
    final cursor = int.tryParse(await _database.getSyncCursor(ownerId)) ?? 0;
    final response = await _authorizedGet('/sync/pull?cursor=$cursor', token);
    if (response.statusCode == 401 && !retried) {
      final refreshed = await _sessionStore.accessToken(refresh: true);
      if (refreshed != null) {
        return _pullChanges(ownerId, deviceId, refreshed, retried: true);
      }
    }
    if (response.statusCode != 200) {
      throw const HttpException('Recebimento dos registros adiado.');
    }
    final body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    for (final raw in (body['changes'] as List<dynamic>? ?? const [])) {
      await _applyRemoteChange(
        ownerId,
        deviceId,
        Map<String, dynamic>.from(raw as Map),
        token,
      );
    }
    await _database.setSyncCursor(
      ownerId,
      body['next_cursor'] as int? ?? cursor,
    );
  }

  Future<void> _applyRemoteChange(
    String ownerId,
    String deviceId,
    Map<String, dynamic> record,
    String token,
  ) async {
    final id = record['client_id'] as String;
    final existing = await _database.getCatById(id);
    final deletedAt = record['deleted_at'] as String?;
    final revision = record['revision'] as int? ?? 0;
    final remoteUpdatedAt = DateTime.parse(record['updated_at'] as String)
        .toUtc();
    if (existing != null &&
        existing.syncState == 'dirty' &&
        existing.localUpdatedAt.isAfter(remoteUpdatedAt)) {
      return;
    }
    if (deletedAt != null) {
      if (existing != null) {
        await _database.markDeleted(id, ownerId, deviceId);
        await _database.markSynced(id, revision);
        await _removeManagedPhoto(existing.photoPath);
      }
      return;
    }
    final payload = Map<String, dynamic>.from(
      record['payload'] as Map? ?? const {},
    );
    var photoPath = existing?.photoPath;
    if (photoPath == null ||
        !await File(photoPath).exists() ||
        (existing != null &&
            remoteUpdatedAt.isAfter(existing.localUpdatedAt))) {
      photoPath = await _downloadPhoto(
        id,
        record['photo_url'] as String?,
        token,
      );
    }
    if (photoPath == null) {
      throw const HttpException('Foto ainda não recebida.');
    }
    final cat = Cat(
      isOwned: payload['is_owned'] == 1 || payload['is_owned'] == true,
      id: id,
      captureNumber:
          (payload['capture_number'] as num?)?.toInt() ??
          existing?.captureNumber ??
          0,
      name: payload['name'] as String?,
      photoPath: photoPath,
      capturedAt:
          DateTime.tryParse(payload['captured_at'] as String? ?? '') ??
          DateTime.now(),
      latitude: (payload['latitude'] as num?)?.toDouble(),
      longitude: (payload['longitude'] as num?)?.toDouble(),
      locationName: payload['location_name'] as String?,
      status: payload['status'] as String? ?? 'completed',
      automaticRetryCount:
          (payload['automatic_retry_count'] as num?)?.toInt() ?? 0,
      ownerId: ownerId,
      syncState: 'synced',
      localUpdatedAt: DateTime.parse(record['updated_at'] as String).toUtc(),
      syncDeviceId: record['device_id'] as String? ?? deviceId,
      syncRevision: revision,
    );
    CatAnalysis? analysis;
    final analysisRaw = record['analysis'];
    if (analysisRaw is Map) {
      final normalized = Map<String, dynamic>.from(analysisRaw)
        ..['cat_id'] = id;
      if (normalized['coat_type'] != null) {
        analysis = CatAnalysis.fromApiJson(normalized);
      }
    }
    await _database.replaceCatFromSync(cat, analysis: analysis);
    await _applyReferencePhotos(id, record['reference_photos'], token);
  }

  Future<void> _applyReferencePhotos(
    String catId,
    dynamic raw,
    String token,
  ) async {
    if (raw is! List) return;
    final remoteKinds = raw
        .whereType<Map>()
        .map((item) => item['kind'])
        .toSet();
    for (final local in await _database.getReferencePhotos(catId)) {
      if (local.syncState == 'synced' && !remoteKinds.contains(local.kind)) {
        await _database.deleteReferencePhotoRecord(catId, local.kind);
      }
    }
    for (final item in raw.whereType<Map>()) {
      final data = Map<String, dynamic>.from(item);
      final kind = data['kind'] as String?;
      final url = data['photo_url'] as String?;
      if (kind == null || url == null) continue;
      final local = (await _database.getReferencePhotos(catId))
          .where((photo) => photo.kind == kind);
      if (local.isNotEmpty && local.first.syncState == 'dirty') continue;
      final path = await _downloadManagedAsset(
        catId,
        'references/$kind.jpg',
        url,
        token,
      );
      if (path == null) continue;
      await _database.upsertReferencePhoto(
        CatReferencePhoto(
          catId: catId,
          kind: kind,
          localPath: path,
          status: data['status'] as String? ?? 'ready',
          updatedAt:
              DateTime.tryParse(data['updated_at'] as String? ?? '')?.toUtc() ??
              DateTime.now().toUtc(),
          syncState: 'synced',
        ),
      );
    }
  }

  Future<String?> _downloadPhoto(
    String id,
    String? relativeUrl,
    String token,
  ) async {
    if (relativeUrl == null) return null;
    final response = await _authorizedGet(relativeUrl, token);
    if (response.statusCode != 200) return null;
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(docs.path, 'cats'));
    await directory.create(recursive: true);
    final path = p.join(directory.path, '$id.jpg');
    await File(path).writeAsBytes(response.bodyBytes, flush: true);
    return path;
  }

  Future<String?> _downloadManagedAsset(
    String catId,
    String relativePath,
    String? url,
    String token,
  ) async {
    if (url == null) return null;
    final response = await _authorizedGet(url, token);
    if (response.statusCode != 200) return null;
    final docs = await getApplicationDocumentsDirectory();
    final path = p.join(docs.path, 'cats', catId, relativePath);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return path;
  }

  Future<void> _removeManagedPhoto(String photoPath) async {
    final docs = await getApplicationDocumentsDirectory();
    if (!p.isWithin(p.join(docs.path, 'cats'), p.normalize(photoPath))) return;
    final file = File(photoPath);
    if (await file.exists()) await file.delete();
  }

  Map<String, dynamic> _payloadFor(Cat cat) {
    final map = cat.toMap();
    for (final key in [
      'id',
      'owner_id',
      'photo_path',
      'sync_state',
      'local_updated_at',
      'sync_device_id',
      'sync_revision',
      'deleted_at',
    ]) {
      map.remove(key);
    }
    return map;
  }

  Future<http.Response> _authorizedPost(
    String path,
    String token,
    Map<String, dynamic> body,
  ) => http
      .post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 30));
  Future<http.Response> _authorizedGet(String path, String token) => http
      .get(
        Uri.parse(path.startsWith('http') ? path : '${ApiConfig.baseUrl}$path'),
        headers: {'Authorization': 'Bearer $token'},
      )
      .timeout(const Duration(seconds: 30));
}
