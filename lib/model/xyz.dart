part of tile_crawler;

class XYZ {
  final int x;
  final int y;
  final int z;

  XYZ({required this.x, required this.y, required this.z});
  static calculateXYZ(double latitude, double longitude, level, int tileSize) {
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
  String toString() {
    return "$z/$x/$y";
  }
}
