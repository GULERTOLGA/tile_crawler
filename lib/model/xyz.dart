import 'dart:math';

class XYZ {
  final int x;
  final int y;
  final int z;

  const XYZ({required this.x, required this.y, required this.z});

  /// Calculate XYZ tile coordinates from latitude/longitude
  static XYZ fromLatLng(double latitude, double longitude, int level,
      [int tileSize = 256]) {
    var sinLat = sin(latitude * pi / 180);
    var pixelX = ((longitude + 180) / 360) * tileSize * pow(2, level);
    var pixelY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) *
        tileSize *
        pow(2, level);

    return XYZ(
        x: (pixelX / tileSize).floor(),
        y: (pixelY / tileSize).floor(),
        z: level);
  }

  /// Generate list of XYZ tiles for a given bounding box
  static List<XYZ> tilesInBounds({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int level,
  }) {
    final topLeft = XYZ.fromLatLng(topLeftLat, topLeftLng, level);
    final bottomRight = XYZ.fromLatLng(bottomRightLat, bottomRightLng, level);

    // Ensure we have correct min/max bounds regardless of input order
    final minX = topLeft.x < bottomRight.x ? topLeft.x : bottomRight.x;
    final maxX = topLeft.x > bottomRight.x ? topLeft.x : bottomRight.x;
    final minY = topLeft.y < bottomRight.y ? topLeft.y : bottomRight.y;
    final maxY = topLeft.y > bottomRight.y ? topLeft.y : bottomRight.y;

    final tiles = <XYZ>[];
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= maxY; y++) {
        tiles.add(XYZ(x: x, y: y, z: level));
      }
    }
    return tiles;
  }

  XYZ copyWith({int? x, int? y, int? z}) =>
      XYZ(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);

  String toQuadKey() {
    var quadKey = [];
    for (var i = z; i > 0; i--) {
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
      other is XYZ &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          z == other.z;

  @override
  int get hashCode => x.hashCode ^ y.hashCode ^ z.hashCode;

  @override
  String toString() => "$z/$x/$y";
}
