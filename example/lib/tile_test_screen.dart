import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';

class TileTestScreen extends StatefulWidget {
  const TileTestScreen({Key? key}) : super(key: key);

  @override
  State<TileTestScreen> createState() => _TileTestScreenState();
}

class _TileTestScreenState extends State<TileTestScreen>
    with TickerProviderStateMixin {
  // Progress tracking
  int _totalTileCount = 0;
  int _tilesDownloaded = 0;
  int _remainingTiles = 0;
  int _errorCount = 0;
  int _skippedTiles = 0;

  // Current tile info
  String _currentTileInfo = '';

  // Performance metrics
  double _downloadSpeed = 0.0;
  String _currentStrategy = 'Auto';
  double _areaKm2 = 0.0;

  // Crawlers
  TileCrawler? _legacyCrawler;
  OfflineTileArchive? _enhancedCrawler;
  bool _isDownloading = false;

  // Performance tracking
  DateTime? _startTime;
  Timer? _speedTimer;

  // Test mode
  TestMode _testMode = TestMode.xyz;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _statsController;

  // Test configurations
  final Map<TestMode, TestConfig> _testConfigs = {
    TestMode.xyz: TestConfig(
      name: 'XYZ Tiles (OpenStreetMap)',
      description: 'Standard XYZ tile format used by most map services',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      color: Colors.blue,
      icon: Icons.map,
    ),
    TestMode.wmtsRestful: TestConfig(
      name: 'WMTS RESTful (ArcGIS)',
      description: 'WMTS service using RESTful URL pattern',
      urlTemplate:
          'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/tile/1.0.0/World_Imagery/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg',
      color: Colors.green,
      icon: Icons.satellite,
    ),
    TestMode.wmtsKvp: TestConfig(
      name: 'WMTS KVP Format',
      description: 'WMTS service using Key-Value Pair parameters',
      urlTemplate: 'https://example.com/wmts',
      color: Colors.purple,
      icon: Icons.settings,
    ),
    TestMode.customWmts: TestConfig(
      name: 'Custom WMTS (Turkish Registry)',
      description: 'Custom WMTS with authentication and special projections',
      urlTemplate: 'https://your-wmts-server.com/wmts',
      color: Colors.red,
      icon: Icons.security,
    ),
    TestMode.netgisPlan1000: TestConfig(
      name: 'NetGIS Plan1000',
      description: 'NetGIS Plan1000 katmanı (EPSG:7933) - Gerçek sunucu testi',
      urlTemplate: 'https://ssltest.netcad.com.tr/netgisnew/wmts.ashx',
      color: Colors.teal,
      icon: Icons.public,
    ),
    TestMode.backwardCompatibility: TestConfig(
      name: 'Legacy TileCrawler',
      description: 'Test backward compatibility with original API',
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      color: Colors.orange,
      icon: Icons.history,
    ),
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _statsController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _statsController.dispose();
    _speedTimer?.cancel();
    super.dispose();
  }

  void _resetDownloadStats() {
    setState(() {
      _totalTileCount = 0;
      _tilesDownloaded = 0;
      _remainingTiles = 0;
      _errorCount = 0;
      _skippedTiles = 0;
      _downloadSpeed = 0.0;
      _currentTileInfo = '';
    });
    _progressController.reset();
  }

  void _startSpeedTracking() {
    _speedTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_startTime != null && _tilesDownloaded > 0) {
        final elapsed = DateTime.now().difference(_startTime!).inSeconds;
        if (elapsed > 0) {
          setState(() {
            _downloadSpeed = _tilesDownloaded / elapsed.toDouble();
          });
        }
      }
    });
  }

  void _stopSpeedTracking() {
    _speedTimer?.cancel();
  }

  void _startDownload() async {
    if (_isDownloading) return;

    _resetDownloadStats();
    _startTime = DateTime.now();
    _startSpeedTracking();

    var dir = await getApplicationDocumentsDirectory();
    final config = _testConfigs[_testMode]!;

    try {
      switch (_testMode) {
        case TestMode.xyz:
          await _startXYZDownload(dir.path, config);
          break;
        case TestMode.wmtsRestful:
          await _startWMTSRestfulDownload(dir.path, config);
          break;
        case TestMode.wmtsKvp:
          await _startWMTSKvpDownload(dir.path, config);
          break;
        case TestMode.customWmts:
          await _startCustomWMTSDownload(dir.path, config);
          break;
        case TestMode.netgisPlan1000:
          await _startNetGISPlan1000Download(dir.path, config);
          break;
        case TestMode.backwardCompatibility:
          await _startLegacyDownload(dir.path, config);
          break;
      }
    } catch (e) {
      log('❌ Download failed: $e');
      _showErrorDialog(e.toString());
      setState(() {
        _isDownloading = false;
      });
    }
  }

  Future<void> _startXYZDownload(String basePath, TestConfig config) async {
    final crawler = OfflineTileArchive.xyz(
      topLeftLatLng: [39.898931, 32.701024], // Ankara coordinates
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: 10,
      maxZoomLevel: 12,
      tileUrlFormat: config.urlTemplate,
      downloadFolder: '$basePath/xyz_tiles',
    );

    _enhancedCrawler = crawler;
    await _executeDownload(crawler, 'XYZ');
  }

  Future<void> _startWMTSRestfulDownload(
    String basePath,
    TestConfig config,
  ) async {
    final crawler = OfflineTileArchive.wmts(
      topLeftLatLng: [39.898931, 32.701024],
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: 10,
      maxZoomLevel: 11,
      urlTemplate: config.urlTemplate,
      layer: 'World_Imagery',
      style: 'default',
      tileMatrixSet: 'GoogleMapsCompatible',
      format: 'jpg',
      useRestful: true,
      downloadFolder: '$basePath/wmts_restful',
    );

    _enhancedCrawler = crawler;
    await _executeDownload(crawler, 'WMTS RESTful');
  }

  Future<void> _startWMTSKvpDownload(String basePath, TestConfig config) async {
    // Create a WMTS provider with KVP format
    final provider = TileProviderFactory.createWMTSProvider(
      urlTemplate: 'https://geodata.nationaalgeoregister.nl/wmts',
      layer: 'brtachtergrondkaart',
      style: 'default',
      tileMatrixSet: 'EPSG:3857',
      format: 'png',
      useRestful: false, // Use KVP format
    );

    final options = EnhancedDownloadOptions(
      topLeftLatLng: [39.898931, 32.701024],
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: 10,
      maxZoomLevel: 10,
      tileProvider: provider,
      downloadFolder: '$basePath/wmts_kvp',
    );

    final crawler = OfflineTileArchive(options);
    _enhancedCrawler = crawler;
    await _executeDownload(crawler, 'WMTS KVP');
  }

  Future<void> _startCustomWMTSDownload(
    String basePath,
    TestConfig config,
  ) async {
    // Create a custom WMTS provider with authentication and custom parameters
    final provider = CustomWMTSProviders.createWithAuth(
      baseUrl: 'https://your-wmts-server.com/wmts',
      sid: 'demo_session_id',
      layer: 'Plan1000',
      style: 'default',
      tileMatrixSet: 'Plan1000_7933',
      format: 'png',
      projectionCode: KnownProjections.epsg7933Code,
      projectionDef: KnownProjections.epsg7933Def,
      resolutions: const [
        15624.984375,
        7812.4921875,
        3906.24609375,
        1953.123046875,
        976.5615234375,
        488.28076171875,
        244.140380859375,
        122.0701904296875,
        61.03509521484375,
        30.517547607421875,
        15.2587738037109375,
        7.62938690185546875,
        3.814693450927734375,
        1.9073467254638671875,
        0.95367336273193359375,
        0.47683668136596875,
        0.23841834068298359375,
        0.119209170341491796875
      ],
      originX: -180,
      originY: 31999878,
      customParams: 'NCWS=wmtstest',
      name: 'Turkish Land Registry Custom',
    );

    final options = EnhancedDownloadOptions(
      topLeftLatLng: [39.898931, 32.701024],
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: 5, // Lower zoom for custom resolutions
      maxZoomLevel: 8,
      tileProvider: provider,
      downloadFolder: '$basePath/custom_wmts',
    );

    final crawler = OfflineTileArchive(options);
    _enhancedCrawler = crawler;
    await _executeDownload(crawler, 'Custom WMTS');
  }

  Future<void> _startNetGISPlan1000Download(
    String basePath,
    TestConfig config,
  ) async {
    // CRS must match the WMTS tile matrix set (here TM3 / GRS80, EPSG:7933).
    final provider = CustomWMTSTileProvider(
      urlTemplate: config.urlTemplate,
      layer: 'AlanyaPlanWMS',
      style: 'default',
      tileMatrixSet: 'AlanyaPlanWMS_7933',
      format: 'png',
      projectionCode: KnownProjections.epsg7933Code,
      projectionDef: KnownProjections.epsg7933Def,
      resolutions: CustomWMTSProviders.netgisPlan1000Resolutions,
      originX: -180,
      originY: 31999878,
      tileSize: 256,
      customParams: 'NCWS=ALANYA_BELNETMAP6',
      name: 'NetGIS Plan1000',
    );

    final options = EnhancedDownloadOptions(
      topLeftLatLng: [36.55671691910899, 31.9852927882567], // Ankara area
      bottomRightLatLng: [36.54236919973332, 32.00151888772663],
      minZoomLevel: 13,
      maxZoomLevel: 14,
      tileProvider: provider,
      downloadFolder: '$basePath/netgis_plan1000',
    );

    final crawler = OfflineTileArchive(options);
    _enhancedCrawler = crawler;
    await _executeDownload(crawler, 'NetGIS Plan1000');
  }

  Future<void> _startLegacyDownload(String basePath, TestConfig config) async {
    final options = DownloadOptions(
      topLeftLatLng: [39.898931, 32.701024],
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: 10,
      maxZoomLevel: 11,
      tileUrlFormat: config.urlTemplate,
      downloadFolder: '$basePath/legacy',
    );

    final crawler = TileCrawler(options);
    _legacyCrawler = crawler;

    final summary = await crawler.getSummary();
    setState(() {
      _areaKm2 = options.area;
      _currentStrategy = 'Concurrent HTTP';
    });

    await crawler.download(
      onStart: _onStart,
      onProcess: _onProcess,
      onEnd: _onEnd,
      onProcessError: _onError,
    );
  }

  Future<void> _executeDownload(
    OfflineTileArchive crawler,
    String type,
  ) async {
    final summary = await crawler.getSummary();
    setState(() {
      _areaKm2 = summary.area;
      _currentStrategy = 'Concurrent HTTP';
    });

    await crawler.download(
      onStart: _onStart,
      onProcess: _onProcess,
      onEnd: _onEnd,
      onProcessError: _onError,
    );
  }

  void _onStart(int totalTileCount, int remainingTileCount, double area) {
    setState(() {
      _isDownloading = true;
      _totalTileCount = totalTileCount;
      _remainingTiles = remainingTileCount;
      _skippedTiles = totalTileCount - remainingTileCount;
      _areaKm2 = area;
    });

    _progressController.forward();
    _statsController.forward();

    log('📈 ${_testConfigs[_testMode]!.name} download started:');
    log('   Total tiles: $totalTileCount');
    log('   To download: $remainingTileCount');
    log('   Already cached: $_skippedTiles');
    log('   Area: ${area.toStringAsFixed(2)} km²');
  }

  void _onProcess(int tilesDownloaded, int remainingTiles, XYZ xyz) {
    setState(() {
      _tilesDownloaded = tilesDownloaded;
      _remainingTiles = remainingTiles;
      _currentTileInfo = 'Tile: ${xyz.z}/${xyz.x}/${xyz.y}';
    });
  }

  void _onError(XYZ xyz, Object error, StackTrace stackTrace) {
    setState(() {
      _errorCount++;
    });
    log('❌ Error downloading tile ${xyz.toString()}: $error');
  }

  void _onEnd(int totalDownloaded, int totalSkipped) {
    _stopSpeedTracking();
    final duration = DateTime.now().difference(_startTime!);
    final avgSpeed = totalDownloaded > 0
        ? totalDownloaded / duration.inSeconds.toDouble()
        : 0.0;

    setState(() {
      _isDownloading = false;
      _tilesDownloaded = totalDownloaded;
      _skippedTiles = totalSkipped;
    });

    log("✅ ${_testConfigs[_testMode]!.name} download completed!");
    log("   Duration: ${duration.inMilliseconds}ms");
    log("   Downloaded: $totalDownloaded tiles");
    log("   Skipped (cached): $totalSkipped tiles");
    log("   Errors: $_errorCount");
    log("   Avg speed: ${avgSpeed.toStringAsFixed(2)} tiles/sec");

    _showCompletionDialog(duration, avgSpeed, totalDownloaded, totalSkipped);
  }

  void _cancelDownload() {
    if (_isDownloading) {
      _legacyCrawler?.cancel();
      _enhancedCrawler?.cancel();
      setState(() {
        _isDownloading = false;
      });
      _stopSpeedTracking();
      log('🛑 Download cancelled by user');
    }
  }

  void _showCompletionDialog(
    Duration duration,
    double avgSpeed,
    int downloaded,
    int skipped,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Download Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Test: ${_testConfigs[_testMode]!.name}'),
            SizedBox(height: 8),
            Text('Duration: ${duration.inSeconds}s'),
            Text('Downloaded: $downloaded tiles'),
            Text('Skipped: $skipped tiles'),
            Text('Errors: $_errorCount'),
            Text('Avg Speed: ${avgSpeed.toStringAsFixed(2)} tiles/sec'),
            Text('Strategy: $_currentStrategy'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Download Error'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tile Crawler Test'),
        backgroundColor: _testConfigs[_testMode]!.color,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTestModeSelector(),
            SizedBox(height: 20),
            _buildTestInfo(),
            SizedBox(height: 20),
            _buildProgressSection(),
            SizedBox(height: 20),
            _buildStatsSection(),
            SizedBox(height: 20),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTestModeSelector() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Test Mode',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: TestMode.values.map((mode) {
                final config = _testConfigs[mode]!;
                final isSelected = _testMode == mode;

                return FilterChip(
                  selected: isSelected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(config.icon, size: 16),
                      SizedBox(width: 4),
                      Text(config.name),
                    ],
                  ),
                  onSelected: _isDownloading
                      ? null
                      : (selected) {
                          if (selected) {
                            setState(() {
                              _testMode = mode;
                            });
                          }
                        },
                  selectedColor: config.color.withOpacity(0.3),
                  checkmarkColor: config.color,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestInfo() {
    final config = _testConfigs[_testMode]!;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(config.icon, color: config.color),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    config.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: config.color,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              config.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                config.urlTemplate,
                style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final progress = _totalTileCount > 0
        ? (_tilesDownloaded + _skippedTiles) / _totalTileCount
        : 0.0;

    return AnimatedBuilder(
      animation: _progressController,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Download Progress',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation(
                  _testConfigs[_testMode]!.color,
                ),
              ),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(progress * 100).toStringAsFixed(1)}%'),
                  Text(
                    '${_tilesDownloaded + _skippedTiles}/${_totalTileCount}',
                  ),
                ],
              ),
              if (_currentTileInfo.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  _currentTileInfo,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.scale(
          scale: 0.95 + (0.05 * _progressController.value),
          child: child,
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return AnimatedBuilder(
      animation: _statsController,
      child: Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statistics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Downloaded',
                      _tilesDownloaded.toString(),
                      Icons.download_done,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Remaining',
                      _remainingTiles.toString(),
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Skipped',
                      _skippedTiles.toString(),
                      Icons.skip_next,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Errors',
                      _errorCount.toString(),
                      Icons.error,
                      Colors.red,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      'Speed',
                      '${_downloadSpeed.toStringAsFixed(1)} t/s',
                      Icons.speed,
                      Colors.purple,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      'Strategy',
                      _currentStrategy,
                      Icons.settings,
                      Colors.indigo,
                    ),
                  ),
                ],
              ),
              if (_areaKm2 > 0) ...[
                SizedBox(height: 12),
                _buildStatItem(
                  'Area',
                  '${_areaKm2.toStringAsFixed(2)} km²',
                  Icons.area_chart,
                  Colors.teal,
                ),
              ],
            ],
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _statsController.value)),
          child: Opacity(opacity: _statsController.value, child: child),
        );
      },
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isDownloading ? null : _startDownload,
            icon: Icon(_isDownloading ? Icons.downloading : Icons.play_arrow),
            label: Text(_isDownloading ? 'Downloading...' : 'Start Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _testConfigs[_testMode]!.color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ),
        SizedBox(height: 12),
        if (_isDownloading)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _cancelDownload,
              icon: Icon(Icons.stop),
              label: Text('Cancel Download'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

enum TestMode {
  xyz,
  wmtsRestful,
  wmtsKvp,
  customWmts,
  netgisPlan1000,
  backwardCompatibility,
}

class TestConfig {
  final String name;
  final String description;
  final String urlTemplate;
  final Color color;
  final IconData icon;

  TestConfig({
    required this.name,
    required this.description,
    required this.urlTemplate,
    required this.color,
    required this.icon,
  });
}
