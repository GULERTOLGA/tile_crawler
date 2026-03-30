import 'dart:math' show atan2, cos, pi, sin, sqrt;

import 'crawler_summary.dart';
import 'resolved_download.dart';
import 'storage_layout.dart';
import 'xyz.dart';
import '../tile_download_security.dart';

/// Bounding-box + zoom range + XYZ URL template (legacy pipeline).
class DownloadOptions {
  final List<double> topLeftLatLng;
  final List<double> bottomRightLatLng;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  final String downloadFolder;

  /// On-disk layout under [downloadFolder] (default Slippy / flutter_map).
  final StorageLayout storageLayout;

  /// Optional host allow-list for requests.
  final TileDownloadSecurity? security;

  /// Filename extension hint when building paths before bytes are known.
  final String fileExtensionHint;

  List<XYZ>? _cachedQueue;

  DownloadOptions({
    required this.topLeftLatLng,
    required this.bottomRightLatLng,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.tileUrlFormat,
    this.downloadFolder = '',
    this.storageLayout = StorageLayout.slippyMapXyz,
    this.security,
    this.fileExtensionHint = 'png',
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
    this.storageLayout = StorageLayout.slippyMapXyz,
    this.security,
    this.fileExtensionHint = 'png',
  })  : topLeftLatLng = const [0, 0],
        bottomRightLatLng = const [0, 0],
        minZoomLevel = 1,
        maxZoomLevel = 1,
        _cachedQueue = tiles;

  double get area {
    final areaInSquareMeters = _calculateArea(
      topLeftLatLng[0],
      topLeftLatLng[1],
      bottomRightLatLng[0],
      bottomRightLatLng[1],
    );
    return areaInSquareMeters / 1000000;
  }

  Future<List<XYZ>> get queue async {
    if (_cachedQueue != null) {
      return _cachedQueue!;
    }

    var tiles = <XYZ>[];
    for (var z = minZoomLevel; z <= maxZoomLevel; z++) {
      tiles.addAll(
        XYZ.tilesInBounds(
          topLeftLat: topLeftLatLng[0],
          topLeftLng: topLeftLatLng[1],
          bottomRightLat: bottomRightLatLng[0],
          bottomRightLng: bottomRightLatLng[1],
          level: z,
        ),
      );
    }

    _cachedQueue = tiles;
    return tiles;
  }

  /// Pre-resolved HTTP + relative paths for [TileDownloadService].
  Future<List<ResolvedDownload>> get resolvedDownloads async {
    final tiles = await queue;
    return tiles
        .map(
          (xyz) => ResolvedDownload.fromXyz(
            xyz: xyz,
            urlTemplate: tileUrlFormat,
            storageLayout: storageLayout,
            fileExtensionHint: fileExtensionHint,
          ),
        )
        .toList(growable: false);
  }

  Future<CrawlerSummary> get summary async {
    final tiles = await queue;
    return CrawlerSummary(area: area, tileCount: tiles.length);
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371e3;
    final phi1 = pi / 180 * lat1;
    final phi2 = pi / 180 * lat2;
    final deltaPhi = pi / 180 * (lat2 - lat1);
    final deltaLambda = pi / 180 * (lon2 - lon1);

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  double _calculateArea(double lat1, double lon1, double lat2, double lon2) {
    final width = _calculateDistance(lat1, lon1, lat1, lon2);
    final height = _calculateDistance(lat1, lon1, lat2, lon1);
    return width * height;
  }
}
