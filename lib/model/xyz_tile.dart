import 'dart:math';
import 'tile.dart';

/// XYZ tile implementation for standard web map tiles
class XYZTile extends CoordinateTile {
  @override
  final int x;

  @override
  final int y;

  @override
  final int zoomLevel;

  XYZTile({
    required this.x,
    required this.y,
    required this.zoomLevel,
  });

  @override
  String get id => '$zoomLevel/$x/$y';

  @override
  String get filePath => '$zoomLevel/$x/$y.$fileExtension';

  @override
  String get fileExtension => 'png';

  @override
  String buildUrl(String urlTemplate) {
    var url = urlTemplate;

    // Handle quadkey format
    if (url.contains('{quadkey}')) {
      url = url.replaceAll('{quadkey}', toQuadKey());
    } else {
      // Handle standard XYZ format
      url = url
          .replaceAll('{x}', x.toString())
          .replaceAll('{y}', y.toString())
          .replaceAll('{z}', zoomLevel.toString());
    }

    return url;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'xyz',
      'x': x,
      'y': y,
      'z': zoomLevel,
    };
  }

  static XYZTile fromMap(Map<String, dynamic> map) {
    return XYZTile(
      x: map['x'] as int,
      y: map['y'] as int,
      zoomLevel: map['z'] as int,
    );
  }

  /// Calculate XYZ tile coordinates from latitude/longitude
  static XYZTile fromLatLng(double latitude, double longitude, int zoomLevel,
      [int tileSize = 256]) {
    var sinLat = sin(latitude * pi / 180);
    var pixelX = ((longitude + 180) / 360) * tileSize * pow(2, zoomLevel);
    var pixelY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) *
        tileSize *
        pow(2, zoomLevel);

    return XYZTile(
      x: (pixelX / tileSize).floor(),
      y: (pixelY / tileSize).floor(),
      zoomLevel: zoomLevel,
    );
  }

  /// Generate list of XYZ tiles for a given bounding box
  static List<XYZTile> tilesInBounds({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int zoomLevel,
  }) {
    final topLeft = XYZTile.fromLatLng(topLeftLat, topLeftLng, zoomLevel);
    final bottomRight =
        XYZTile.fromLatLng(bottomRightLat, bottomRightLng, zoomLevel);

    // Ensure we have correct min/max bounds regardless of input order
    final minX = topLeft.x < bottomRight.x ? topLeft.x : bottomRight.x;
    final maxX = topLeft.x > bottomRight.x ? topLeft.x : bottomRight.x;
    final minY = topLeft.y < bottomRight.y ? topLeft.y : bottomRight.y;
    final maxY = topLeft.y > bottomRight.y ? topLeft.y : bottomRight.y;

    final tiles = <XYZTile>[];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add(XYZTile(x: x, y: y, zoomLevel: zoomLevel));
      }
    }
    return tiles;
  }

  /// Create a copy of this tile with optional parameter changes
  XYZTile copyWith({int? x, int? y, int? zoomLevel}) => XYZTile(
        x: x ?? this.x,
        y: y ?? this.y,
        zoomLevel: zoomLevel ?? this.zoomLevel,
      );

  /// Convert tile coordinates to quadkey format
  String toQuadKey() {
    var quadKey = [];
    for (var i = zoomLevel; i > 0; i--) {
      var digit = 0;
      var mask = 1 << (i - 1);
      if ((x & mask) != 0) {
        digit++;
      }
      if ((y & mask) != 0) {
        digit++;
        digit++;
      }
      quadKey.add(digit);
    }
    return quadKey.join('');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XYZTile &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          zoomLevel == other.zoomLevel;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ zoomLevel.hashCode;

  @override
  String toString() => '$zoomLevel/$x/$y';
}

/// Compatibility alias for backward compatibility
typedef XYZ = XYZTile;
