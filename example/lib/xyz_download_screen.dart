import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';

class XYZDownloadScreen extends StatefulWidget {
  const XYZDownloadScreen({Key? key}) : super(key: key);

  @override
  State<XYZDownloadScreen> createState() => _XYZDownloadScreenState();
}

class _XYZDownloadScreenState extends State<XYZDownloadScreen>
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
  double _areaKm2 = 0.0;

  // Crawler
  EnhancedTileCrawler? _crawler;
  bool _isDownloading = false;

  // Performance tracking
  DateTime? _startTime;
  Timer? _speedTimer;

  // Animation controller
  late AnimationController _progressController;

  // Form controllers
  final _topLatController = TextEditingController(text: '39.898931');
  final _topLngController = TextEditingController(text: '32.701024');
  final _bottomLatController = TextEditingController(text: '39.845293');
  final _bottomLngController = TextEditingController(text: '32.803630');
  final _minZoomController = TextEditingController(text: '10');
  final _maxZoomController = TextEditingController(text: '12');

  // URL templates
  String _selectedProvider = 'OpenStreetMap';
  final Map<String, String> _urlTemplates = {
    'OpenStreetMap': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Google Satellite': 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
    'Google Terrain': 'https://mt1.google.com/vt/lyrs=t&x={x}&y={y}&z={z}',
    'Stamen Toner':
        'https://stamen-tiles.a.ssl.fastly.net/toner/{z}/{x}/{y}.png',
    'CartoDB Light':
        'https://cartodb-basemaps-a.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _speedTimer?.cancel();
    _topLatController.dispose();
    _topLngController.dispose();
    _bottomLatController.dispose();
    _bottomLngController.dispose();
    _minZoomController.dispose();
    _maxZoomController.dispose();
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
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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

    // Validate input
    if (!_validateInput()) return;

    _resetDownloadStats();
    _startTime = DateTime.now();
    _startSpeedTracking();

    var dir = await getApplicationDocumentsDirectory();

    try {
      final crawler = EnhancedTileCrawler.xyz(
        topLeftLatLng: [
          double.parse(_topLatController.text),
          double.parse(_topLngController.text),
        ],
        bottomRightLatLng: [
          double.parse(_bottomLatController.text),
          double.parse(_bottomLngController.text),
        ],
        minZoomLevel: int.parse(_minZoomController.text),
        maxZoomLevel: int.parse(_maxZoomController.text),
        tileUrlFormat: _urlTemplates[_selectedProvider]!,
        downloadFolder: '${dir.path}/xyz_tiles',
      );

      _crawler = crawler;

      final summary = await crawler.getSummary();
      setState(() {
        _areaKm2 = summary.area;
      });

      await crawler.download(
        onStart: _onStart,
        onProcess: _onProcess,
        onEnd: _onEnd,
        onProcessError: _onError,
      );
    } catch (e) {
      log('❌ Download failed: $e');
      _showErrorDialog(e.toString());
      setState(() {
        _isDownloading = false;
      });
    }
  }

  bool _validateInput() {
    try {
      final topLat = double.parse(_topLatController.text);
      final topLng = double.parse(_topLngController.text);
      final bottomLat = double.parse(_bottomLatController.text);
      final bottomLng = double.parse(_bottomLngController.text);
      final minZoom = int.parse(_minZoomController.text);
      final maxZoom = int.parse(_maxZoomController.text);

      if (topLat <= bottomLat || topLng >= bottomLng) {
        _showErrorDialog(
          'Geçersiz koordinatlar. Sol üst koordinat sağ alt koordinattan daha büyük olmalıdır.',
        );
        return false;
      }

      if (minZoom < 0 || maxZoom > 20 || minZoom > maxZoom) {
        _showErrorDialog(
          'Geçersiz zoom seviyesi. Min: 0, Max: 20, MinZoom <= MaxZoom',
        );
        return false;
      }

      return true;
    } catch (e) {
      _showErrorDialog('Geçersiz sayı formatı. Lütfen geçerli sayılar girin.');
      return false;
    }
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

    log('📈 XYZ download started:');
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

    log("✅ XYZ download completed!");
    log("   Duration: ${duration.inMilliseconds}ms");
    log("   Downloaded: $totalDownloaded tiles");
    log("   Skipped (cached): $totalSkipped tiles");
    log("   Errors: $_errorCount");
    log("   Avg speed: ${avgSpeed.toStringAsFixed(2)} tiles/sec");

    _showCompletionDialog(duration, avgSpeed, totalDownloaded, totalSkipped);
  }

  void _cancelDownload() {
    if (_isDownloading) {
      _crawler?.cancel();
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
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('İndirme Tamamlandı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sağlayıcı: $_selectedProvider'),
            const SizedBox(height: 8),
            Text('Süre: ${duration.inSeconds}s'),
            Text('İndirilen: $downloaded karolar'),
            Text('Atlanan: $skipped karolar'),
            Text('Hata: $_errorCount'),
            Text('Ortalama Hız: ${avgSpeed.toStringAsFixed(2)} karo/sn'),
            Text('Alan: ${_areaKm2.toStringAsFixed(2)} km²'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red),
            SizedBox(width: 8),
            Text('Hata'),
          ],
        ),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XYZ Tile İndirme'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildProviderSelector(),
            const SizedBox(height: 16),
            _buildCoordinateInputs(),
            const SizedBox(height: 16),
            _buildZoomInputs(),
            const SizedBox(height: 16),
            _buildProgressSection(),
            const SizedBox(height: 16),
            _buildStatsSection(),
            const SizedBox(height: 16),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Harita Sağlayıcısı',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _selectedProvider,
              isExpanded: true,
              items: _urlTemplates.keys.map((String provider) {
                return DropdownMenuItem<String>(
                  value: provider,
                  child: Text(provider),
                );
              }).toList(),
              onChanged: _isDownloading
                  ? null
                  : (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedProvider = newValue;
                        });
                      }
                    },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _urlTemplates[_selectedProvider]!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinateInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Koordinatlar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _topLatController,
                    decoration: const InputDecoration(
                      labelText: 'Sol Üst Enlem',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _topLngController,
                    decoration: const InputDecoration(
                      labelText: 'Sol Üst Boylam',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _bottomLatController,
                    decoration: const InputDecoration(
                      labelText: 'Sağ Alt Enlem',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _bottomLngController,
                    decoration: const InputDecoration(
                      labelText: 'Sağ Alt Boylam',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomInputs() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Zoom Seviyeleri',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minZoomController,
                    decoration: const InputDecoration(
                      labelText: 'Min Zoom',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxZoomController,
                    decoration: const InputDecoration(
                      labelText: 'Max Zoom',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    enabled: !_isDownloading,
                  ),
                ),
              ],
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İndirme İlerlemesi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(progress * 100).toStringAsFixed(1)}%'),
                Text('${_tilesDownloaded + _skippedTiles}/${_totalTileCount}'),
              ],
            ),
            if (_currentTileInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
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
    );
  }

  Widget _buildStatsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İstatistikler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'İndirilen',
                    _tilesDownloaded.toString(),
                    Icons.download_done,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Kalan',
                    _remainingTiles.toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Atlanan',
                    _skippedTiles.toString(),
                    Icons.skip_next,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Hata',
                    _errorCount.toString(),
                    Icons.error,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Hız',
                    '${_downloadSpeed.toStringAsFixed(1)} k/s',
                    Icons.speed,
                    Colors.purple,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Alan',
                    '${_areaKm2.toStringAsFixed(2)} km²',
                    Icons.area_chart,
                    Colors.teal,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
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
            label: Text(_isDownloading ? 'İndiriliyor...' : 'İndirmeyi Başlat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_isDownloading)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _cancelDownload,
              icon: const Icon(Icons.stop),
              label: const Text('İndirmeyi Durdur'),
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
