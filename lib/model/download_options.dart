import 'dart:io';
import 'dart:math';
import 'xyz.dart';
import 'crawler_summary.dart';

class DownloadOptions {
  final List<double> topLeftLatLng;
  final List<double> bottomRightLatLng;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  final String downloadFolder;

  List<XYZ>? _cachedQueue;

  DownloadOptions({
    required this.topLeftLatLng,
    required this.bottomRightLatLng,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.tileUrlFormat,
    this.downloadFolder = '',
  })  : assert(tileUrlFormat.isNotEmpty, 'Tile URL format cannot be empty'),
        assert(topLeftLatLng.length == 2,
            'Top left coordinates must have latitude and longitude'),
        assert(bottomRightLatLng.length == 2,
            'Bottom right coordinates must have latitude and longitude'),
        assert(minZoomLevel > 0, 'Min zoom level must be greater than 0'),
        assert(maxZoomLevel > 0, 'Max zoom level must be greater than 0'),
        assert(minZoomLevel <= maxZoomLevel,
            'Min zoom level cannot be greater than max zoom level');

  DownloadOptions.fromTiles({
    required List<XYZ> tiles,
    required this.downloadFolder,
    required this.tileUrlFormat,
    HttpClient? client,
  })  : topLeftLatLng = const [0, 0],
        bottomRightLatLng = const [0, 0],
        minZoomLevel = 1,
        maxZoomLevel = 1,
        _cachedQueue = tiles;

  /// Calculate area in square kilometers
  double get area {
    final areaInSquareMeters = _calculateArea(
      topLeftLatLng[0],
      topLeftLatLng[1],
      bottomRightLatLng[0],
      bottomRightLatLng[1],
    );
    return areaInSquareMeters / 1000000; // Convert to km²
  }

  /// Get all tiles for the specified bounds and zoom levels
  Future<List<XYZ>> get queue async {
    if (_cachedQueue != null) return _cachedQueue!;

    var tiles = <XYZ>[];
    for (int z = minZoomLevel; z <= maxZoomLevel; z++) {
      tiles.addAll(XYZ.tilesInBounds(
        topLeftLat: topLeftLatLng[0],
        topLeftLng: topLeftLatLng[1],
        bottomRightLat: bottomRightLatLng[0],
        bottomRightLng: bottomRightLatLng[1],
        level: z,
      ));
    }

    _cachedQueue = tiles;
    return tiles;
  }

  /// Get summary information about the crawl
  Future<CrawlerSummary> get summary async {
    final tiles = await queue;
    return CrawlerSummary(area: area, tileCount: tiles.length);
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371e3; // Earth's average radius in meters
    final double phi1 = pi / 180 * lat1;
    final double phi2 = pi / 180 * lat2;
    final double deltaPhi = pi / 180 * (lat2 - lat1);
    final double deltaLambda = pi / 180 * (lon2 - lon1);

    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }

  double _calculateArea(double lat1, double lon1, double lat2, double lon2) {
    final double width = _calculateDistance(lat1, lon1, lat1, lon2);
    final double height = _calculateDistance(lat1, lon1, lat2, lon1);
    return width * height;
  }
}
