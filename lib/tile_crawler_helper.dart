import 'dart:math';

import 'package:tile_crawler/tile_crawler.dart';

mixin TileCrawlerHelper {
  Rectangle calculateRect(LatLng topLeft, LatLng bottomRight, int level) {
    XYZ topLeftTile = calculateXYZ(topLeft.latitude, topLeft.longitude, level);

    XYZ bottomRightTile =
        calculateXYZ(bottomRight.latitude, bottomRight.longitude, level);

    return Rectangle(
        startX: topLeftTile.x,
        startY: topLeftTile.y,
        endX: bottomRightTile.x,
        endY: bottomRightTile.y,
        level: level);
  }

  XYZ calculateXYZ(double latitude, double longitude, level,
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

  List<XYZ> calculateRectIN(Rectangle rect) {
    var _queue = <XYZ>[];
    for (int x = rect.startX; x <= rect.endX; x++) {
      for (int y = rect.startY; y <= rect.endY; y++) {
        var xyz = XYZ(x: x, y: y, z: rect.level);

        _queue.add(xyz);
      }
    }
    return _queue;
  }

  double calculateArea(double lat1, double lng1, double lat2, double lng2) {
    var r = 6371000;
    double area = ((lng2 - lng1) * pi / 180) *
        ((sin(lat2 * pi / 180) - sin(lat1 * pi / 180)) *
            (cos(lng1 * pi / 180) + cos(lng2 * pi / 180)) /
            2);
    return area * pow(r, 2);
  }
}
