import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:ol_map/ol_map.dart';
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

  final OlMapController _mapController = OlMapController();

  LocalTileHttpServer? _httpServer;
  String? _downloadRoot;

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
              child: OlMapView(
            controller: _mapController,
            onMapReady: () async {
              _mapController.layer.add(OlMapLayer.osm());
              var dir = await getApplicationDocumentsDirectory();
              var tileServer = LocalTileHttpServer(
                  downloadRoot: '${dir.path}/wmts_tiles', serveWmtsKvp: true);
              await tileServer.start();
              _mapController.layer.add(OlMapLayer.wmts(
                id: 'id',
                name: 'name',
                layerIdentifier: 'layerIdentifier',
                matrixSetId: 'matrixSetId',
                tileUrl: tileServer.baseUrl,
                isVisible: true,
                opacity: 1.0,
                requestEncoding: 'KVP',
              ));
            },
          )),
        ],
      ),
    );
  }
}
