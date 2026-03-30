import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'model/download_options.dart';
import 'model/resolved_download.dart';
import 'model/xyz.dart';
import 'tile_download_security.dart';
import 'util/download_path.dart';
import 'util/tile_content_type.dart';

typedef OnTileStart = void Function(
  int totalTileCount,
  int remainingTileCount,
  double area,
);
typedef OnTileProcess = void Function(
  int tilesDownloaded,
  int remainingTiles,
  XYZ xyz,
);
typedef OnTileError = void Function(
  XYZ xyz,
  Object error,
  StackTrace stackTrace,
);
typedef OnTileEnd = void Function(int totalDownloaded, int totalSkipped);

/// Downloads map tiles using [dart:io] [HttpClient] only (no `package:http`).
///
/// Isolates were removed: concurrency is handled with a [Semaphore] and one
/// [HttpClient] per [download] / [downloadResolved] call for predictable
/// lifecycle and cancellation.
class TileDownloadService {
  TileDownloadService({
    HttpClient? httpClient,
    int maxConcurrentDownloads = 20,
  })  : _injectedClient = httpClient,
        _semaphore = Semaphore(maxConcurrentDownloads);

  final HttpClient? _injectedClient;
  final Semaphore _semaphore;

  final CancelToken _cancelToken = CancelToken();

  int _totalTileCount = 0;
  int _remainingTileCount = 0;
  int _downloadedTileCount = 0;
  int _skippedTileCount = 0;

  final Set<String> _downloadedTileCache = <String>{};
  bool _isCancelled = false;

  bool _fileExistsNonEmpty(String absolutePath) {
    final file = File(absolutePath);
    return file.existsSync() && file.lengthSync() > 0;
  }

  bool _isResolvedAlreadyOnDisk(ResolvedDownload item, String downloadFolder) {
    final safe = safeTileFilePath(downloadFolder, item.relativePath);
    if (_downloadedTileCache.contains(safe)) {
      return true;
    }
    if (_fileExistsNonEmpty(safe)) {
      _downloadedTileCache.add(safe);
      return true;
    }
    return false;
  }

  /// Cancels in-flight work for this service instance (session-scoped).
  void cancel() {
    _isCancelled = true;
    _cancelToken.cancel();
  }

  /// Legacy entry: builds [ResolvedDownload] list from [DownloadOptions].
  Future<void> download({
    required DownloadOptions options,
    OnTileStart? onStart,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) {
    return downloadResolved(
      downloadFolder: options.downloadFolder,
      areaKm2: options.area,
      itemsFuture: options.resolvedDownloads,
      security: options.security,
      onStart: onStart,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onError,
    );
  }

  /// Primary API: [itemsFuture] supplies the full download plan (URLs + paths).
  Future<void> downloadResolved({
    required String downloadFolder,
    required double areaKm2,
    required Future<List<ResolvedDownload>> itemsFuture,
    TileDownloadSecurity? security,
    OnTileStart? onStart,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) async {
    _initializeDownloadSession();

    final allItems = await itemsFuture;
    _totalTileCount = allItems.length;

    final toFetch = <ResolvedDownload>[];
    final skipped = <ResolvedDownload>[];

    for (final item in allItems) {
      if (_isResolvedAlreadyOnDisk(item, downloadFolder)) {
        skipped.add(item);
      } else {
        toFetch.add(item);
      }
    }

    _skippedTileCount = skipped.length;
    _remainingTileCount = toFetch.length;
    _downloadedTileCount = 0;

    dev.log(
      'Download session: total=$_totalTileCount toFetch=${toFetch.length} '
      'skipped=$_skippedTileCount',
      name: 'TileDownloadService',
    );

    onStart?.call(_totalTileCount, _remainingTileCount, areaKm2);

    if (toFetch.isEmpty) {
      onEnd?.call(_downloadedTileCount, _skippedTileCount);
      return;
    }

    final client = _injectedClient ?? _createSessionClient();
    final ownClient = _injectedClient == null;

    try {
      await Future.wait(
        toFetch.map(
          (item) => _downloadOne(
            item: item,
            downloadFolder: downloadFolder,
            client: client,
            security: security,
            onProcess: onProcess,
            onError: onError,
          ),
        ),
        eagerError: false,
      );
    } finally {
      if (ownClient) {
        client.close(force: true);
      }
      onEnd?.call(_downloadedTileCount, _skippedTileCount);
    }
  }

  void _initializeDownloadSession() {
    _isCancelled = false;
    _cancelToken.reset();
    _totalTileCount = 0;
    _remainingTileCount = 0;
    _downloadedTileCount = 0;
    _skippedTileCount = 0;
    _downloadedTileCache.clear();
  }

  HttpClient _createSessionClient() {
    final c = HttpClient();
    c.maxConnectionsPerHost = 20;
    c.connectionTimeout = const Duration(seconds: 30);
    c.idleTimeout = const Duration(seconds: 30);
    c.autoUncompress = true;
    return c;
  }

  Future<void> _downloadOne({
    required ResolvedDownload item,
    required String downloadFolder,
    required HttpClient client,
    required TileDownloadSecurity? security,
    OnTileProcess? onProcess,
    OnTileError? onError,
  }) async {
    await _semaphore.acquire();
    try {
      if (_isCancelled || _cancelToken.isCancelled) {
        return;
      }

      final host = item.url.host;
      if (security != null && !security.isHostAllowed(host)) {
        throw StateError('Host not allowed: $host');
      }

      final writtenRelative = await _httpGetAndSave(
        item: item,
        downloadFolder: downloadFolder,
        client: client,
      );

      if (!_isCancelled && !_cancelToken.isCancelled) {
        final path = safeTileFilePath(downloadFolder, writtenRelative);
        _downloadedTileCache.add(path);
        _downloadedTileCount++;
        _remainingTileCount--;
        onProcess?.call(
          _downloadedTileCount,
          _remainingTileCount,
          item.progressXYZ,
        );
      }
    } catch (e, st) {
      if (!_isCancelled && !_cancelToken.isCancelled) {
        _remainingTileCount--;
        onError?.call(item.progressXYZ, e, st);
      }
    } finally {
      _semaphore.release();
    }
  }

  Future<String> _httpGetAndSave({
    required ResolvedDownload item,
    required String downloadFolder,
    required HttpClient client,
  }) async {
    const maxRetries = 3;
    var attempt = 0;
    while (attempt < maxRetries) {
      try {
        final request = await client.getUrl(item.url);
        request.headers.set(
          'Accept',
          'image/png,image/jpeg,image/webp,image/*;q=0.8,*/*;q=0.5',
        );
        request.headers.set('Accept-Encoding', 'gzip, deflate');
        request.headers.set('User-Agent', 'TileCrawler/1.0');

        final response = await request.close();
        final code = response.statusCode;
        final contentType =
            response.headers.value(HttpHeaders.contentTypeHeader);
        final bytes = await _collectBytes(response);

        if (code == 200) {
          final ext = extensionForTilePayload(
                bytes: bytes,
                contentTypeHeader: contentType,
              ) ??
              _extensionFromRelativePath(item.relativePath);
          var relative = item.relativePath;
          final hinted =
              p.extension(relative).replaceFirst('.', '').toLowerCase();
          if (ext != hinted) {
            relative = '${p.withoutExtension(relative)}.$ext';
          }
          final fullPath = safeTileFilePath(downloadFolder, relative);
          await Directory(p.dirname(fullPath)).create(recursive: true);
          await File(fullPath).writeAsBytes(bytes, flush: true);
          if (!_fileExistsNonEmpty(fullPath)) {
            throw StateError('Empty or missing file after write: $fullPath');
          }
          return relative;
        }
        if (code == 404) {
          throw Exception('Tile not found (404): ${item.url}');
        }
        if (code >= 500) {
          throw Exception('Server error $code for ${item.url}');
        }
        throw Exception('HTTP $code for ${item.url}');
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          rethrow;
        }
        final delayMs = 100 * (1 << (attempt - 1));
        await Future<void>.delayed(Duration(milliseconds: delayMs));
      }
    }
    throw StateError('unreachable');
  }

  String _extensionFromRelativePath(String relativePath) {
    final e = p.extension(relativePath).replaceFirst('.', '').toLowerCase();
    if (e.isEmpty) {
      return 'bin';
    }
    return e;
  }
}

Future<Uint8List> _collectBytes(HttpClientResponse response) async {
  final builder = BytesBuilder(copy: false);
  await for (final chunk in response) {
    builder.add(chunk);
  }
  return builder.toBytes();
}

/// Rate limiting for concurrent GETs.
class Semaphore {
  Semaphore(this.maxConcurrency) : _currentCount = maxConcurrency;

  final int maxConcurrency;
  int _currentCount;
  final Queue<Completer<void>> _waitingQueue = Queue<Completer<void>>();

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }
    final completer = Completer<void>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Coordinated cancellation for one [TileDownloadService] instance.
class CancelToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void reset() {
    _isCancelled = false;
  }
}
