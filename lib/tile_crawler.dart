library tile_crawler;

import 'dart:async';
import 'dart:io';
import 'dart:math';

//https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
//https://a.tile.openstreetmap.org/{z}/{x}/{y}.png
//https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90

typedef OnStart = void Function(int totalTileCount, double area);

typedef OnProcess = void Function(int tileDownloaded, int z, int x, int y);
typedef OnEnd = void Function();

class TileCrawler {
  final int tileSize = 256;
  final DownloadOptions options;
  final List<_XYZ> _queue = [];

  TileCrawler(this.options);

  bool _cancel = false;

  Future<void> download(
      {OnStart? onStart, OnProcess? onProcess, OnEnd? onEnd}) async {
    _queue.clear();
    _cancel = false;
    for (int z = options.minZoomLevel; z <= options.maxZoomLevel; z++) {
      _calculateRectIN(_calculateRect(options.topLeft, options.bottomRight, z));
    }
    if (onStart != null) {
      onStart(_queue.length, 1500.0);
    }
    var startCount = _queue.length;
    while (!_cancel && _queue.isNotEmpty) {
      var xyz = _queue.removeLast();
      await _downloadCurrent(xyz);
      if (onProcess != null) {
        onProcess(startCount - _queue.length, xyz.z, xyz.x, xyz.y);
      }
    }
  }

  void cancel() {
    _cancel = true;
    _queue.clear();
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

  _calculateRectIN(_Rectangle rect) {
    for (int x = rect.startX; x <= rect.endX; x++) {
      for (int y = rect.startY; y <= rect.endY; y++) {
        var xyz = _XYZ(x: x, y: y, z: rect.level);

        _queue.add(xyz);
      }
    }
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

class MapProviders {
  static const String googleStreets =
      "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}";

  static const String openStreetMap =
      "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png";

  static const String bingSattellite =
      "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90";
}

class MapboxStyles {
  static const String MAPBOX_STREETS = "mapbox://styles/mapbox/streets-v11";

  /// Outdoors: A general-purpose style tailored to outdoor activities. Using this constant means
  /// your map style will always use the latest version and may change as we improve the style.
  static const String OUTDOORS = "mapbox://styles/mapbox/outdoors-v11";

  /// Light: Subtle light backdrop for data visualizations. Using this constant means your map
  /// style will always use the latest version and may change as we improve the style.
  static const String LIGHT = "mapbox://styles/mapbox/light-v10";

  /// Empty: Basic empty style
  static const String EMPTY = "mapbox://styles/mapbox/empty-v8";

  /// Dark: Subtle dark backdrop for data visualizations. Using this constant means your map style
  /// will always use the latest version and may change as we improve the style.
  static const String DARK = "mapbox://styles/mapbox/dark-v10";

  /// Satellite: A beautiful global satellite and aerial imagery layer. Using this constant means
  /// your map style will always use the latest version and may change as we improve the style.
  static const String SATELLITE = "mapbox://styles/mapbox/satellite-v9";

  /// Satellite Streets: Global satellite and aerial imagery with unobtrusive labels. Using this
  /// constant means your map style will always use the latest version and may change as we
  /// improve the style.
  static const String SATELLITE_STREETS =
      "mapbox://styles/mapbox/satellite-streets-v11";

  /// Traffic Day: Color-coded roads based on live traffic congestion data. Traffic data is currently
  /// available in
  /// <a href="https://www.mapbox.com/help/how-directions-work/#traffic-data">these select
  /// countries</a>. Using this constant means your map style will always use the latest version and
  /// may change as we improve the style.
  static const String TRAFFIC_DAY = "mapbox://styles/mapbox/traffic-day-v2";

  /// Traffic Night: Color-coded roads based on live traffic congestion data, designed to maximize
  /// legibility in low-light situations. Traffic data is currently available in
  /// <a href="https://www.mapbox.com/help/how-directions-work/#traffic-data">these select
  /// countries</a>. Using this constant means your map style will always use the latest version and
  /// may change as we improve the style.
  static const String TRAFFIC_NIGHT = "mapbox://styles/mapbox/traffic-night-v2";
}
