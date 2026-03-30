import 'dart:math';

import 'model/resolved_download.dart';
import 'model/storage_layout.dart';
import 'model/tile.dart';
import 'model/xyz.dart' as xyz_model;
import 'model/xyz_tile.dart';
import 'model/wmts_tile.dart';
import 'providers/tile_provider.dart';
import 'providers/xyz_tile_provider.dart';
import 'providers/wmts_tile_provider.dart';
import 'tile_download_security.dart';

/// Factory class for creating different tile providers
/// Provides a unified interface while maintaining backward compatibility
class TileProviderFactory {
  /// Create an XYZ tile provider
  static XYZTileProvider createXYZProvider({
    required String urlTemplate,
    String name = 'XYZ Provider',
  }) {
    return XYZTileProvider(
      urlTemplate: urlTemplate,
      name: name,
    );
  }

  /// Create a WMTS tile provider
  static WMTSTileProvider createWMTSProvider({
    required String urlTemplate,
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
    String name = 'WMTS Provider',
  }) {
    return WMTSTileProvider(
      urlTemplate: urlTemplate,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      useRestful: useRestful,
      name: name,
    );
  }

  /// Create a tile provider from configuration map
  static TileProvider fromMap(Map<String, dynamic> config) {
    final type = config['type'] as String;

    switch (type.toLowerCase()) {
      case 'xyz':
        return XYZTileProvider.fromMap(config);
      case 'wmts':
        return WMTSTileProvider.fromMap(config);
      default:
        throw ArgumentError('Unsupported tile provider type: $type');
    }
  }
}

/// Enhanced download options that support both XYZ and WMTS
class EnhancedDownloadOptions {
  final List<double> topLeftLatLng;
  final List<double> bottomRightLatLng;
  final int minZoomLevel;
  final int maxZoomLevel;
  final TileProvider tileProvider;
  final String downloadFolder;

  /// Storage layout for all tiles from this job (WMTS often uses
  /// [StorageLayout.sourceRelativePath] or Slippy for EPSG:3857).
  final StorageLayout storageLayout;

  final TileDownloadSecurity? security;

  List<dynamic>? _cachedQueue;

  EnhancedDownloadOptions({
    required this.topLeftLatLng,
    required this.bottomRightLatLng,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.tileProvider,
    this.downloadFolder = '',
    this.storageLayout = StorageLayout.slippyMapXyz,
    this.security,
  })  : assert(tileProvider.isValid, 'Tile provider configuration is invalid'),
        assert(topLeftLatLng.length == 2,
            'Top left coordinates must have latitude and longitude'),
        assert(bottomRightLatLng.length == 2,
            'Bottom right coordinates must have latitude and longitude'),
        assert(minZoomLevel > 0, 'Min zoom level must be greater than 0'),
        assert(maxZoomLevel > 0, 'Max zoom level must be greater than 0'),
        assert(minZoomLevel <= maxZoomLevel,
            'Min zoom level cannot be greater than max zoom level');

  /// Create from XYZ configuration for backward compatibility
  EnhancedDownloadOptions.fromXYZ({
    required this.topLeftLatLng,
    required this.bottomRightLatLng,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required String tileUrlFormat,
    this.downloadFolder = '',
    this.storageLayout = StorageLayout.slippyMapXyz,
    this.security,
  }) : tileProvider = TileProviderFactory.createXYZProvider(
          urlTemplate: tileUrlFormat,
        );

  /// Create from WMTS configuration
  EnhancedDownloadOptions.fromWMTS({
    required this.topLeftLatLng,
    required this.bottomRightLatLng,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required String urlTemplate,
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
    this.downloadFolder = '',
    this.storageLayout = StorageLayout.sourceRelativePath,
    this.security,
  }) : tileProvider = TileProviderFactory.createWMTSProvider(
          urlTemplate: urlTemplate,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          useRestful: useRestful,
        );

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
  Future<List<dynamic>> get queue async {
    if (_cachedQueue != null) return _cachedQueue!;

    final tiles = await tileProvider.generateTiles(
      topLeftLat: topLeftLatLng[0],
      topLeftLng: topLeftLatLng[1],
      bottomRightLat: bottomRightLatLng[0],
      bottomRightLng: bottomRightLatLng[1],
      minZoomLevel: minZoomLevel,
      maxZoomLevel: maxZoomLevel,
    );

    _cachedQueue = tiles;
    return tiles;
  }

  /// Convert to legacy XYZ format for backward compatibility
  Future<List<xyz_model.XYZ>> get xyzQueue async {
    final tiles = await queue;

    // If tiles are already XYZ, return them
    if (tiles.isNotEmpty && tiles.first is XYZTile) {
      return tiles
          .cast<XYZTile>()
          .map((t) => xyz_model.XYZ(x: t.x, y: t.y, z: t.zoomLevel))
          .toList();
    }

    // If tiles are WMTS, convert to XYZ format
    if (tiles.isNotEmpty && tiles.first is WMTSTile) {
      return tiles
          .cast<WMTSTile>()
          .map((t) => xyz_model.XYZ(x: t.x, y: t.y, z: t.zoomLevel))
          .toList();
    }

    return <xyz_model.XYZ>[];
  }

  /// Resolved download rows using each tile’s [Tile.buildUrl] / [Tile.storageRelativePath].
  Future<List<ResolvedDownload>> get resolvedDownloads async {
    final tiles = await queue;
    return tiles
        .map(
          (dynamic t) => ResolvedDownload.fromTile(
            tile: t as Tile,
            urlTemplate: tileProvider.urlTemplate,
            storageLayout: storageLayout,
          ),
        )
        .toList(growable: false);
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
