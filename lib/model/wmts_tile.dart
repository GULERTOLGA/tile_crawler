import 'dart:math';
import 'tile.dart';

/// WMTS tile implementation for Web Map Tile Service
class WMTSTile extends CoordinateTile {
  @override
  final int x; // TileCol

  @override
  final int y; // TileRow

  @override
  final int zoomLevel; // TileMatrix

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

  WMTSTile({
    required this.x,
    required this.y,
    required this.zoomLevel,
    required this.layer,
    required this.style,
    required this.tileMatrixSet,
    this.format = 'png',
    this.useRestful = true,
  });

  @override
  String get id => '$layer/$style/$tileMatrixSet/$zoomLevel/$y/$x';

  @override
  String get filePath =>
      '$layer/$style/$tileMatrixSet/$zoomLevel/$y/$x.$fileExtension';

  @override
  String get fileExtension => format;

  @override
  String buildUrl(String urlTemplate) {
    if (useRestful) {
      return _buildRestfulUrl(urlTemplate);
    } else {
      return _buildKvpUrl(urlTemplate);
    }
  }

  String _buildRestfulUrl(String urlTemplate) {
    return urlTemplate
        .replaceAll('{Layer}', layer)
        .replaceAll('{Style}', style)
        .replaceAll('{TileMatrixSet}', tileMatrixSet)
        .replaceAll('{TileMatrix}', zoomLevel.toString())
        .replaceAll('{TileRow}', y.toString())
        .replaceAll('{TileCol}', x.toString())
        .replaceAll('{format}', format);
  }

  String _buildKvpUrl(String urlTemplate) {
    final baseUrl = urlTemplate.contains('?') ? urlTemplate : '$urlTemplate?';
    final params = <String, String>{
      'SERVICE': 'WMTS',
      'REQUEST': 'GetTile',
      'VERSION': '1.0.0',
      'LAYER': layer,
      'STYLE': style,
      'TILEMATRIXSET': tileMatrixSet,
      'TILEMATRIX': zoomLevel.toString(),
      'TILEROW': y.toString(),
      'TILECOL': x.toString(),
      'FORMAT': 'image/$format',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return baseUrl.endsWith('?')
        ? '$baseUrl$queryString'
        : '$baseUrl&$queryString';
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'wmts',
      'x': x,
      'y': y,
      'z': zoomLevel,
      'layer': layer,
      'style': style,
      'tileMatrixSet': tileMatrixSet,
      'format': format,
      'useRestful': useRestful,
    };
  }

  static WMTSTile fromMap(Map<String, dynamic> map) {
    return WMTSTile(
      x: map['x'] as int,
      y: map['y'] as int,
      zoomLevel: map['z'] as int,
      layer: map['layer'] as String,
      style: map['style'] as String,
      tileMatrixSet: map['tileMatrixSet'] as String,
      format: map['format'] as String? ?? 'png',
      useRestful: map['useRestful'] as bool? ?? true,
    );
  }

  /// Calculate WMTS tile coordinates from latitude/longitude
  /// Note: This is a simplified implementation assuming Web Mercator projection
  static WMTSTile fromLatLng(
    double latitude,
    double longitude,
    int zoomLevel, {
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
    int tileSize = 256,
  }) {
    // Convert lat/lng to tile coordinates (Web Mercator)
    var sinLat = sin(latitude * pi / 180);
    var pixelX = ((longitude + 180) / 360) * tileSize * pow(2, zoomLevel);
    var pixelY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) *
        tileSize *
        pow(2, zoomLevel);

    return WMTSTile(
      x: (pixelX / tileSize).floor(),
      y: (pixelY / tileSize).floor(),
      zoomLevel: zoomLevel,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      useRestful: useRestful,
    );
  }

  /// Generate list of WMTS tiles for a given bounding box
  static List<WMTSTile> tilesInBounds({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int zoomLevel,
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
  }) {
    final topLeft = WMTSTile.fromLatLng(
      topLeftLat,
      topLeftLng,
      zoomLevel,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      useRestful: useRestful,
    );

    final bottomRight = WMTSTile.fromLatLng(
      bottomRightLat,
      bottomRightLng,
      zoomLevel,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      useRestful: useRestful,
    );

    // Ensure we have correct min/max bounds regardless of input order
    final minX = topLeft.x < bottomRight.x ? topLeft.x : bottomRight.x;
    final maxX = topLeft.x > bottomRight.x ? topLeft.x : bottomRight.x;
    final minY = topLeft.y < bottomRight.y ? topLeft.y : bottomRight.y;
    final maxY = topLeft.y > bottomRight.y ? topLeft.y : bottomRight.y;

    final tiles = <WMTSTile>[];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add(WMTSTile(
          x: x,
          y: y,
          zoomLevel: zoomLevel,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          useRestful: useRestful,
        ));
      }
    }
    return tiles;
  }

  /// Create a copy of this tile with optional parameter changes
  WMTSTile copyWith({
    int? x,
    int? y,
    int? zoomLevel,
    String? layer,
    String? style,
    String? tileMatrixSet,
    String? format,
    bool? useRestful,
  }) =>
      WMTSTile(
        x: x ?? this.x,
        y: y ?? this.y,
        zoomLevel: zoomLevel ?? this.zoomLevel,
        layer: layer ?? this.layer,
        style: style ?? this.style,
        tileMatrixSet: tileMatrixSet ?? this.tileMatrixSet,
        format: format ?? this.format,
        useRestful: useRestful ?? this.useRestful,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WMTSTile &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          zoomLevel == other.zoomLevel &&
          layer == other.layer &&
          style == other.style &&
          tileMatrixSet == other.tileMatrixSet &&
          format == other.format &&
          useRestful == other.useRestful;

  @override
  int get hashCode =>
      x.hashCode ^
      y.hashCode ^
      zoomLevel.hashCode ^
      layer.hashCode ^
      style.hashCode ^
      tileMatrixSet.hashCode ^
      format.hashCode ^
      useRestful.hashCode;

  @override
  String toString() => '$layer/$style/$tileMatrixSet/$zoomLevel/$y/$x';
}
