/// Immutable habitat values shared by the scene, persistence and API adapters.
class HabitatItem {
  const HabitatItem({
    required this.id,
    required this.sku,
    this.x,
    this.y,
    this.rotation = 0,
    this.careState = const {},
  });

  final String id;
  final String sku;
  final int? x;
  final int? y;
  final int rotation;
  final Map<String, dynamic> careState;

  bool get isPlaced => x != null && y != null;

  HabitatItem at(int? newX, int? newY, int newRotation) => HabitatItem(
    id: id,
    sku: sku,
    x: newX,
    y: newY,
    rotation: newRotation,
    careState: careState,
  );

  factory HabitatItem.fromMap(Map<String, dynamic> value) => HabitatItem(
    id: value['id'].toString(),
    sku: value['sku'].toString(),
    x: (value['x'] as num?)?.toInt(),
    y: (value['y'] as num?)?.toInt(),
    rotation: (value['rotation'] as num?)?.toInt() ?? 0,
    careState: Map<String, dynamic>.from(
      value['care_state'] as Map? ?? const {},
    ),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sku': sku,
    'x': x,
    'y': y,
    'rotation': rotation,
    'care_state': careState,
  };
}

class HabitatShopItem {
  const HabitatShopItem({
    required this.sku,
    required this.name,
    required this.category,
    required this.sprite,
    required this.price,
    required this.width,
    required this.height,
    required this.maxOwned,
    this.basePrice,
    this.purchasable,
    this.layer = 'solid',
    this.rotatable = true,
  });

  final String sku;
  final String name;
  final String category;
  final String sprite;
  String get displaySprite => switch (sku) {
    'food_bowl' => 'production:crafted-cat-food-0-0',
    'water_bowl' => 'production:crafted-cat-water-0-0',
    _ => sprite,
  };
  final int price;
  final int? basePrice;
  final bool? purchasable;
  bool get canBuy => purchasable ?? (basePrice ?? price) > 0;
  final int width;
  final int height;
  final int maxOwned;
  final String layer;
  final bool rotatable;
  bool get isPath => layer == 'path';
  bool get isGround => layer == 'path' || layer == 'terrain';
  bool get isBridge => layer == 'bridge';

  factory HabitatShopItem.fromMap(Map<String, dynamic> value) =>
      HabitatShopItem(
        sku: value['sku'].toString(),
        name: value['name'].toString(),
        category: value['category'].toString(),
        sprite: value['sprite'].toString(),
        price: (value['price'] as num).toInt(),
        basePrice: (value['base_price'] as num?)?.toInt(),
        purchasable: value['purchasable'] as bool?,
        width: (value['width'] as num).toInt(),
        height: (value['height'] as num).toInt(),
        maxOwned: (value['max_owned'] as num).toInt(),
        layer: value['layer']?.toString() ?? 'solid',
        rotatable: value['rotatable'] != false,
      );

  Map<String, dynamic> toMap() => {
    'sku': sku,
    'name': name,
    'category': category,
    'sprite': sprite,
    'price': price,
    'base_price': basePrice,
    'purchasable': purchasable,
    'width': width,
    'height': height,
    'max_owned': maxOwned,
    'layer': layer,
    'rotatable': rotatable,
  };
}

class HabitatCat {
  const HabitatCat({
    required this.id,
    required this.name,
    this.primaryColor,
    this.coatType,
    this.coatColors = const [],
  });

  final String id;
  final String name;
  final String? primaryColor;
  final String? coatType;
  final List<String> coatColors;

  factory HabitatCat.fromMap(Map<String, dynamic> value) => HabitatCat(
    id: value['id'].toString(),
    name: value['name']?.toString() ?? 'Meu gato',
    primaryColor: value['primary_color']?.toString(),
    coatType: value['coat_type']?.toString(),
    coatColors: (value['coat_colors'] as List? ?? const [])
        .whereType<String>()
        .toList(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'primary_color': primaryColor,
    'coat_type': coatType,
    'coat_colors': coatColors,
  };
}
