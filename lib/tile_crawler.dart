library tile_crawler;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'tile_download_service.dart';
import 'model/xyz.dart';
import 'model/download_options.dart';
import 'model/download_status.dart';
import 'model/map_providers.dart';
import 'model/crawler_summary.dart';

// Export all public classes
export 'model/xyz.dart';
export 'model/download_options.dart';
export 'model/download_status.dart';
export 'model/map_providers.dart';
export 'model/crawler_summary.dart';

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
