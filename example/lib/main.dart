import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tile Crawler Optimized Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Tile Crawler Optimized Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // Progress tracking
  int _totalTileCount = 0;
  int _tilesDownloaded = 0;
  int _remainingTiles = 0;
  int _errorCount = 0;
  int _skippedTiles = 0;

  // Current tile info
  int _currentX = 0;
  int _currentY = 0;
  int _currentZ = 0;

  // Performance metrics
  double _downloadSpeed = 0.0;
  String _currentStrategy = 'Auto';
  double _areaKm2 = 0.0;

  TileCrawler? _crawler;
  bool _isDownloading = false;

  // Performance tracking
  DateTime? _startTime;
  List<double> _speedHistory = [];
  Timer? _speedTimer;

  // Test scenarios - updated with more realistic expectations
  final List<TestScenario> _testScenarios = [
    TestScenario(
      name: 'Small Set (Connection Pool)',
      description: 'Tests optimized connection pooling for <300 tiles',
      minZoom: 15,
      maxZoom: 15,
      area: 'Small area around Ankara center',
      expectedTiles: '~50-100 tiles',
    ),
    TestScenario(
      name: 'Medium Set (Hybrid)',
      description: 'Tests strategy transition point around 300 tiles',
      minZoom: 15,
      maxZoom: 16,
      area: 'Medium area in Ankara',
      expectedTiles: '~200-400 tiles',
    ),
    TestScenario(
      name: 'Large Set (Isolates)',
      description: 'Tests optimized isolate management for >300 tiles',
      minZoom: 16,
      maxZoom: 17,
      area: 'Large area in Ankara',
      expectedTiles: '~800-1600 tiles',
    ),
    TestScenario(
      name: 'Cache Efficiency Test',
      description: 'Re-download same area to test cache performance',
      minZoom: 15,
      maxZoom: 15,
      area: 'Same as Small Set',
      expectedTiles: 'Should skip already downloaded',
    ),
    TestScenario(
      name: 'Multi-Level Test',
      description: 'Mixed zoom levels for comprehensive testing',
      minZoom: 14,
      maxZoom: 17,
      area: 'Multi-level progressive download',
      expectedTiles: 'Progressive zoom levels',
    ),
  ];

  int _selectedScenario = 0;

  void _startDownload() async {
    if (_isDownloading) return;

    _resetDownloadStats();
    _startTime = DateTime.now();
    _startSpeedTracking();

    var dir = await getApplicationDocumentsDirectory();
    final scenario = _testScenarios[_selectedScenario];

    final options = DownloadOptions(
      tileUrlFormat: MapProviders.googleHybrid,
      topLeftLatLng: [39.898931, 32.701024], // Ankara coordinates
      bottomRightLatLng: [39.845293, 32.803630],
      minZoomLevel: scenario.minZoom,
      maxZoomLevel: scenario.maxZoom,
      downloadFolder: '${dir.path}/tiles.',
    );

    _crawler = TileCrawler(options);

    // Get summary before starting
    final summary = await _crawler!.getSummary();
    log('🚀 Starting ${scenario.name}');
    log('📊 Download summary: ${summary.toString()}');
    log('💡 Strategy: ${summary.tileCount < 300 ? "Connection Pool" : "Isolates"}');

    setState(() {
      _areaKm2 = options.area;
      _currentStrategy =
          summary.tileCount < 300 ? "Connection Pool" : "Isolates";
    });

    _crawler!.download(
      onStart: (totalTileCount, remainingTileCount, area) {
        setState(() {
          _isDownloading = true;
          _totalTileCount = totalTileCount;
          _remainingTiles = remainingTileCount;
          _skippedTiles = totalTileCount - remainingTileCount;
          _areaKm2 = area;
        });

        log('📈 Download session started:');
        log('   Total tiles: $totalTileCount');
        log('   To download: $remainingTileCount');
        log('   Already cached: $_skippedTiles');
        log('   Area: ${area.toStringAsFixed(2)} km²');
        log('   Strategy: $_currentStrategy');
      },
      onProcess: (tilesDownloaded, remainingTiles, xyz) {
        setState(() {
          _tilesDownloaded = tilesDownloaded;
          _remainingTiles = remainingTiles;
          _currentX = xyz.x;
          _currentY = xyz.y;
          _currentZ = xyz.z;
        });

        // Calculate real-time download speed
        if (_startTime != null) {
          final elapsed = DateTime.now().difference(_startTime!).inSeconds;
          if (elapsed > 0) {
            _downloadSpeed = _tilesDownloaded / elapsed.toDouble();
          }
        }
      },
      onEnd: (totalDownloaded, totalSkipped) {
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

        log("✅ Download completed successfully!");
        log("   Duration: ${duration.inMilliseconds}ms");
        log("   Downloaded: $totalDownloaded tiles");
        log("   Skipped (cached): $totalSkipped tiles");
        log("   Errors: $_errorCount");
        log("   Avg speed: ${avgSpeed.toStringAsFixed(2)} tiles/sec");
        log("   Strategy used: $_currentStrategy");

        _showCompletionDialog(
            duration, avgSpeed, totalDownloaded, totalSkipped);
      },
      onProcessError: (xyz, error, stackTrace) {
        setState(() {
          _errorCount++;
          _remainingTiles--;
        });
        log('❌ Error downloading tile $xyz: $error');
      },
    );
  }

  void _resetDownloadStats() {
    setState(() {
      _isDownloading = false;
      _totalTileCount = 0;
      _tilesDownloaded = 0;
      _remainingTiles = 0;
      _errorCount = 0;
      _skippedTiles = 0;
      _downloadSpeed = 0.0;
      _speedHistory.clear();
      _currentX = 0;
      _currentY = 0;
      _currentZ = 0;
    });
  }

  void _startSpeedTracking() {
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && _isDownloading && _tilesDownloaded > 0) {
        final elapsed = DateTime.now().difference(_startTime!).inSeconds;
        if (elapsed > 0) {
          final currentSpeed = _tilesDownloaded / elapsed.toDouble();
          setState(() {
            _downloadSpeed = currentSpeed;
          });
          _speedHistory.add(currentSpeed);
        }
      }
    });
  }

  void _stopSpeedTracking() {
    _speedTimer?.cancel();
    _speedTimer = null;
  }

  void _showCompletionDialog(
      Duration duration, double avgSpeed, int downloaded, int skipped) {
    final scenario = _testScenarios[_selectedScenario];
    final efficiency = _totalTileCount > 0
        ? (downloaded / _totalTileCount.toDouble() * 100)
        : 0.0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${scenario.name} Completed! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⏱️ Duration: ${duration.inSeconds}s'),
            Text('🚀 Avg Speed: ${avgSpeed.toStringAsFixed(2)} tiles/sec'),
            Text('📥 Downloaded: $downloaded tiles'),
            Text('💾 Cached (skipped): $skipped tiles'),
            Text('⚠️ Errors: $_errorCount'),
            Text('🎯 Efficiency: ${efficiency.toStringAsFixed(1)}%'),
            Text('🔧 Strategy: $_currentStrategy'),
            Text('📍 Area: ${_areaKm2.toStringAsFixed(2)} km²'),
            const SizedBox(height: 10),
            Text('💡 ${_getOptimizationTip()}',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _getOptimizationTip() {
    if (_skippedTiles > _tilesDownloaded) {
      return 'Great caching! Most tiles were already available.';
    } else if (_currentStrategy == 'Connection Pool') {
      return 'Connection pooling used for optimal UI responsiveness.';
    } else {
      return 'Isolates used for maximum parallel processing power.';
    }
  }

  void _cancelDownload() {
    _crawler?.cancel();
    _stopSpeedTracking();
    setState(() {
      _isDownloading = false;
    });
    log('🛑 Download cancelled by user');
  }

  Widget _buildScenarioSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🧪 Test Scenarios',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            DropdownButton<int>(
              isExpanded: true,
              value: _selectedScenario,
              items: _testScenarios.asMap().entries.map((entry) {
                final scenario = entry.value;
                return DropdownMenuItem<int>(
                  value: entry.key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scenario.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(scenario.description,
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _isDownloading
                  ? null
                  : (value) {
                      setState(() {
                        _selectedScenario = value!;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Text(_testScenarios[_selectedScenario].expectedTiles,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📊 Detailed Progress',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            // Main stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Total', '$_totalTileCount', Colors.blue),
                _buildStatItem('Downloaded', '$_tilesDownloaded', Colors.green),
                _buildStatItem('Cached', '$_skippedTiles', Colors.orange),
                _buildStatItem('Errors', '$_errorCount', Colors.red),
              ],
            ),

            const SizedBox(height: 15),

            // Progress info
            if (_isDownloading) ...[
              Text('🚀 Speed: ${_downloadSpeed.toStringAsFixed(2)} tiles/sec'),
              Text('🔧 Strategy: $_currentStrategy'),
              Text('📍 Current: z:$_currentZ, x:$_currentX, y:$_currentY'),
              Text('⏳ Remaining: $_remainingTiles tiles'),
              const SizedBox(height: 10),

              // Progress bar
              LinearProgressIndicator(
                value: _totalTileCount > 0
                    ? (_tilesDownloaded + _skippedTiles) /
                        _totalTileCount.toDouble()
                    : 0.0,
                backgroundColor: Colors.grey[300],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 5),
              Text(
                  '${_totalTileCount > 0 ? (((_tilesDownloaded + _skippedTiles) / _totalTileCount.toDouble()) * 100).toStringAsFixed(1) : 0}% complete'),
            ] else if (_totalTileCount > 0) ...[
              // Completed stats
              Text('✅ Session completed'),
              Text('📍 Area: ${_areaKm2.toStringAsFixed(2)} km²'),
              Text(
                  '🎯 Success rate: ${_totalTileCount > 0 ? (((_tilesDownloaded + _skippedTiles) / _totalTileCount.toDouble()) * 100).toStringAsFixed(1) : 0}%'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildOptimizationInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚡ Active Optimizations',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.speed, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Smart strategy: Connection pool <300 tiles, Isolates >300')),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.cached, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Intelligent caching (skips existing tiles automatically)')),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.assessment, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Real-time progress tracking with accurate counts')),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.memory, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Optimized resource management & concurrency')),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.autorenew, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text('Progressive retry with exponential backoff')),
              ],
            ),
            const SizedBox(height: 5),
            const Row(
              children: [
                Icon(Icons.verified, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'File validation (prevents corrupted/empty files)')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopSpeedTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildScenarioSelector(),
            const SizedBox(height: 16),
            _buildDetailedStatsCard(),
            const SizedBox(height: 16),
            _buildOptimizationInfo(),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_isDownloading)
            FloatingActionButton(
              onPressed: _cancelDownload,
              backgroundColor: Colors.red,
              heroTag: "cancel",
              child: const Icon(Icons.cancel, color: Colors.white),
            )
          else
            const SizedBox(width: 56), // Placeholder for spacing
          FloatingActionButton.extended(
            onPressed: _isDownloading ? null : _startDownload,
            backgroundColor: _isDownloading ? Colors.grey : Colors.blue,
            heroTag: "download",
            icon: Icon(
                _isDownloading ? Icons.hourglass_empty : Icons.rocket_launch,
                color: Colors.white),
            label: Text(_isDownloading ? 'Downloading...' : 'Start Test',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class TestScenario {
  final String name;
  final String description;
  final int minZoom;
  final int maxZoom;
  final String area;
  final String expectedTiles;

  TestScenario({
    required this.name,
    required this.description,
    required this.minZoom,
    required this.maxZoom,
    required this.area,
    required this.expectedTiles,
  });
}
