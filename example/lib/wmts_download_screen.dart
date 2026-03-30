import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';

class WMTSDownloadScreen extends StatefulWidget {
  const WMTSDownloadScreen({Key? key}) : super(key: key);

  @override
  State<WMTSDownloadScreen> createState() => _WMTSDownloadScreenState();
}

class _WMTSDownloadScreenState extends State<WMTSDownloadScreen>
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
  OfflineTileArchive? _crawler;
  bool _isDownloading = false;

  // Performance tracking
  DateTime? _startTime;
  Timer? _speedTimer;

  // Animation controller
  late AnimationController _progressController;

  // Form controllers
  final _topLatController = TextEditingController(text: '36.55285449444367');
  final _topLngController = TextEditingController(text: '31.9897278454153');
  final _bottomLatController = TextEditingController(text: '36.54332068153187');
  final _bottomLngController =
      TextEditingController(text: '31.998578896372305');
  final _minZoomController = TextEditingController(text: '6');
  final _maxZoomController = TextEditingController(text: '10');

  // WMTS specific controllers
  final _urlController = TextEditingController(
    text:
        'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/tile/1.0.0/World_Imagery/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg',
  );
  final _layerController = TextEditingController(text: 'World_Imagery');
  final _styleController = TextEditingController(text: 'default');
  final _tileMatrixSetController = TextEditingController(
    text: 'GoogleMapsCompatible',
  );
  final _formatController = TextEditingController(text: 'jpg');

  // Service type
  bool _useRestful = true;
  String _selectedService = 'ArcGIS World Imagery';

  // Predefined WMTS services
  final Map<String, WMTSServiceConfig> _predefinedServices = {
    'ArcGIS World Imagery': WMTSServiceConfig(
      name: 'ArcGIS World Imagery',
      url:
          'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/tile/1.0.0/World_Imagery/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg',
      layer: 'World_Imagery',
      style: 'default',
      tileMatrixSet: 'GoogleMapsCompatible',
      format: 'jpg',
      useRestful: true,
    ),
    'Netherlands BGT': WMTSServiceConfig(
      name: 'Netherlands BGT',
      url: 'https://geodata.nationaalgeoregister.nl/wmts',
      layer: 'brtachtergrondkaart',
      style: 'default',
      tileMatrixSet: 'EPSG:3857',
      format: 'png',
      useRestful: false,
    ),
    'NetGIS Plan1000': WMTSServiceConfig(
      name: 'NetGIS Plan1000',
      url:
          'https://ssltest.netcad.com.tr/netgisnew/wmts.ashx?NCWS=ALANYA_BELNETMAP6',
      layer: 'HALIHAZIRTUM_ITRF',
      style: 'default',
      tileMatrixSet: 'HALIHAZIRTUM_ITRF_7933',
      format: 'png',
      useRestful: false,
    ),
    'Custom WMTS': WMTSServiceConfig(
      name: 'Custom WMTS',
      url:
          'https://ssltest.netcad.com.tr/netgisnew/wmts.ashx?NCWS=ALANYA_BELNETMAP6',
      layer: 'HALIHAZIRTUM_ITRF',
      style: 'default',
      tileMatrixSet: 'HALIHAZIRTUM_ITRF_7933',
      format: 'png',
      useRestful: true,
    ),
  };

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _updateServiceConfig();
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
    _urlController.dispose();
    _layerController.dispose();
    _styleController.dispose();
    _tileMatrixSetController.dispose();
    _formatController.dispose();
    super.dispose();
  }

  void _updateServiceConfig() {
    final config = _predefinedServices[_selectedService]!;
    _urlController.text = config.url;
    _layerController.text = config.layer;
    _styleController.text = config.style;
    _tileMatrixSetController.text = config.tileMatrixSet;
    _formatController.text = config.format;
    _useRestful = config.useRestful;
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
      late OfflineTileArchive crawler;

      if (_useRestful) {
        // RESTful WMTS
        crawler = OfflineTileArchive.wmts(
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
          urlTemplate: _urlController.text,
          layer: _layerController.text,
          style: _styleController.text,
          tileMatrixSet: _tileMatrixSetController.text,
          format: _formatController.text,
          useRestful: true,
          downloadFolder: '${dir.path}/wmts_tiles',
        );
      } else {
        // KVP WMTS
        final provider = TileProviderFactory.createWMTSProvider(
          urlTemplate: _urlController.text,
          layer: _layerController.text,
          style: _styleController.text,
          tileMatrixSet: _tileMatrixSetController.text,
          format: _formatController.text,
          useRestful: false,
        );

        final options = EnhancedDownloadOptions(
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
          tileProvider: provider,
          downloadFolder: '${dir.path}/wmts_tiles',
        );

        crawler = OfflineTileArchive(options);
      }

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

      if (_urlController.text.isEmpty || _layerController.text.isEmpty) {
        _showErrorDialog('URL ve Layer alanları boş olamaz.');
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

    log('📈 WMTS download started:');
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

    log("✅ WMTS download completed!");
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
            Text('Servis: $_selectedService'),
            Text('Tip: ${_useRestful ? "RESTful" : "KVP"}'),
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
        title: const Text('WMTS Tile İndirme'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildServiceSelector(),
            const SizedBox(height: 16),
            _buildWMTSConfiguration(),
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

  Widget _buildServiceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WMTS Servisi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _selectedService,
              isExpanded: true,
              items: _predefinedServices.keys.map((String service) {
                return DropdownMenuItem<String>(
                  value: service,
                  child: Text(service),
                );
              }).toList(),
              onChanged: _isDownloading
                  ? null
                  : (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedService = newValue;
                          _updateServiceConfig();
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWMTSConfiguration() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'WMTS Konfigürasyonu',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Service type
            Row(
              children: [
                const Text('Servis Tipi: '),
                Switch(
                  value: _useRestful,
                  onChanged: _isDownloading
                      ? null
                      : (bool value) {
                          setState(() {
                            _useRestful = value;
                          });
                        },
                ),
                Text(_useRestful ? 'RESTful' : 'KVP'),
              ],
            ),
            const SizedBox(height: 16),

            // URL
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'WMTS URL',
                border: OutlineInputBorder(),
              ),
              enabled: !_isDownloading,
              maxLines: 2,
            ),
            const SizedBox(height: 12),

            // Layer and Style
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _layerController,
                    decoration: const InputDecoration(
                      labelText: 'Layer',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isDownloading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _styleController,
                    decoration: const InputDecoration(
                      labelText: 'Style',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isDownloading,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // TileMatrixSet and Format
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tileMatrixSetController,
                    decoration: const InputDecoration(
                      labelText: 'TileMatrixSet',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !_isDownloading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _formatController,
                    decoration: const InputDecoration(
                      labelText: 'Format',
                      border: OutlineInputBorder(),
                    ),
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
              valueColor: const AlwaysStoppedAnimation(Colors.orange),
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
              backgroundColor: Colors.orange,
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

class WMTSServiceConfig {
  final String name;
  final String url;
  final String layer;
  final String style;
  final String tileMatrixSet;
  final String format;
  final bool useRestful;

  WMTSServiceConfig({
    required this.name,
    required this.url,
    required this.layer,
    required this.style,
    required this.tileMatrixSet,
    required this.format,
    required this.useRestful,
  });
}
