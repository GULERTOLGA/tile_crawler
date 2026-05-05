/// Offline tile download for Flutter / Dart clients.
library tile_crawler;

import 'model/crawler_summary.dart';
import 'model/download_options.dart';
import 'tile_download_service.dart';
import 'tile_provider_factory.dart';
import 'model/xyz.dart';

export 'model/xyz.dart';
export 'model/download_options.dart';
export 'model/download_status.dart';
export 'model/map_providers.dart';
export 'model/crawler_summary.dart';
export 'model/storage_layout.dart';
export 'model/resolved_download.dart';
export 'tile_download_security.dart';
export 'util/tile_url_helper.dart';
export 'util/download_path.dart';
export 'util/tile_content_type.dart';
export 'util/tile_projection_registry.dart';
export 'util/wmts_get_tile_path.dart';

export 'model/tile.dart';
export 'model/xyz_tile.dart' hide XYZ;
export 'model/wmts_tile.dart';
export 'providers/tile_provider.dart';
export 'providers/xyz_tile_provider.dart';
export 'providers/wmts_tile_provider.dart';
export 'providers/custom_wmts_tile_provider.dart';
export 'tile_provider_factory.dart';
export 'tile_download_service.dart';

typedef OnStart = void Function(
  int totalTileCount,
  int remainingTileCount,
  double area,
);
typedef OnProcess = void Function(
  int tilesDownloaded,
  int remainingTiles,
  XYZ xyz,
);
typedef OnProcessError = void Function(
  XYZ xyz,
  Object error,
  StackTrace stackTrace,
);
typedef OnEnd = void Function(int totalDownloaded, int totalSkipped);

/// Primary API: bbox + zoom + [TileProvider] (XYZ, WMTS, …).
class OfflineTileArchive {
  OfflineTileArchive(
    this.options, {
    TileDownloadService? downloadService,
  }) : _downloadService = downloadService ?? TileDownloadService();

  final EnhancedDownloadOptions options;
  final TileDownloadService _downloadService;

  factory OfflineTileArchive.xyz({
    required List<double> topLeftLatLng,
    required List<double> bottomRightLatLng,
    required int minZoomLevel,
    required int maxZoomLevel,
    required String tileUrlFormat,
    String downloadFolder = '',
    TileDownloadService? downloadService,
  }) {
    return OfflineTileArchive(
      EnhancedDownloadOptions.fromXYZ(
        topLeftLatLng: topLeftLatLng,
        bottomRightLatLng: bottomRightLatLng,
        minZoomLevel: minZoomLevel,
        maxZoomLevel: maxZoomLevel,
        tileUrlFormat: tileUrlFormat,
        downloadFolder: downloadFolder,
      ),
      downloadService: downloadService,
    );
  }

  factory OfflineTileArchive.wmts({
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
    TileDownloadService? downloadService,
  }) {
    return OfflineTileArchive(
      EnhancedDownloadOptions.fromWMTS(
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
      ),
      downloadService: downloadService,
    );
  }

  Future<void> download({
    OnStart? onStart,
    OnProcess? onProcess,
    OnEnd? onEnd,
    OnProcessError? onProcessError,
  }) {
    return _downloadService.downloadResolved(
      downloadFolder: options.downloadFolder,
      areaKm2: options.area,
      itemsFuture: options.resolvedDownloads,
      security: options.security,
      onStart: onStart,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onProcessError,
    );
  }

  void cancel() {
    _downloadService.cancel();
  }

  Future<CrawlerSummary> getSummary() async {
    return CrawlerSummary(
      area: options.area,
      tileCount: (await options.queue).length,
    );
  }
}

/// Use [OfflineTileArchive] instead.
@Deprecated('Use OfflineTileArchive')
class EnhancedTileCrawler extends OfflineTileArchive {
  EnhancedTileCrawler(
    super.options, {
    super.downloadService,
  });

  EnhancedTileCrawler.xyz({
    required List<double> topLeftLatLng,
    required List<double> bottomRightLatLng,
    required int minZoomLevel,
    required int maxZoomLevel,
    required String tileUrlFormat,
    String downloadFolder = '',
    TileDownloadService? downloadService,
  }) : super(
          EnhancedDownloadOptions.fromXYZ(
            topLeftLatLng: topLeftLatLng,
            bottomRightLatLng: bottomRightLatLng,
            minZoomLevel: minZoomLevel,
            maxZoomLevel: maxZoomLevel,
            tileUrlFormat: tileUrlFormat,
            downloadFolder: downloadFolder,
          ),
          downloadService: downloadService,
        );

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
    TileDownloadService? downloadService,
  }) : super(
          EnhancedDownloadOptions.fromWMTS(
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
          ),
          downloadService: downloadService,
        );
}

/// Legacy XYZ-only crawler using [DownloadOptions].
@Deprecated(
    'Use OfflineTileArchive.xyz or DownloadOptions with TileDownloadService')
class TileCrawler {
  TileCrawler(this.options);

  final DownloadOptions options;
  final TileDownloadService _downloadService = TileDownloadService();

  Future<void> download({
    OnStart? onStart,
    OnProcess? onProcess,
    OnEnd? onEnd,
    OnProcessError? onProcessError,
  }) {
    return _downloadService.download(
      options: options,
      onStart: onStart,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onProcessError,
    );
  }

  void cancel() {
    _downloadService.cancel();
  }

  Future<CrawlerSummary> getSummary() async {
    return options.summary;
  }
}
