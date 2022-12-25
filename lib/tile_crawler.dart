library tile_crawler;

import 'dart:io';
import 'dart:math';

//https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
//https://a.tile.openstreetmap.org/{z}/{x}/{y}.png
//https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90

class TileCrawler {
  final int tileSize = 256;
  final DownloadOptions options;
  final List<_XYZ> _queue = [];

  TileCrawler(this.options);

  void startDownload() {
    _queue.clear();

    for (int i = options.minZoomLevel; i <= options.maxZoomLevel; i++) {
      _calculateRectIN(
          _calculateRect(options.topLeft, options.bottomRight, i), null);
    }
  }

  _Rectangle _calculateRect(LatLng topLeft, LatLng bottomRight, int level) {
    _XYZ topLeftTile =
        _calculateXYZ(topLeft.latitude, topLeft.longitude, level);

    _XYZ bottomRightTile =
        _calculateXYZ(bottomRight.latitude, bottomRight.longitude, level);

    return _Rectangle(
        startX: topLeftTile.x,
        startY: topLeftTile.y,
        endX: bottomRightTile.x,
        endY: bottomRightTile.y,
        level: level);
  }

  _XYZ _calculateXYZ(double latitude, double longitude, level) {
    var sinLat = sin(latitude * pi / 180);
    var pixelX = ((longitude + 180) / 360) * tileSize * pow(2, level);
    var pixelY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) *
        tileSize *
        pow(2, level);

    return _XYZ(
        x: (pixelX / tileSize).floor(),
        y: (pixelY / tileSize).floor(),
        z: level);
  }

  Future<void> _calculateRectIN(_Rectangle rect, _XYZ? inCurrent) async {
    var current =
        inCurrent ??= _XYZ(x: rect.startX, y: rect.startY, z: rect.level);

    print(current);
    _queue.add(current);
    await _downloadCurrent(current);

    if (current.x >= rect.endX && current.y >= rect.endY) {
      return;
    } else if (current.x >= rect.endX && current.y < rect.endY) {
      current = current.copyWith(y: current.y + 1);
    }

    if (current.x >= rect.endX) {
      current = current.copyWith(x: rect.startX);
    } else {
      current = current.copyWith(x: current.x + 1);
    }
    await _calculateRectIN(rect, current);
  }

  Future<void> _downloadCurrent(_XYZ current) async {
    var url = options.tileUrlFormat.toLowerCase();
    if (url.contains("{quadkey}")) {
      url = url.replaceAll("{quadkey}", current.toQuadKey());
    } else {
      url = url
          .replaceAll("{x}", current.x.toString())
          .replaceAll("{y}", current.y.toString())
          .replaceAll("{z}", current.z.toString());
    }

    final request = await options.client.getUrl(Uri.parse(url));
    final response = await request.close();
    final String pathString =
        "${options.downloadFolder}/${current.z}/${current.x}";
    final dirPath = await Directory(pathString).create(recursive: true);
    await response.pipe(File('${dirPath.path}/${current.y}.png').openWrite());
  }
}

class LatLng {
  final double latitude;
  final double longitude;
  LatLng({required this.latitude, required this.longitude});
}

class DownloadOptions {
  final LatLng topLeft;
  final LatLng bottomRight;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  final String downloadFolder;
  final HttpClient client;

  DownloadOptions(
      {required this.topLeft,
      required this.bottomRight,
      required this.minZoomLevel,
      required this.maxZoomLevel,
      required this.tileUrlFormat,
      HttpClient? client,
      required this.downloadFolder})
      : client = client ?? HttpClient();
}

class _Rectangle {
  final int startX;
  final int startY;
  final int endX;
  final int endY;
  final int level;

  _Rectangle(
      {required this.startX,
      required this.startY,
      required this.endX,
      required this.level,
      required this.endY});

  @override
  String toString() {
    return "$startX, $startY $endX, $endY $level";
  }
}

class _XYZ {
  final int x;
  final int y;
  final int z;

  _XYZ({required this.x, required this.y, required this.z});

  _XYZ copyWith({int? x, int? y, int? z}) =>
      _XYZ(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);

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
