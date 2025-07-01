import 'dart:async';
import 'dart:collection';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:isolate';

import 'model/xyz.dart';
import 'model/download_status.dart';
import 'model/download_options.dart';

typedef OnTileStart = void Function(
    int totalTileCount, int remainingTileCount, double area);
typedef OnTileProcess = void Function(
    int tilesDownloaded, int remainingTiles, XYZ xyz);
typedef OnTileError = void Function(
    XYZ xyz, Object error, StackTrace stackTrace);
typedef OnTileEnd = void Function(int totalDownloaded, int totalSkipped);

class TileDownloadService {
  static final List<ReceivePort?> _activeIsolates = [];

  // Progress tracking
  int _totalTileCount = 0;
  int _remainingTileCount = 0;
  int _downloadedTileCount = 0;
  int _skippedTileCount = 0;

  // HTTP client management
  static HttpClient? _sharedHttpClient;
  static int _clientRefCount = 0;

  // Cancellation and rate limiting
  final CancelToken _cancelToken = CancelToken();
  final _semaphore =
      Semaphore(20); // Higher concurrent downloads for better performance

  // Cache for already downloaded tiles
  final Set<String> _downloadedTileCache = <String>{};
  String? _currentDownloadFolder;

  bool _isCancelled = false;

  /// Check if tile file already exists on disk
  bool _isTileAlreadyDownloaded(XYZ tile, String downloadFolder) {
    final filePath = '$downloadFolder/${tile.z}/${tile.x}/${tile.y}.png';

    // Check cache first for performance
    if (_downloadedTileCache.contains(filePath)) {
      return true;
    }

    // Check actual file existence
    final file = File(filePath);
    final exists =
        file.existsSync() && file.lengthSync() > 0; // Ensure file has content

    if (exists) {
      _downloadedTileCache.add(filePath);
    }

    return exists;
  }

  /// Mark tile as successfully downloaded
  void _markTileAsDownloaded(XYZ tile, String downloadFolder) {
    final filePath = '$downloadFolder/${tile.z}/${tile.x}/${tile.y}.png';
    _downloadedTileCache.add(filePath);
  }

  /// Get or create optimized HTTP client
  static HttpClient _getSharedHttpClient() {
    if (_sharedHttpClient == null) {
      _sharedHttpClient = HttpClient();
      _sharedHttpClient!.maxConnectionsPerHost = 20;
      _sharedHttpClient!.connectionTimeout = const Duration(seconds: 30);
      _sharedHttpClient!.idleTimeout = const Duration(seconds: 30);
      _sharedHttpClient!.autoUncompress = true;
    }
    _clientRefCount++;
    return _sharedHttpClient!;
  }

  /// Release HTTP client when no longer needed
  static void _releaseSharedHttpClient() {
    _clientRefCount--;
    if (_clientRefCount <= 0 && _sharedHttpClient != null) {
      _sharedHttpClient!.close();
      _sharedHttpClient = null;
      _clientRefCount = 0;
    }
  }

  /// Cancel all active downloads
  void cancel() {
    _isCancelled = true;
    _cancelToken.cancel();

    dev.log("Cancelling ${_activeIsolates.length} active isolates",
        name: "TileDownloadService", level: 1800);

    for (var port in _activeIsolates) {
      port?.close();
    }
    _activeIsolates.clear();
    _releaseSharedHttpClient();
  }

  /// Start downloading tiles with progress tracking
  Future<void> download({
    required DownloadOptions options,
    OnTileStart? onStart,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) async {
    _initializeDownloadSession();
    _currentDownloadFolder = options.downloadFolder;

    // Get all tiles that need to be processed
    final allTiles = await options.queue;
    _totalTileCount = allTiles.length;

    // Separate already downloaded tiles from tiles that need downloading
    final tilesToDownload = <XYZ>[];
    final alreadyDownloadedTiles = <XYZ>[];

    for (final tile in allTiles) {
      if (_isTileAlreadyDownloaded(tile, options.downloadFolder)) {
        alreadyDownloadedTiles.add(tile);
      } else {
        tilesToDownload.add(tile);
      }
    }

    // Update counters
    _skippedTileCount = alreadyDownloadedTiles.length;
    _remainingTileCount = tilesToDownload.length;
    _downloadedTileCount = 0;

    dev.log(
        "Download session initialized: "
        "Total: $_totalTileCount, "
        "To download: ${tilesToDownload.length}, "
        "Already exists: $_skippedTileCount",
        name: "TileDownloadService");

    // Notify start with accurate counts
    onStart?.call(_totalTileCount, _remainingTileCount, options.area);

    if (tilesToDownload.isEmpty) {
      // All tiles already downloaded
      onEnd?.call(_downloadedTileCount, _skippedTileCount);
      return;
    }

    // Start downloading remaining tiles
    await _downloadTilesWithOptimalStrategy(
      tiles: tilesToDownload,
      options: options,
      onProcess: onProcess,
      onEnd: onEnd,
      onError: onError,
    );
  }

  /// Initialize download session counters
  void _initializeDownloadSession() {
    _isCancelled = false;
    _cancelToken.reset();
    _totalTileCount = 0;
    _remainingTileCount = 0;
    _downloadedTileCount = 0;
    _skippedTileCount = 0;
    _downloadedTileCache.clear();
  }

  /// Calculate optimal thread count based on tile count and system resources
  int _calculateOptimalConcurrency(int tileCount) {
    final int availableProcessors = (Platform.numberOfProcessors / 2).round();

    if (tileCount < 100) {
      return 2; // Small batches don't need much concurrency
    } else if (tileCount < 1000) {
      return (availableProcessors * 0.75).clamp(2, 4).round();
    } else {
      return (availableProcessors * 0.9).clamp(4, 8).round();
    }
  }

  /// Choose optimal download strategy based on tile count
  Future<void> _downloadTilesWithOptimalStrategy({
    required List<XYZ> tiles,
    required DownloadOptions options,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) async {
    final tileCount = tiles.length;

    // Use single-threaded approach for smaller sets, isolates for larger sets
    if (tileCount < 300) {
      await _downloadWithConnectionPool(
        tiles: tiles,
        options: options,
        onProcess: onProcess,
        onEnd: onEnd,
        onError: onError,
      );
    } else {
      final concurrency = _calculateOptimalConcurrency(tileCount);
      await _downloadWithIsolates(
        tiles: tiles,
        options: options,
        concurrency: concurrency,
        onProcess: onProcess,
        onEnd: onEnd,
        onError: onError,
      );
    }
  }

  /// Single-threaded download with connection pooling for smaller sets
  Future<void> _downloadWithConnectionPool({
    required List<XYZ> tiles,
    required DownloadOptions options,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) async {
    final client = _getSharedHttpClient();
    final serializedOptions = _serializeOptions(options);

    try {
      await Future.wait(
        tiles.map((tile) => _downloadSingleTileWithRateLimit(
              tile: tile,
              options: serializedOptions,
              client: client,
              onProcess: onProcess,
              onError: onError,
            )),
        eagerError: false, // Continue downloading even if some tiles fail
      );
    } finally {
      _releaseSharedHttpClient();
      onEnd?.call(_downloadedTileCount, _skippedTileCount);
    }
  }

  /// Download single tile with semaphore rate limiting
  Future<void> _downloadSingleTileWithRateLimit({
    required XYZ tile,
    required Map<String, dynamic> options,
    required HttpClient client,
    OnTileProcess? onProcess,
    OnTileError? onError,
  }) async {
    await _semaphore.acquire();

    try {
      if (_isCancelled || _cancelToken.isCancelled) return;

      await _downloadSingleTileOptimized(tile, options, client);

      if (!_isCancelled && !_cancelToken.isCancelled) {
        _markTileAsDownloaded(tile, options['downloadFolder'] as String);
        _downloadedTileCount++;
        _remainingTileCount--;
        onProcess?.call(_downloadedTileCount, _remainingTileCount, tile);
      }
    } catch (e, stackTrace) {
      if (!_isCancelled && !_cancelToken.isCancelled) {
        _remainingTileCount--;
        onError?.call(tile, e, stackTrace);
      }
    } finally {
      _semaphore.release();
    }
  }

  /// Multi-threaded download using isolates for larger sets
  Future<void> _downloadWithIsolates({
    required List<XYZ> tiles,
    required DownloadOptions options,
    required int concurrency,
    OnTileProcess? onProcess,
    OnTileEnd? onEnd,
    OnTileError? onError,
  }) async {
    final tileBatches = _createTileBatches(tiles, concurrency);

    // Single ReceivePort for all isolates
    final receivePort = ReceivePort();
    _activeIsolates.add(receivePort);

    final completer = Completer<void>();
    int completedIsolates = 0;

    // Track which isolates have started
    final Set<int> startedIsolates = <int>{};

    // Listen to all isolate messages on single port
    receivePort.listen((message) {
      if (message is DownloadStatus) {
        switch (message.status) {
          case DownloadStatusEnum.completed:
            completedIsolates++;
            dev.log(
                "Isolate completed: $completedIsolates / ${tileBatches.length}",
                name: "TileDownloadService");

            if (completedIsolates == tileBatches.length) {
              dev.log("All isolates completed successfully",
                  name: "TileDownloadService");
              receivePort.close();
              _activeIsolates.remove(receivePort);
              _releaseSharedHttpClient();
              onEnd?.call(_downloadedTileCount, _skippedTileCount);
              completer.complete();
            }
            break;

          case DownloadStatusEnum.error:
            if (!_isCancelled && !_cancelToken.isCancelled) {
              _remainingTileCount--;
              onError?.call(message.xyz!, message.error!, message.stackTrace!);
            }
            break;

          case DownloadStatusEnum.downloading:
            if (!_isCancelled && !_cancelToken.isCancelled) {
              if (_currentDownloadFolder != null) {
                _markTileAsDownloaded(message.xyz!, _currentDownloadFolder!);
              }
              _downloadedTileCount++;
              _remainingTileCount--;
              onProcess?.call(
                  _downloadedTileCount, _remainingTileCount, message.xyz!);

              // Log periodic progress for debugging
              if (_downloadedTileCount % 100 == 0) {
                dev.log(
                    "Progress: $_downloadedTileCount downloaded, $startedIsolates isolates active",
                    name: "TileDownloadService");
              }
            }
            break;
        }
      }
    });

    // Spawn all isolates with shared SendPort (sequential to avoid race conditions)
    for (int i = 0; i < tileBatches.length; i++) {
      if (_isCancelled) break;

      dev.log("Spawning isolate $i with ${tileBatches[i].length} tiles",
          name: "TileDownloadService");

      try {
        // Spawn isolates sequentially to avoid spawn failures
        await Isolate.spawn(_downloadIsolateEntry, {
          'sendPort': receivePort.sendPort,
          'tiles': tileBatches[i],
          'options': _serializeOptions(options),
          'cancelToken': _cancelToken.token,
          'isolateId': i,
        });

        dev.log("Successfully spawned isolate $i", name: "TileDownloadService");

        // Small delay between spawns
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        dev.log("Failed to spawn isolate $i: $e", name: "TileDownloadService");
        // Continue with other isolates
      }
    }
    dev.log("All ${tileBatches.length} isolates spawned successfully",
        name: "TileDownloadService");

    // Wait for all isolates to complete with timeout
    try {
      // Add a periodic check to see if isolates are stuck
      Timer.periodic(Duration(seconds: 30), (timer) {
        if (completer.isCompleted) {
          timer.cancel();
          return;
        }
        dev.log(
            "Progress check: $completedIsolates/${tileBatches.length} isolates completed, "
            "$_downloadedTileCount tiles downloaded",
            name: "TileDownloadService");
      });

      await completer.future.timeout(Duration(minutes: 15), // 15 minute timeout
          onTimeout: () {
        dev.log("Download timeout after 15 minutes, cleaning up",
            name: "TileDownloadService");
        receivePort.close();
        _activeIsolates.remove(receivePort);
        throw TimeoutException(
            'Download timed out after 15 minutes', Duration(minutes: 15));
      });
    } catch (e) {
      dev.log("Download error: $e", name: "TileDownloadService");
      receivePort.close();
      _activeIsolates.remove(receivePort);
      rethrow;
    }
  }

  /// Split tiles into balanced batches for isolates
  List<List<XYZ>> _createTileBatches(List<XYZ> tiles, int batchCount) {
    final batches = <List<XYZ>>[];
    final batchSize = (tiles.length / batchCount).ceil();

    for (int i = 0; i < batchCount; i++) {
      final startIndex = i * batchSize;
      final endIndex = (startIndex + batchSize).clamp(0, tiles.length);

      // Always add batch if there are tiles in range
      if (startIndex < tiles.length && endIndex > startIndex) {
        final batch = tiles.sublist(startIndex, endIndex);
        batches.add(batch);
        dev.log(
            "Batch $i: ${batch.length} tiles (${startIndex}-${endIndex - 1})",
            name: "TileDownloadService");
      }
    }

    final totalTiles = batches.fold<int>(0, (sum, batch) => sum + batch.length);
    dev.log(
        "Created ${batches.length} batches, total tiles: $totalTiles (original: ${tiles.length})",
        name: "TileDownloadService");

    return batches;
  }

  /// Convert DownloadOptions to serializable map for isolate communication
  Map<String, dynamic> _serializeOptions(DownloadOptions options) {
    return {
      'tileUrlFormat': options.tileUrlFormat,
      'downloadFolder': options.downloadFolder,
    };
  }
}

/// Semaphore for controlling concurrent downloads
class Semaphore {
  final int maxConcurrency;
  int _currentCount;
  final Queue<Completer<void>> _waitingQueue = Queue<Completer<void>>();

  Semaphore(this.maxConcurrency) : _currentCount = maxConcurrency;

  /// Acquire a permit - wait if none available
  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitingQueue.add(completer);
    return completer.future;
  }

  /// Release a permit - signal waiting tasks
  void release() {
    if (_waitingQueue.isNotEmpty) {
      final completer = _waitingQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

/// Token for coordinated cancellation across isolates
class CancelToken {
  bool _isCancelled = false;
  String _token = '';

  bool get isCancelled => _isCancelled;
  String get token => _token;

  void cancel() {
    _isCancelled = true;
    _token = DateTime.now().millisecondsSinceEpoch.toString();
  }

  void reset() {
    _isCancelled = false;
    _token = DateTime.now().millisecondsSinceEpoch.toString();
  }
}

/// Semaphore for controlling concurrent downloads within isolate
class _IsolateSemaphore {
  final int maxConcurrency;
  int _currentCount;
  final Queue<Completer<void>> _waitingQueue = Queue<Completer<void>>();

  _IsolateSemaphore(this.maxConcurrency) : _currentCount = maxConcurrency;

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

/// Entry point for isolate-based tile downloading
void _downloadIsolateEntry(Map<String, dynamic> message) async {
  final tiles = message['tiles'] as List<XYZ>;
  final sendPort = message['sendPort'] as SendPort;
  final options = message['options'] as Map<String, dynamic>;
  final cancelToken = message['cancelToken'] as String;
  final isolateId = message['isolateId'] as int;

  // Create HTTP client optimized for this isolate
  final client = HttpClient();
  client.maxConnectionsPerHost = 20; // Much higher connection limit
  client.connectionTimeout = const Duration(seconds: 15);
  client.idleTimeout = const Duration(seconds: 30);
  client.autoUncompress = true;

  // Thread-safe result counting will be done after all downloads complete

  dev.log("Isolate $isolateId started with ${tiles.length} tiles",
      name: "DownloadIsolate");

  try {
    // Use semaphore to control concurrent downloads within isolate
    final semaphore =
        _IsolateSemaphore(6); // Reduced to 6 to prevent overwhelming server

    dev.log("Isolate $isolateId starting downloads...",
        name: "DownloadIsolate");

    // Download tiles in parallel within this isolate
    final downloadResults = await Future.wait(
      tiles.map((tile) async {
        await semaphore.acquire();
        try {
          // Check for cancellation signal
          if (cancelToken != message['cancelToken']) {
            return 'cancelled';
          }

          // Add progress tracking
          final start = DateTime.now();
          await _downloadSingleTileOptimized(tile, options, client);
          final duration = DateTime.now().difference(start);

          try {
            sendPort.send(DownloadStatus.downloading(tile));
          } catch (e) {
            dev.log(
                "Failed to send progress message for tile ${tile.z}/${tile.x}/${tile.y}: $e",
                name: "DownloadIsolate");
          }

          // Log slow downloads for debugging
          if (duration.inMilliseconds > 5000) {
            dev.log(
                "Slow download: ${tile.z}/${tile.x}/${tile.y} took ${duration.inMilliseconds}ms",
                name: "DownloadIsolate");
          }

          return 'success';
        } catch (e, stackTrace) {
          try {
            sendPort.send(DownloadStatus.error(e, stackTrace, tile));
          } catch (sendError) {
            dev.log(
                "Failed to send error message for tile ${tile.z}/${tile.x}/${tile.y}: $sendError",
                name: "DownloadIsolate");
          }
          return 'error';
        } finally {
          semaphore.release();
        }
      }),
      eagerError: false, // Continue even if some downloads fail
    );

    dev.log("Isolate $isolateId finished downloads, sending completion...",
        name: "DownloadIsolate");

    // Count results safely after all downloads complete
    final successCount = downloadResults.where((r) => r == 'success').length;
    final errorCount = downloadResults.where((r) => r == 'error').length;
    final cancelledCount =
        downloadResults.where((r) => r == 'cancelled').length;

    dev.log(
        "Isolate $isolateId completed: $successCount success, $errorCount errors, $cancelledCount cancelled",
        name: "DownloadIsolate");
  } catch (isolateError) {
    dev.log("Isolate $isolateId crashed: $isolateError",
        name: "DownloadIsolate");
  } finally {
    try {
      client.close();
    } catch (e) {
      dev.log("Error closing client in isolate $isolateId: $e",
          name: "DownloadIsolate");
    }

    try {
      sendPort.send(DownloadStatus.completed());
      dev.log("Isolate $isolateId sent completion signal",
          name: "DownloadIsolate");
    } catch (e) {
      dev.log("Failed to send completion signal from isolate $isolateId: $e",
          name: "DownloadIsolate");
    }
  }
}

/// Download single tile with retry mechanism and error handling
Future<void> _downloadSingleTileOptimized(
  XYZ tile,
  Map<String, dynamic> options,
  HttpClient client,
) async {
  var tileUrl = options['tileUrlFormat'] as String;

  // Build tile URL by replacing placeholders
  if (tileUrl.contains("{quadkey}")) {
    tileUrl = tileUrl.replaceAll("{quadkey}", tile.toQuadKey());
  } else {
    tileUrl = tileUrl
        .replaceAll("{x}", tile.x.toString())
        .replaceAll("{y}", tile.y.toString())
        .replaceAll("{z}", tile.z.toString());
  }

  const maxRetries = 3;
  int attempt = 0;

  while (attempt < maxRetries) {
    try {
      final request = await client.getUrl(Uri.parse(tileUrl));

      // Set optimal headers for tile downloading
      request.headers.set('Accept', 'image/png,image/*;q=0.8,*/*;q=0.5');
      request.headers.set('Accept-Encoding', 'gzip, deflate');
      request.headers.set('User-Agent', 'TileCrawler/1.0');

      final response = await request.close();

      if (response.statusCode == 200) {
        await _saveTileToFile(tile, options, response);
        return; // Success - exit retry loop
      } else if (response.statusCode == 404) {
        // Tile doesn't exist - don't retry
        throw Exception('Tile not found (404): $tile');
      } else if (response.statusCode >= 500) {
        // Server error - retry
        throw Exception('Server error ${response.statusCode} for tile: $tile');
      } else {
        // Client error - don't retry
        throw Exception('HTTP ${response.statusCode} for tile: $tile');
      }
    } catch (e) {
      attempt++;
      if (attempt >= maxRetries) {
        throw Exception(
            'Failed to download tile $tile after $maxRetries attempts: $e');
      }

      // Shorter progressive backoff: 100ms, 200ms, 400ms
      final delayMs = 100 * (1 << (attempt - 1));
      await Future.delayed(Duration(milliseconds: delayMs));
    }
  }
}

/// Save downloaded tile data to file system
Future<void> _saveTileToFile(
  XYZ tile,
  Map<String, dynamic> options,
  HttpClientResponse response,
) async {
  final downloadFolder = options['downloadFolder'] as String;
  final tileDirectory = "$downloadFolder/${tile.z}/${tile.x}";
  final tileFilePath = "$tileDirectory/${tile.y}.png";

  // Create directory structure if it doesn't exist
  final directory = Directory(tileDirectory);
  await directory.create(recursive: true);

  // Write tile data to file
  final file = File(tileFilePath);
  final sink = file.openWrite();

  try {
    await response.pipe(sink);
    await sink.flush();
  } finally {
    await sink.close();
  }

  // Verify file was written successfully
  if (!file.existsSync() || file.lengthSync() == 0) {
    throw Exception('Failed to save tile file: $tileFilePath');
  }
}
