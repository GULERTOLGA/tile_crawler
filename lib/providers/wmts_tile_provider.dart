import '../model/tile.dart';
import '../model/wmts_tile.dart';
import 'tile_provider.dart';

/// WMTS tile provider for Web Map Tile Service
class WMTSTileProvider extends TileProvider {
  @override
  final String urlTemplate;

  @override
  final String name;

  /// WMTS Layer identifier
  final String layer;

  /// WMTS Style identifier
  final String style;

  /// WMTS TileMatrixSet identifier
  final String tileMatrixSet;

  /// Image format (png, jpg, etc.)
  final String format;

  /// Whether to use RESTful or KVP (Key-Value Pair) URL format
  final bool useRestful;

  WMTSTileProvider({
    required this.urlTemplate,
    required this.layer,
    required this.style,
    required this.tileMatrixSet,
    this.format = 'png',
    this.useRestful = true,
    this.name = 'WMTS Provider',
  })  : assert(urlTemplate.isNotEmpty, 'URL template cannot be empty'),
        assert(layer.isNotEmpty, 'Layer cannot be empty'),
        assert(style.isNotEmpty, 'Style cannot be empty'),
        assert(tileMatrixSet.isNotEmpty, 'TileMatrixSet cannot be empty');

  @override
  Future<List<Tile>> generateTiles({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int minZoomLevel,
    required int maxZoomLevel,
  }) async {
    final tiles = <Tile>[];

    for (int zoomLevel = minZoomLevel; zoomLevel <= maxZoomLevel; zoomLevel++) {
      final levelTiles = await generateTilesForZoom(
        topLeftLat: topLeftLat,
        topLeftLng: topLeftLng,
        bottomRightLat: bottomRightLat,
        bottomRightLng: bottomRightLng,
        zoomLevel: zoomLevel,
      );
      tiles.addAll(levelTiles);
    }

    return tiles;
  }

  @override
  Future<List<Tile>> generateTilesForZoom({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int zoomLevel,
  }) async {
    final wmtsTiles = WMTSTile.tilesInBounds(
      topLeftLat: topLeftLat,
      topLeftLng: topLeftLng,
      bottomRightLat: bottomRightLat,
      bottomRightLng: bottomRightLng,
      zoomLevel: zoomLevel,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      useRestful: useRestful,
    );

    return wmtsTiles.cast<Tile>();
  }

  @override
  Tile createTileFromMap(Map<String, dynamic> map) {
    return WMTSTile.fromMap(map);
  }

  @override
  bool get isValid {
    if (urlTemplate.isEmpty ||
        layer.isEmpty ||
        style.isEmpty ||
        tileMatrixSet.isEmpty) {
      return false;
    }

    if (useRestful) {
      // Check for RESTful placeholders
      return urlTemplate.contains('{Layer}') &&
          urlTemplate.contains('{Style}') &&
          urlTemplate.contains('{TileMatrixSet}') &&
          urlTemplate.contains('{TileMatrix}') &&
          urlTemplate.contains('{TileRow}') &&
          urlTemplate.contains('{TileCol}');
    } else {
      // For KVP format, we just need a base URL
      return urlTemplate.startsWith('http');
    }
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'wmts',
      'urlTemplate': urlTemplate,
      'name': name,
      'layer': layer,
      'style': style,
      'tileMatrixSet': tileMatrixSet,
      'format': format,
      'useRestful': useRestful,
    };
  }

  static WMTSTileProvider fromMap(Map<String, dynamic> map) {
    return WMTSTileProvider(
      urlTemplate: map['urlTemplate'] as String,
      layer: map['layer'] as String,
      style: map['style'] as String,
      tileMatrixSet: map['tileMatrixSet'] as String,
      format: map['format'] as String? ?? 'png',
      useRestful: map['useRestful'] as bool? ?? true,
      name: map['name'] as String? ?? 'WMTS Provider',
    );
  }

  /// Create a copy of this provider with optional parameter changes
  WMTSTileProvider copyWith({
    String? urlTemplate,
    String? name,
    String? layer,
    String? style,
    String? tileMatrixSet,
    String? format,
    bool? useRestful,
  }) =>
      WMTSTileProvider(
        urlTemplate: urlTemplate ?? this.urlTemplate,
        name: name ?? this.name,
        layer: layer ?? this.layer,
        style: style ?? this.style,
        tileMatrixSet: tileMatrixSet ?? this.tileMatrixSet,
        format: format ?? this.format,
        useRestful: useRestful ?? this.useRestful,
      );

  @override
  String toString() =>
      'WMTSTileProvider(name: $name, layer: $layer, style: $style, tileMatrixSet: $tileMatrixSet)';
}
