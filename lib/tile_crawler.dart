library tile_crawler;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'tile_download_service.dart';
import 'model/xyz.dart';
import 'model/download_options.dart';
import 'model/download_status.dart';
import 'model/map_providers.dart';
import 'model/crawler_summary.dart';
import 'tile_provider_factory.dart';

// Export all public classes
export 'model/xyz.dart';
export 'model/download_options.dart';
export 'model/download_status.dart';
export 'model/map_providers.dart';
export 'model/crawler_summary.dart';

// Export new generic tile system
export 'model/tile.dart';
export 'model/xyz_tile.dart' hide XYZ;
export 'model/wmts_tile.dart';
export 'providers/tile_provider.dart';
export 'providers/xyz_tile_provider.dart';
export 'providers/wmts_tile_provider.dart';
export 'providers/custom_wmts_tile_provider.dart';
export 'tile_provider_factory.dart';

// Updated callback signatures to match improved TileDownloadService
typedef OnStart = void Function(
    int totalTileCount, int remainingTileCount, double area);
typedef OnProcess = void Function(
    int tilesDownloaded, int remainingTiles, XYZ xyz);
typedef OnProcessError = void Function(
    XYZ xyz, Object error, StackTrace stackTrace);
typedef OnEnd = void Function(int totalDownloaded, int totalSkipped);

class TileCrawler {
  final DownloadOptions options;
  final TileDownloadService _downloadService = TileDownloadService();

  TileCrawler(this.options);

  /// Create TileCrawler with WMTS support
  TileCrawler.wmts({
    required List<double> topLeftLatLng,
    required List<double> bottomRightLatLng,
    required int minZoomLevel,
    required int maxZoomLevel,
    required String urlTemplate,
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
    String downloadFolder = '',
  }) : options = DownloadOptions(
          topLeftLatLng: topLeftLatLng,
          bottomRightLatLng: bottomRightLatLng,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          tileUrlFormat: urlTemplate, // Note: This is a simplified approach
          downloadFolder: downloadFolder,
        );

  /// Start downloading tiles with enhanced progress tracking
  Future<void> download({
    OnStart? onStart,
    OnProcess? onProcess,
    OnEnd? onEnd,
    OnProcessError? onProcessError,
  }) async {
    await _downloadService.download(
      options: options,
      onStart: onStart,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onProcessError,
    );
  }

  /// Cancel the download process
  void cancel() {
    _downloadService.cancel();
  }

  /// Get download summary with area and tile count
  Future<CrawlerSummary> getSummary() async {
    return await options.summary;
  }
}

/// Enhanced TileCrawler with full generic tile support
class EnhancedTileCrawler {
  final EnhancedDownloadOptions options;
  final TileDownloadService _downloadService = TileDownloadService();

  EnhancedTileCrawler(this.options);

  /// Create with XYZ provider
  EnhancedTileCrawler.xyz({
    required List<double> topLeftLatLng,
    required List<double> bottomRightLatLng,
    required int minZoomLevel,
    required int maxZoomLevel,
    required String tileUrlFormat,
    String downloadFolder = '',
  }) : options = EnhancedDownloadOptions.fromXYZ(
          topLeftLatLng: topLeftLatLng,
          bottomRightLatLng: bottomRightLatLng,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          tileUrlFormat: tileUrlFormat,
          downloadFolder: downloadFolder,
        );

  /// Create with WMTS provider
  EnhancedTileCrawler.wmts({
    required List<double> topLeftLatLng,
    required List<double> bottomRightLatLng,
    required int minZoomLevel,
    required int maxZoomLevel,
    required String urlTemplate,
    required String layer,
    required String style,
    required String tileMatrixSet,
    String format = 'png',
    bool useRestful = true,
    String downloadFolder = '',
  }) : options = EnhancedDownloadOptions.fromWMTS(
          topLeftLatLng: topLeftLatLng,
          bottomRightLatLng: bottomRightLatLng,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          urlTemplate: urlTemplate,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          useRestful: useRestful,
          downloadFolder: downloadFolder,
        );

  /// Start downloading tiles with enhanced progress tracking
  Future<void> download({
    OnStart? onStart,
    OnProcess? onProcess,
    OnEnd? onEnd,
    OnProcessError? onProcessError,
  }) async {
    // Convert tiles to XYZ format for legacy download service
    final xyzTiles = await options.xyzQueue;
    final legacyOptions = DownloadOptions.fromTiles(
      tiles: xyzTiles,
      downloadFolder: options.downloadFolder,
      tileUrlFormat: options.tileProvider.urlTemplate,
    );

    await _downloadService.download(
      options: legacyOptions,
      onStart: onStart,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onProcessError,
    );
  }

  /// Cancel the download process
  void cancel() {
    _downloadService.cancel();
  }

  /// Get download summary with area and tile count
  Future<CrawlerSummary> getSummary() async {
    return CrawlerSummary(
      area: options.area,
      tileCount: (await options.queue).length,
    );
  }
}
