import 'dart:async';
import 'dart:convert';

import 'habitat_navigation.dart';
import '../models/habitat.dart';
import '../models/quintal_snapshot.dart';
export '../models/habitat.dart';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/cat_database.dart';
import '../data/habitat_repository.dart';
import '../stores/cat_store.dart';
import '../stores/session_store.dart';
import 'product_api_service.dart';

part 'habitat_catalog.g.dart';
part 'habitat_care.dart';
part 'habitat_encounters.dart';
part 'habitat_layout.dart';
part 'quintal_production.dart';

class HabitatConflictException implements Exception {}

class HabitatService extends ChangeNotifier {
  /// Read-only art metadata shared with reward previews outside the editor.
  static HabitatShopItem? catalogItem(String sku) =>
      _offlineShop.where((item) => item.sku == sku).firstOrNull;

  HabitatService(
    this.session,
    this.catStore, {
    CatDatabase? database,
    ProductApiService? api,
    HabitatRepository? repository,
  }) : _repository =
           repository ??
           HabitatRepository(
             database ?? CatDatabase.instance,
             api ?? ProductApiService(session),
           );

  final SessionStore session;
  final CatStore catStore;
  final HabitatRepository _repository;

  static const gridSize = 8;
  static const maxPlaced = 24;
  static const _layoutRulesVersion = 3;
  static const _starterSkus = [
    'cat_bed',
    'small_tree',
    'small_bush',
    'red_flowers',
  ];

  int satisfaction = 0;
  Map<String, dynamic>? pendingGift;
  bool _visitorRequest = false;
  void _notifyVisitors() {
    if (!_disposed) notifyListeners();
  }

  int balance = 0;
  int revision = 0;
  int expansionLevel = 0;
  bool freeShop = false;
  int? _nextExpansionPrice;
  bool layoutAdjusted = false;
  Map<String, (int, int)> catAnchors = {};
  Set<(int, int)> buildableCells = yardCells(0);
  int get catCapacity => 3 + expansionLevel;
  int get decorationCapacity => 24 + 8 * expansionLevel;
  int? get nextExpansionPrice => expansionLevel < 3
      ? (freeShop
            ? 0
            : _nextExpansionPrice ?? const [80, 180, 320][expansionLevel])
      : null;

  static Set<(int, int)> yardCells(int level) {
    var cells = <(int, int)>{
      for (var x = 0; x < 8; x++)
        for (var y = 0; y < 8; y++) (x, y),
      for (var x = 2; x <= 5; x++) (x, -1),
      for (var y = 2; y <= 5; y++) (-1, y),
      for (var y = 1; y <= 6; y++) (8, y),
      for (var x = 2; x <= 6; x++) (x, 8),
    };
    for (var i = 0; i < level; i++) {
      cells = {
        ...cells,
        for (final cell in cells) (cell.$1 + 1, cell.$2),
        for (final cell in cells) (cell.$1 - 1, cell.$2),
        for (final cell in cells) (cell.$1, cell.$2 + 1),
        for (final cell in cells) (cell.$1, cell.$2 - 1),
      };
    }
    return cells;
  }

  bool loading = false;
  bool offline = false;
  bool hasDraft = false;
  List<HabitatItem> items = [];
  List<HabitatCat> cats = [];
  List<String> selectedCatIds = [];
  List<HabitatShopItem> _shop = _offlineShop;
  Map<String, HabitatShopItem> _catalog = {
    for (final item in _offlineShop) item.sku: item,
  };
  List<HabitatShopItem> get shop => _shop;
  set shop(List<HabitatShopItem> value) {
    _shop = value;
    _catalog = {for (final item in value) item.sku: item};
  }

  Map<String, int> rewards = const {
    'catalog': 25,
    'reference': 3,
    'sighting': 8,
    'post': 10,
    'comment': 3,
    'like': 1,
    'share': 3,
    'care': 3,
  };
  Map<String, int> dailyLimits = const {
    'reference': 2,
    'sighting': 3,
    'post': 2,
    'comment': 4,
    'like': 5,
    'share': 2,
    'care': 1,
  };
  Map<String, String> _pendingPurchases = {};
  Map<String, dynamic> care = {};
  QuintalSnapshot _production = QuintalSnapshot({});
  QuintalSnapshot get productionState => _production;
  Map<String, dynamic> get production => _production.wire;
  set production(Map<String, dynamic> value) =>
      _production = QuintalSnapshot(value);
  Map<String, String> _pendingProduction = {};
  bool productionBusy = false;
  int _productionGeneration = 0;
  bool productionOffline = false;
  Map<String, dynamic> lastProductionProgress = {};
  Map<String, String> _pendingInteractions = {};
  Duration _clockOffset = Duration.zero;
  bool _disposed = false;
  bool caring = false;
  void _setCaring(bool value) {
    caring = value;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void>? _syncInFlight;
  int _editVersion = 0;

  String get _ownerId => session.session?.userId ?? 'guest';
  String? _loadedOwner;
  HabitatShopItem definition(String sku) =>
      _catalog[sku] ?? (throw StateError('Item desconhecido no Quintal: $sku'));

  Future<void> load() async {
    if (_disposed) return;
    final owner = _ownerId;
    if (_loadedOwner != owner) {
      _loadedOwner = owner;
      _readSnapshot({});
      shop = _offlineShop;
      hasDraft = false;
      _clockOffset = Duration.zero;
      _pendingInteractions.clear();
      production = {};
      lastProductionProgress = {};
      _pendingProduction.clear();
    }
    loading = true;
    notifyListeners();
    Map<String, dynamic>? cached;
    try {
      cached = await _repository.readCache(owner);
    } catch (_) {
      // The scene can still open if local storage is temporarily unavailable.
    }
    if (_disposed || owner != _ownerId) return;
    _pendingPurchases = {
      for (final entry
          in (cached?['pending_purchases'] as Map? ?? const {}).entries)
        entry.key.toString(): entry.value.toString(),
    };
    if (cached?['snapshot'] case final Map raw) {
      _readSnapshot(Map<String, dynamic>.from(raw), cached: true);
    } else if (!session.isSignedIn) {
      _seedGuest();
    }
    final draft = cached?['draft'];
    if (draft is Map) {
      _applyDraft(Map<String, dynamic>.from(draft));
      hasDraft = true;
    }
    final snapshot = cached?['snapshot'];
    if (snapshot is Map &&
        ((snapshot['layout_rules_version'] as num?)?.toInt() ?? 1) <
            _layoutRulesVersion) {
      // Offline layouts must use the same corrected bed axes as the API.
      shop = [
        for (final item in shop)
          if (item.sku == 'cat_bed')
            HabitatShopItem.fromMap({...item.toMap(), 'width': 1, 'height': 2})
          else
            item,
      ];
      if (_normalizeDraftLayout()) {
        hasDraft = true;
        await _repository.saveDraft(owner, _draft());
        if (_disposed || owner != _ownerId) return;
      }
      await _persistSnapshot();
      if (_disposed || owner != _ownerId) return;
    }
    if (!session.isSignedIn) {
      _readLocalCats();
      loading = false;
      offline = true;
      notifyListeners();
      return;
    }
    try {
      final results = await Future.wait([
        _repository.snapshot(),
        _repository.catalog(),
      ]);
      if (_disposed || owner != _ownerId) return;
      _readSnapshot(results.first);
      shop = ((results.last['items'] as List?) ?? const [])
          .map(
            (entry) => HabitatShopItem.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
      if (shop.isEmpty) shop = _offlineShop;
      rewards = _intMap(results.last['rewards']) ?? rewards;
      dailyLimits = _intMap(results.last['daily_limits']) ?? dailyLimits;
      if (draft is Map) {
        _applyDraft(Map<String, dynamic>.from(draft));
        if (_normalizeDraftLayout()) {
          await _repository.saveDraft(_ownerId, _draft());
          if (_disposed || owner != _ownerId) return;
        }
      }
      await _persistSnapshot();
      if (_disposed || owner != _ownerId) return;
      offline = false;
      await refreshProduction();
    } catch (_) {
      if (_disposed || owner != _ownerId) return;
      offline = true;
      if (items.isEmpty && !session.isSignedIn) _seedGuest();
    } finally {
      if (!_disposed && owner == _ownerId) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _seedGuest() {
    care = {};
    pendingGift = null;
    satisfaction = 0;
    freeShop = false;
    _nextExpansionPrice = null;
    HabitatNavigation.hasGift.value = false;
    _pendingInteractions.clear();
    _clockOffset = Duration.zero;
    items = [
      for (final sku in _starterSkus) HabitatItem(id: 'guest-$sku', sku: sku),
    ];
    shop = _offlineShop;
    balance = 0;
    revision = 0;
    expansionLevel = 0;
    buildableCells = yardCells(0);
    catAnchors = {};
  }

  void _readLocalCats() {
    cats = [
      for (final cat in catStore.pets)
        HabitatCat(
          id: cat.id,
          name: cat.displayName,
          primaryColor:
              catStore.analysisFor(cat.id)?.primaryColor ??
              catStore
                  .analysisFor(cat.id)
                  ?.patternMap?['base_color']
                  ?.toString(),
          coatType:
              catStore.analysisFor(cat.id)?.coatType ??
              catStore.analysisFor(cat.id)?.patternMap?['pattern']?.toString(),
          coatColors: [
            for (final c in catStore.analysisFor(cat.id)?.colors ?? []) c.name,
            ...((catStore.analysisFor(cat.id)?.patternMap?['accent_colors']
                        as List?)
                    ?.whereType<String>() ??
                const <String>[]),
          ],
        ),
    ];
  }

  void _readSnapshot(Map<String, dynamic> data, {bool cached = false}) {
    if (cached) {
      lastProductionProgress = Map<String, dynamic>.from(
        data['last_production_progress'] as Map? ?? const {},
      );
      production = Map<String, dynamic>.from(
        data['production'] as Map? ?? const {},
      );
      _pendingProduction = Map<String, String>.from(
        data['pending_production'] as Map? ?? const {},
      );
    }
    care = Map<String, dynamic>.from(data['care'] as Map? ?? const {});
    if (cached) {
      _clockOffset = Duration(
        milliseconds: (data['care_clock_offset_ms'] as num?)?.toInt() ?? 0,
      );
      _pendingInteractions = {
        for (final entry
            in (data['pending_interactions'] as Map? ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      };
    } else if (DateTime.tryParse(care['server_now']?.toString() ?? '')
        case final serverTime?) {
      _clockOffset = serverTime.difference(DateTime.now().toUtc());
    }
    balance = (data['balance'] as num?)?.toInt() ?? 0;
    revision = (data['revision'] as num?)?.toInt() ?? 0;
    satisfaction =
        ((data['satisfaction'] as Map?)?['value'] as num?)?.toInt() ?? 0;
    pendingGift = data['pending_gift'] is Map
        ? Map<String, dynamic>.from(data['pending_gift'])
        : null;
    HabitatNavigation.hasGift.value = pendingGift?['state'] == 'available';
    expansionLevel = (data['expansion_level'] as num?)?.toInt() ?? 0;
    freeShop = data['free_shop'] == true;
    _nextExpansionPrice = (data['next_expansion_price'] as num?)?.toInt();
    layoutAdjusted = data['layout_adjusted'] == true;
    buildableCells = data['buildable_cells'] is List
        ? {
            for (final cell in data['buildable_cells'] as List)
              ((cell[0] as num).toInt(), (cell[1] as num).toInt()),
          }
        : yardCells(expansionLevel);
    catAnchors = {
      for (final entry in (data['cat_anchors'] as Map? ?? const {}).entries)
        if (entry.value is List && (entry.value as List).length == 2)
          entry.key.toString(): (
            (entry.value[0] as num).toInt(),
            (entry.value[1] as num).toInt(),
          ),
    };
    items = ((data['items'] as List?) ?? const [])
        .map(
          (entry) =>
              HabitatItem.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    cats = ((data['cats'] as List?) ?? const [])
        .map(
          (entry) =>
              HabitatCat.fromMap(Map<String, dynamic>.from(entry as Map)),
        )
        .toList();
    selectedCatIds = ((data['selected_cat_ids'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();
    if (data['shop'] is List) {
      shop = (data['shop'] as List)
          .map(
            (entry) => HabitatShopItem.fromMap(
              Map<String, dynamic>.from(entry as Map),
            ),
          )
          .toList();
    }
    rewards = _intMap(data['rewards']) ?? rewards;
    dailyLimits = _intMap(data['daily_limits']) ?? dailyLimits;
  }

  Map<String, int>? _intMap(Object? value) => value is Map
      ? {
          for (final entry in value.entries)
            entry.key.toString(): (entry.value as num).toInt(),
        }
      : null;

  Map<String, dynamic> _snapshot() => {
    'production': production,
    'last_production_progress': lastProductionProgress,
    'pending_production': _pendingProduction,
    'care': care,
    'care_clock_offset_ms': _clockOffset.inMilliseconds,
    'pending_interactions': _pendingInteractions,
    'layout_rules_version': _layoutRulesVersion,
    'balance': balance,
    'revision': revision,
    'expansion_level': expansionLevel,
    'satisfaction': {'value': satisfaction},
    'pending_gift': pendingGift,
    'free_shop': freeShop,
    'next_expansion_price': nextExpansionPrice,
    'buildable_cells': [
      for (final cell in buildableCells) [cell.$1, cell.$2],
    ],
    'cat_anchors': {
      for (final entry in catAnchors.entries)
        entry.key: [entry.value.$1, entry.value.$2],
    },
    'items': items.map((item) => item.toMap()).toList(),
    'cats': cats.map((cat) => cat.toMap()).toList(),
    'selected_cat_ids': selectedCatIds,
    'shop': shop.map((entry) => entry.toMap()).toList(),
    'rewards': rewards,
    'daily_limits': dailyLimits,
  };

  Future<void> _persistSnapshot() =>
      _repository.saveSnapshot(_ownerId, _snapshot());

  Map<String, dynamic> _draft() => {
    'production_rules_version': production.isEmpty ? 0 : 1,
    'expected_revision': revision,
    'placements': [
      for (final item in items.where((item) => item.isPlaced))
        {
          'item_id': item.id,
          'x': item.x,
          'y': item.y,
          'rotation': item.rotation,
        },
    ],
    'selected_cat_ids': selectedCatIds,
    'cat_anchors': {
      for (final entry in catAnchors.entries)
        if (selectedCatIds.contains(entry.key))
          entry.key: [entry.value.$1, entry.value.$2],
    },
  };

  void _applyDraft(Map<String, dynamic> draft) {
    final positions = <String, Map<String, dynamic>>{
      for (final raw in (draft['placements'] as List? ?? const []))
        Map<String, dynamic>.from(raw as Map)['item_id'].toString():
            Map<String, dynamic>.from(raw),
    };
    items = [
      for (final item in items)
        if (positions[item.id] case final position?)
          item.at(
            (position['x'] as num).toInt(),
            (position['y'] as num).toInt(),
            (position['rotation'] as num).toInt(),
          )
        else
          item.at(null, null, 0),
    ];
    selectedCatIds = ((draft['selected_cat_ids'] as List?) ?? const [])
        .map((entry) => entry.toString())
        .toList();
    if (draft['cat_anchors'] is Map) {
      catAnchors = {
        for (final entry in (draft['cat_anchors'] as Map).entries)
          if (entry.value is List && (entry.value as List).length == 2)
            entry.key.toString(): (
              (entry.value[0] as num).toInt(),
              (entry.value[1] as num).toInt(),
            ),
      };
    }
  }

  List<(int, int)> _cellsNearestTo((int, int) origin) =>
      buildableCells.toList()..sort((a, b) {
        final distanceA = (a.$1 - origin.$1).abs() + (a.$2 - origin.$2).abs();
        final distanceB = (b.$1 - origin.$1).abs() + (b.$2 - origin.$2).abs();
        if (distanceA != distanceB) return distanceA.compareTo(distanceB);
        if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
        return a.$1.compareTo(b.$1);
      });

  bool _normalizeDraftLayout() {
    final placed = items.where((item) => item.isPlaced).toList()
      ..sort((a, b) {
        final first = definition(a.sku);
        final second = definition(b.sku);
        if (first.isGround != second.isGround) return first.isGround ? -1 : 1;
        return (second.width * second.height).compareTo(
          first.width * first.height,
        );
      });
    final original = {for (final item in placed) item.id: (item.x!, item.y!)};
    final previousAnchors = Map<String, (int, int)>.of(catAnchors);
    catAnchors = {};
    items = [for (final item in items) item.at(null, null, 0)];
    var adjusted = false;
    for (final item in placed) {
      final origin = original[item.id]!;
      final rotation = definition(item.sku).rotatable ? item.rotation : 0;
      final position = _cellsNearestTo(origin)
          .where((cell) => canPlace(item, cell.$1, cell.$2, rotation))
          .firstOrNull;
      if (position != null) {
        final index = items.indexWhere((entry) => entry.id == item.id);
        items[index] = item.at(position.$1, position.$2, rotation);
      }
      adjusted |= position != origin;
    }
    for (final id in selectedCatIds) {
      final origin = previousAnchors[id];
      final position = _cellsNearestTo(origin ?? (3, 3))
          .where(
            (cell) =>
                isFreeForCat(cell.$1, cell.$2) &&
                !catAnchors.values.contains(cell),
          )
          .firstOrNull;
      if (position != null) catAnchors[id] = position;
      adjusted |= position != origin;
    }
    layoutAdjusted |= adjusted;
    return adjusted;
  }

  bool canPlace(HabitatItem item, int x, int y, int rotation) =>
      layoutProblem([
        for (final other in items)
          if (other.id != item.id) other,
        item.at(x, y, rotation),
      ]) ==
      null;

  Future<bool> place(String itemId, int x, int y, int rotation) async {
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index < 0 || !canPlace(items[index], x, y, rotation)) return false;
    items[index] = items[index].at(x, y, rotation);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<void> storeItem(String itemId) async {
    final index = items.indexWhere((entry) => entry.id == itemId);
    if (index < 0) return;
    final proposed = [...items];
    proposed[index] = proposed[index].at(null, null, 0);
    if (layoutProblem(proposed) case final problem?) {
      throw ProductApiException(problem);
    }
    items[index] = proposed[index];
    notifyListeners();
    await _saveDraft();
  }

  Future<int> collectGround(Iterable<(int, int)> cells) async {
    final selected = cells.toSet();
    var collected = 0;
    final proposed = [
      for (final item in items)
        if (item.isPlaced &&
            definition(item.sku).isGround &&
            occupiedCells(item).intersection(selected).isNotEmpty)
          (() {
            collected++;
            return item.at(null, null, 0);
          })()
        else
          item,
    ];
    if (layoutProblem(proposed) case final problem?) {
      throw ProductApiException(problem);
    }
    if (collected > 0) {
      items = proposed;
      notifyListeners();
      await _saveDraft();
    }
    return collected;
  }

  Future<void> selectCats(List<String> ids) async {
    if (ids.length > catCapacity ||
        ids.toSet().length != ids.length ||
        ids.any((id) => !cats.any((cat) => cat.id == id))) {
      return;
    }
    selectedCatIds = ids;
    catAnchors.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      catAnchors.putIfAbsent(id, () => firstFreeCatCell() ?? (0, 0));
    }
    notifyListeners();
    await _saveDraft();
  }

  bool isFreeForCat(int x, int y) => walkableCells().contains((x, y));

  (int, int)? firstFreeCatCell() {
    final cells = buildableCells.toList()
      ..sort(
        (a, b) => ((a.$1 - 3).abs() + (a.$2 - 3).abs()).compareTo(
          (b.$1 - 3).abs() + (b.$2 - 3).abs(),
        ),
      );
    for (final cell in cells) {
      if (isFreeForCat(cell.$1, cell.$2) && !catAnchors.values.contains(cell)) {
        return cell;
      }
    }
    return null;
  }

  Future<bool> setCatAnchor(String id, int x, int y) async {
    if (!selectedCatIds.contains(id) ||
        !isFreeForCat(x, y) ||
        catAnchors.entries.any(
          (entry) => entry.key != id && entry.value == (x, y),
        )) {
      return false;
    }
    catAnchors[id] = (x, y);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<bool> addCatAt(String id, int x, int y) async {
    if (selectedCatIds.contains(id)) return setCatAnchor(id, x, y);
    if (selectedCatIds.length >= catCapacity ||
        !cats.any((cat) => cat.id == id) ||
        !isFreeForCat(x, y) ||
        catAnchors.values.contains((x, y))) {
      return false;
    }
    selectedCatIds = [...selectedCatIds, id];
    catAnchors[id] = (x, y);
    notifyListeners();
    await _saveDraft();
    return true;
  }

  Future<int> paintGround(String sku, Iterable<(int, int)> cells) async {
    if (!definition(sku).isGround) return 0;
    var painted = 0;
    for (final cell in cells.toSet()) {
      final available = items
          .where((item) => item.sku == sku && !item.isPlaced)
          .firstOrNull;
      if (available == null || !canPlace(available, cell.$1, cell.$2, 0)) {
        continue;
      }
      final index = items.indexWhere((item) => item.id == available.id);
      items[index] = available.at(cell.$1, cell.$2, 0);
      painted++;
    }
    if (painted > 0) {
      notifyListeners();
      await _saveDraft();
    }
    return painted;
  }

  Future<void> _saveDraft() async {
    _editVersion++;
    hasDraft = true;
    await _repository.saveDraft(_ownerId, _draft());
    if (session.isSignedIn) {
      try {
        await syncLayout();
      } on HabitatConflictException {
        rethrow;
      } catch (_) {
        offline = true;
        notifyListeners();
      }
    } else {
      await _persistSnapshot();
    }
  }

  Future<void> syncLayout({bool overwrite = false}) async {
    while (true) {
      final running = _syncInFlight;
      if (running == null) break;
      await running;
    }
    if (!session.isSignedIn || !hasDraft) return;
    final task = _syncOnce(overwrite: overwrite);
    _syncInFlight = task;
    try {
      await task;
    } finally {
      _syncInFlight = null;
    }
  }

  Future<void> _syncOnce({required bool overwrite}) async {
    try {
      if (overwrite) {
        final remote = await _repository.snapshot();
        revision = (remote['revision'] as num).toInt();
      }
      final version = _editVersion;
      final result = await _repository.layout(_draft());
      final newerDraft = version == _editVersion ? null : _draft();
      _readSnapshot(result);
      final appliedVersion = _editVersion;
      if (newerDraft != null) {
        _applyDraft(newerDraft);
        await _repository.saveDraft(_ownerId, _draft());
      } else {
        await _repository.saveDraft(_ownerId, null);
      }
      hasDraft = newerDraft != null || _editVersion != appliedVersion;
      if (_editVersion != appliedVersion) {
        await _repository.saveDraft(_ownerId, _draft());
      }
      offline = false;
      await _persistSnapshot();
      notifyListeners();
    } on ProductApiException catch (error) {
      if (error.statusCode == 409) throw HabitatConflictException();
      rethrow;
    }
  }

  Future<void> discardDraft() async {
    await _repository.saveDraft(_ownerId, null);
    hasDraft = false;
    await load();
  }

  Future<void> buy(String sku, {int quantity = 1}) async {
    if (!session.isSignedIn) {
      throw const ProductApiException(
        'Entre na sua conta para comprar decorações.',
      );
    }
    if (quantity < 1 ||
        quantity > 20 ||
        (quantity > 1 && !definition(sku).isGround)) {
      throw const ProductApiException('Quantidade inválida para este item.');
    }
    final pendingId = '$sku:$quantity';
    if (_pendingPurchases.keys.any(
      (id) => id.startsWith('$sku:') && id != pendingId,
    )) {
      throw const ProductApiException(
        'Conclua a compra anterior deste item antes de mudar a quantidade.',
      );
    }
    final key = _pendingPurchases[pendingId] ?? const Uuid().v4();
    _pendingPurchases[pendingId] = key;
    await _repository.savePurchases(_ownerId, _pendingPurchases);
    final result = await _repository.purchase({
      'sku': sku,
      'quantity': quantity,
      'idempotency_key': key,
    });
    final purchased = (result['items'] as List? ?? [result['item']]).map(
      (raw) => HabitatItem.fromMap(Map<String, dynamic>.from(raw as Map)),
    );
    for (final item in purchased) {
      if (!items.any((existing) => existing.id == item.id)) {
        items = [...items, item];
      }
    }
    balance = (result['balance'] as num).toInt();
    offline = false;
    await _persistSnapshot();
    _pendingPurchases.remove(pendingId);
    await _repository.savePurchases(_ownerId, _pendingPurchases);
    notifyListeners();
  }

  Future<void> expand() async {
    if (!session.isSignedIn || nextExpansionPrice == null) {
      throw const ProductApiException(
        'Não é possível ampliar este quintal agora.',
      );
    }
    if (hasDraft) await syncLayout();
    final pendingId = 'expansion:$expansionLevel';
    final key = _pendingPurchases[pendingId] ?? const Uuid().v4();
    _pendingPurchases[pendingId] = key;
    await _repository.savePurchases(_ownerId, _pendingPurchases);
    final result = await _repository.expand({
      'expected_level': expansionLevel,
      'idempotency_key': key,
    });
    _readSnapshot(result);
    _pendingPurchases.remove(pendingId);
    await _repository.savePurchases(_ownerId, _pendingPurchases);
    await _persistSnapshot();
    notifyListeners();
  }
}
