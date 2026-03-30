import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';
import 'package:tile_crawler_server/tile_crawler_server.dart';

/// flutter_map + [OfflineTileArchive] indirme, sonra [LocalTileHttpServer] ile
/// çevrimdışı katman.
class FlutterMapOfflineScreen extends StatefulWidget {
  const FlutterMapOfflineScreen({super.key});

  @override
  State<FlutterMapOfflineScreen> createState() =>
      _FlutterMapOfflineScreenState();
}

class _FlutterMapOfflineScreenState extends State<FlutterMapOfflineScreen> {
  static const _osmUrl = MapProviders.openStreetMap;
  static const _userAgent = 'dev.flutter.example.tile_crawler';

  final MapController _mapController = MapController();

  LocalTileHttpServer? _httpServer;
  String? _downloadRoot;
  String _offlineUrlTemplate = '';

  bool _mapReady = false;
  bool _downloading = false;
  bool _useOffline = false;
  bool _hasOfflineTiles = false;

  String _status = 'Haritayı kaydırın, sonra görünür alanı indirin.';

  @override
  void dispose() {
    _mapController.dispose();
    unawaited(_stopServer());
    super.dispose();
  }

  Future<void> _stopServer() async {
    await _httpServer?.close();
    _httpServer = null;
  }

  Future<void> _ensureDownloadDir() async {
    final dir = await getApplicationDocumentsDirectory();
    _downloadRoot = '${dir.path}/flutter_map_offline_demo';
    await Directory(_downloadRoot!).create(recursive: true);
  }

  Future<void> _downloadVisibleArea() async {
    if (_downloading || !_mapReady) {
      return;
    }
    setState(() {
      _downloading = true;
      _status = 'İndiriliyor…';
    });
    try {
      await _ensureDownloadDir();
      final bounds = _mapController.camera.visibleBounds;
      final archive = OfflineTileArchive.xyz(
        topLeftLatLng: [bounds.north, bounds.west],
        bottomRightLatLng: [bounds.south, bounds.east],
        minZoomLevel: 14,
        maxZoomLevel: 17,
        tileUrlFormat: _osmUrl,
        downloadFolder: _downloadRoot!,
      );

      await archive.download(
        onStart: (total, remaining, areaKm2) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'Kuyruk: $total karo, ~${areaKm2.toStringAsFixed(1)} km²';
          });
        },
        onProcess: (downloaded, remaining, xyz) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'İndirilen: $downloaded, kalan: $remaining  '
                '(z=${xyz.z})';
          });
        },
        onEnd: (totalDownloaded, totalSkipped) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status =
                'Bitti: $totalDownloaded indirildi, $totalSkipped atlandı.';
          });
        },
        onProcessError: (xyz, error, stackTrace) {
          if (!mounted) {
            return;
          }
          setState(() {
            _status = 'Hata z=${xyz.z}: $error';
          });
        },
      );

      await _stopServer();
      final server = LocalTileHttpServer(downloadRoot: _downloadRoot!);
      await server.start(port: 0);
      _httpServer = server;
      if (!mounted) {
        await server.close();
        return;
      }
      setState(() {
        _offlineUrlTemplate = server.urlTemplate(fileExtension: 'png');
        _hasOfflineTiles = true;
        _useOffline = true;
        _status =
            'Çevrimdışı hazır. Yerel: ${server.baseUrl} (Wi‑Fi kapalı test edin).';
      });
    } catch (e, st) {
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          _status = 'İndirme hatası: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme başarısız: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }

  Future<void> _onOfflineToggled(bool value) async {
    if (value && !_hasOfflineTiles) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce görünür alanı indirin (yerel sunucu gerekir).'),
        ),
      );
      return;
    }
    if (!value) {
      await _stopServer();
      if (mounted) {
        setState(() {
          _useOffline = false;
        });
      }
      return;
    }
    if (_httpServer == null && _downloadRoot != null) {
      final server = LocalTileHttpServer(downloadRoot: _downloadRoot!);
      await server.start(port: 0);
      _httpServer = server;
      _offlineUrlTemplate = server.urlTemplate(fileExtension: 'png');
    }
    if (mounted) {
      setState(() {
        _useOffline = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = LatLng(39.92, 32.86);

    return Scaffold(
      appBar: AppBar(
        title: const Text('flutter_map — çevrimiçi / çevrimdışı'),
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: initial,
                initialZoom: 11,
                minZoom: 3,
                maxZoom: 19,
                onMapReady: () {
                  setState(() {
                    _mapReady = true;
                  });
                },
              ),
              children: [
                TileLayer(
                  key: ValueKey<String>(
                    _useOffline && _hasOfflineTiles
                        ? _offlineUrlTemplate
                        : _osmUrl,
                  ),
                  urlTemplate: _useOffline && _hasOfflineTiles
                      ? _offlineUrlTemplate
                      : _osmUrl,
                  userAgentPackageName: _userAgent,
                ),
                SimpleAttributionWidget(
                  source: const Text('OpenStreetMap contributors'),
                ),
              ],
            ),
          ),
          Material(
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_downloading) const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Çevrimdışı (yerel HTTP)'),
                      subtitle: const Text(
                        'İndirilen karoları tile_crawler_server ile sunar',
                      ),
                      value: _useOffline,
                      onChanged: _downloading
                          ? null
                          : (v) {
                              unawaited(_onOfflineToggled(v));
                            },
                    ),
                    FilledButton.icon(
                      onPressed: _downloading || !_mapReady
                          ? null
                          : _downloadVisibleArea,
                      icon: _downloading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: const Text('Görünür alanı indir (zoom 10–12)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
