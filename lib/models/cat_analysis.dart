import 'dart:convert';

enum AnalysisStatus { pending, analyzing, completed, failed }

class CoatColor {
  final String name;
  final double percentage;

  const CoatColor({required this.name, required this.percentage});

  Map<String, dynamic> toJson() {
    return {'name': name, 'percentage': percentage};
  }

  factory CoatColor.fromJson(Map<String, dynamic> json) {
    return CoatColor(
      name: json['name'] as String,
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class CatAnalysis {
  final String catId;
  final AnalysisStatus status;

  final String? coatType;
  final String? primaryColor;

  final List<CoatColor> colors;

  final double? confidence;

  // Guardamos o mapa completo retornado pela IA
  // para uso futuro na geração da skin 3D.
  final Map<String, dynamic>? patternMap;

  final DateTime? analyzedAt;

  const CatAnalysis({
    required this.catId,
    required this.status,
    this.coatType,
    this.primaryColor,
    this.colors = const [],
    this.confidence,
    this.patternMap,
    this.analyzedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'cat_id': catId,
      'analysis_status': status.name,
      'coat_type': coatType,
      'primary_color': primaryColor,
      'colors_json': jsonEncode(colors.map((color) => color.toJson()).toList()),
      'confidence': confidence,
      'pattern_map_json': patternMap == null ? null : jsonEncode(patternMap),
      'analyzed_at': analyzedAt?.toIso8601String(),
    };
  }

  factory CatAnalysis.fromMap(Map<String, dynamic> map) {
    final decodedColors =
        jsonDecode(map['colors_json'] ?? '[]') as List<dynamic>;

    final patternMapJson = map['pattern_map_json'] as String?;

    return CatAnalysis(
      catId: map['cat_id'] as String,
      status: AnalysisStatus.values.firstWhere(
        (status) => status.name == map['analysis_status'],
        orElse: () => AnalysisStatus.pending,
      ),
      coatType: map['coat_type'] as String?,
      primaryColor: map['primary_color'] as String?,
      colors: decodedColors
          .map(
            (item) =>
                CoatColor.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      confidence: map['confidence'] == null
          ? null
          : (map['confidence'] as num).toDouble(),
      patternMap: patternMapJson == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(patternMapJson) as Map),
      analyzedAt: map['analyzed_at'] == null
          ? null
          : DateTime.parse(map['analyzed_at'] as String),
    );
  }

  factory CatAnalysis.fromApiJson(Map<String, dynamic> json) {
    final colorsJson = json['colors'] as List<dynamic>? ?? [];

    return CatAnalysis(
      catId: json['cat_id'] as String,
      status: AnalysisStatus.completed,
      coatType: json['coat_type'] as String?,
      primaryColor: json['primary_color'] as String?,
      colors: colorsJson
          .map(
            (color) =>
                CoatColor.fromJson(Map<String, dynamic>.from(color as Map)),
          )
          .toList(),
      confidence: json['confidence'] == null
          ? null
          : (json['confidence'] as num).toDouble(),
      patternMap: json['pattern_map'] == null
          ? null
          : Map<String, dynamic>.from(json['pattern_map'] as Map),
      analyzedAt: json['analyzed_at'] == null
          ? null
          : DateTime.parse(json['analyzed_at'] as String),
    );
  }

  Map<String, dynamic> toApiJson() {
    return {
      'cat_id': catId,
      'coat_type': coatType,
      'primary_color': primaryColor,
      'colors': colors.map((color) => color.toJson()).toList(),
      'confidence': confidence,
      'pattern_map': patternMap,
      'analyzed_at': analyzedAt?.toUtc().toIso8601String(),
      'analysis_status': status.name,
    };
  }

  CatAnalysis withStatus(AnalysisStatus newStatus) {
    return CatAnalysis(
      catId: catId,
      status: newStatus,
      coatType: coatType,
      primaryColor: primaryColor,
      colors: colors,
      confidence: confidence,
      patternMap: patternMap,
      analyzedAt: analyzedAt,
    );
  }
}
