// ignore_for_file: prefer_const_constructors, unused_local_variable
import 'package:tile_crawler/tile_crawler.dart';

void main() async {
  // Example usage of the enhanced tile crawler system
  await xyzTileExample();
  await wmtsTileExample();
  await customWmtsExample();
  await netgisPlan1000Example();
  await backwardCompatibilityExample();
  await factoryPatternExample();
}

/// Example: Using XYZ tiles with the enhanced system
Future<void> xyzTileExample() async {
  print('\n=== XYZ Tile Download Example ===');
  
  // Create XYZ tile crawler using the enhanced system
  final crawler = EnhancedTileCrawler.xyz(
    topLeftLatLng: [39.0, 28.0],      // Istanbul top-left
    bottomRightLatLng: [40.0, 29.0],  // Istanbul bottom-right
    minZoomLevel: 10,
    maxZoomLevel: 12,
    tileUrlFormat: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    downloadFolder: './downloads/xyz_tiles',
  );

  // Get summary before starting
  final summary = await crawler.getSummary();
  print('Total tiles to download: ${summary.tileCount}');
  print('Area coverage: ${summary.area.toStringAsFixed(2)} km²');

  // Start download with progress tracking
  try {
    await crawler.download(
      onStart: (totalTiles, remainingTiles, area) {
        print('Starting download: $totalTiles tiles, ${area.toStringAsFixed(2)} km²');
      },
      onProcess: (downloaded, remaining, xyz) {
        if (downloaded % 100 == 0) {
          print('Progress: $downloaded downloaded, $remaining remaining');
        }
      },
      onEnd: (totalDownloaded, totalSkipped) {
        print('Download completed: $totalDownloaded downloaded, $totalSkipped skipped');
      },
      onProcessError: (xyz, error, stackTrace) {
        print('Error downloading tile ${xyz.toString()}: $error');
      },
    );
  } catch (e) {
    print('Download failed: $e');
  }
}

/// Example: Using WMTS tiles with the enhanced system
Future<void> wmtsTileExample() async {
  print('\n=== WMTS Tile Download Example ===');

  // Create WMTS tile crawler
  final crawler = EnhancedTileCrawler.wmts(
    topLeftLatLng: [39.0, 28.0],      // Istanbul top-left
    bottomRightLatLng: [40.0, 29.0],  // Istanbul bottom-right
    minZoomLevel: 10,
    maxZoomLevel: 12,
    urlTemplate: 'https://services.arcgisonline.com/arcgis/rest/services/World_Imagery/MapServer/WMTS/tile/1.0.0/World_Imagery/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.jpg',
    layer: 'World_Imagery',
    style: 'default',
    tileMatrixSet: 'GoogleMapsCompatible',
    format: 'jpg',
    useRestful: true,
    downloadFolder: './downloads/wmts_tiles',
  );

  // Get summary
  final summary = await crawler.getSummary();
  print('WMTS tiles to download: ${summary.tileCount}');

  // Start download
  try {
    await crawler.download(
      onStart: (totalTiles, remainingTiles, area) {
        print('Starting WMTS download: $totalTiles tiles');
      },
      onProcess: (downloaded, remaining, xyz) {
        if (downloaded % 50 == 0) {
          final total = downloaded + remaining;
          print('WMTS Progress: $downloaded/$total tiles');
        }
      },
      onEnd: (totalDownloaded, totalSkipped) {
        print('WMTS download completed: $totalDownloaded downloaded');
      },
    );
  } catch (e) {
    print('WMTS download failed: $e');
  }
}

/// Example: Using Custom WMTS with authentication and custom projections
Future<void> customWmtsExample() async {
  print('\n=== Custom WMTS with Authentication Example ===');

  // Create a custom WMTS provider with Turkish Land Registry configuration
  final provider = CustomWMTSProviders.createWithAuth(
    baseUrl: 'https://your-wmts-server.com/wmts',
    sid: 'your_session_id_here',
    layer: 'Plan1000',
    style: 'default',
    tileMatrixSet: 'Plan1000_7933',
    format: 'png',
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
      15.258773803710938,
      7.629386901855469,
      3.8146934509277344,
      1.9073467254638672,
      0.9536733627319336,
      0.4768366813659668,
      0.2384183406829834,
      0.1192091703414917,
    ],
    originX: -180,
    originY: 31999878,
    customParams: 'NCWS=wmtstest',
    name: 'Turkish Land Registry WMTS',
  );

  // Create enhanced options with custom provider
  final options = EnhancedDownloadOptions(
    topLeftLatLng: [39.0, 28.0],      // Istanbul area
    bottomRightLatLng: [39.1, 28.1],  // Small area for demo
    minZoomLevel: 5,
    maxZoomLevel: 7,
    tileProvider: provider,
    downloadFolder: './downloads/custom_wmts',
  );

  final crawler = EnhancedTileCrawler(options);

  // Get summary
  final summary = await crawler.getSummary();
  print('Custom WMTS tiles to download: ${summary.tileCount}');
  print('Provider name: ${provider.name}');
  print('Provider validation: ${provider.isValid}');

  // Start download
  try {
    await crawler.download(
      onStart: (totalTiles, remainingTiles, area) {
        print('Starting Custom WMTS download: $totalTiles tiles');
        print('Area: ${area.toStringAsFixed(2)} km²');
      },
      onProcess: (downloaded, remaining, xyz) {
        if (downloaded % 10 == 0) {
          print('Custom WMTS Progress: $downloaded tiles downloaded');
        }
      },
      onEnd: (totalDownloaded, totalSkipped) {
        print('Custom WMTS download completed:');
        print('  Downloaded: $totalDownloaded tiles');
        print('  Skipped: $totalSkipped tiles');
        print('  Authentication: SID-based');
        print('  Projection: Custom EPSG:7933');
        print('  Custom params: NCWS=wmtstest');
      },
      onProcessError: (xyz, error, stackTrace) {
        print('Custom WMTS Error: ${xyz.toString()} - $error');
      },
    );
  } catch (e) {
    print('Custom WMTS download failed: $e');
  }
}

/// Example: Using NetGIS Plan1000 - Real WMTS server test
Future<void> netgisPlan1000Example() async {
  print('\n=== NetGIS Plan1000 Real Server Example ===');

  // Use predefined NetGIS Plan1000 provider
  final provider = CustomWMTSProviders.netgisPlan1000;

  // Create enhanced options with NetGIS provider
  final options = EnhancedDownloadOptions(
    topLeftLatLng: [39.898931, 32.701024], // Ankara coordinates
    bottomRightLatLng: [39.845293, 32.803630],
    minZoomLevel: 10,
    maxZoomLevel: 12,
    tileProvider: provider,
    downloadFolder: './downloads/netgis_plan1000',
  );

  final crawler = EnhancedTileCrawler(options);

  // Get summary
  final summary = await crawler.getSummary();
  print('NetGIS Plan1000 tiles to download: ${summary.tileCount}');
  print('Provider name: ${provider.name}');
  print('Base URL: ${provider.urlTemplate}');
  print('Layer: Plan1000');
  print('Matrix Set: Plan1000_7933');
  print('Projection: EPSG:7933');
  print('Custom params: NCWS=WMTSTEST2');

  // Start download
  try {
    await crawler.download(
      onStart: (totalTiles, remainingTiles, area) {
        print('Starting NetGIS Plan1000 download: $totalTiles tiles');
        print('Area: ${area.toStringAsFixed(2)} km²');
        print('This is a REAL server test!');
      },
      onProcess: (downloaded, remaining, xyz) {
        if (downloaded % 25 == 0) {
          print('NetGIS Progress: $downloaded tiles downloaded');
          print('  Current tile: ${xyz.toString()}');
        }
      },
      onEnd: (totalDownloaded, totalSkipped) {
        print('NetGIS Plan1000 download completed:');
        print('  Downloaded: $totalDownloaded tiles');
        print('  Skipped: $totalSkipped tiles');
        print('  Server: NetCAD NetGIS');
        print('  Layer: Plan1000 (Turkish cadastral data)');
        print('  Status: Real production server test successful!');
      },
      onProcessError: (xyz, error, stackTrace) {
        print('NetGIS Error: ${xyz.toString()} - $error');
      },
    );
  } catch (e) {
    print('NetGIS Plan1000 download failed: $e');
    print('Note: This might be due to server availability or network issues.');
  }
}

/// Example: Backward compatibility with original TileCrawler
Future<void> backwardCompatibilityExample() async {
  print('\n=== Backward Compatibility Example ===');

  // This still works exactly as before
  final options = DownloadOptions(
    topLeftLatLng: [39.0, 28.0],
    bottomRightLatLng: [40.0, 29.0],
    minZoomLevel: 10,
    maxZoomLevel: 11,
    tileUrlFormat: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    downloadFolder: './downloads/backward_compat',
  );

  final crawler = TileCrawler(options);
  
  try {
    await crawler.download(
      onStart: (total, remaining, area) {
        print('Legacy download starting: $total tiles');
      },
      onProcess: (downloaded, remaining, xyz) {
        print('Legacy progress: ${xyz.toString()}');
      },
      onEnd: (downloaded, skipped) {
        print('Legacy download done: $downloaded tiles');
      },
    );
  } catch (e) {
    print('Legacy download error: $e');
  }
}

/// Example: Using the factory pattern directly
Future<void> factoryPatternExample() async {
  print('\n=== Factory Pattern Example ===');

  // Create providers using factory
  final xyzProvider = TileProviderFactory.createXYZProvider(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    name: 'OpenStreetMap',
  );

  final wmtsProvider = TileProviderFactory.createWMTSProvider(
    urlTemplate: 'https://example.com/wmts/{Layer}/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.{format}',
    layer: 'satellite',
    style: 'default',
    tileMatrixSet: 'WebMercatorQuad',
    name: 'Example WMTS',
  );

  // Create enhanced options with specific provider
  final enhancedOptions = EnhancedDownloadOptions(
    topLeftLatLng: [39.0, 28.0],
    bottomRightLatLng: [39.1, 28.1],  // Smaller area for demo
    minZoomLevel: 10,
    maxZoomLevel: 10,
    tileProvider: xyzProvider,
    downloadFolder: './downloads/factory_example',
  );

  print('Provider validation: ${xyzProvider.isValid}');
  print('Provider name: ${xyzProvider.name}');
  print('Provider URL template: ${xyzProvider.urlTemplate}');

  // Generate tiles using provider
  final tiles = await xyzProvider.generateTiles(
    topLeftLat: 39.0,
    topLeftLng: 28.0,
    bottomRightLat: 39.1,
    bottomRightLng: 28.1,
    minZoomLevel: 10,
    maxZoomLevel: 10,
  );

  print('Generated ${tiles.length} tiles using factory provider');

  // Create crawler with factory-created options
  final crawler = EnhancedTileCrawler(enhancedOptions);
  
  try {
    await crawler.download(
      onStart: (total, remaining, area) {
        print('Factory download starting: $total tiles');
      },
      onEnd: (downloaded, skipped) {
        print('Factory download completed: $downloaded tiles');
      },
    );
  } catch (e) {
    print('Factory download error: $e');
  }
}

/// Example: Advanced WMTS configuration with KVP format
Future<void> wmtsKvpExample() async {
  print('\n=== WMTS KVP Format Example ===');

  // Create WMTS provider with KVP (Key-Value Pair) format
  final wmtsProvider = TileProviderFactory.createWMTSProvider(
    urlTemplate: 'https://example.com/wmts',  // Base URL for KVP
    layer: 'orthoimagery',
    style: 'normal',
    tileMatrixSet: 'PM',
    format: 'jpeg',
    useRestful: false,  // Use KVP format instead of RESTful
    name: 'KVP WMTS Provider',
  );

  print('WMTS KVP Provider configuration:');
  print('- Valid: ${wmtsProvider.isValid}');
  print('- Name: ${wmtsProvider.name}');
  print('- URL Template: ${wmtsProvider.urlTemplate}');

  // Show how URL would be generated
  final sampleTiles = await wmtsProvider.generateTilesForZoom(
    topLeftLat: 39.0,
    topLeftLng: 28.0,
    bottomRightLat: 39.01,
    bottomRightLng: 28.01,
    zoomLevel: 10,
  );

  if (sampleTiles.isNotEmpty) {
    final sampleTile = sampleTiles.first;
    final sampleUrl = sampleTile.buildUrl(wmtsProvider.urlTemplate);
    print('Sample KVP URL: $sampleUrl');
  }
}

/// Example: Configuration serialization and deserialization
Future<void> configurationExample() async {
  print('\n=== Configuration Serialization Example ===');

  // Create provider configurations
  final xyzConfig = {
    'type': 'xyz',
    'urlTemplate': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'name': 'OpenStreetMap XYZ',
  };

  final wmtsConfig = {
    'type': 'wmts',
    'urlTemplate': 'https://example.com/wmts/{Layer}/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.{format}',
    'name': 'Example WMTS Service',
    'layer': 'satellite',
    'style': 'default',
    'tileMatrixSet': 'WebMercatorQuad',
    'format': 'png',
    'useRestful': true,
  };

  // Create providers from configuration
  final xyzProvider = TileProviderFactory.fromMap(xyzConfig);
  final wmtsProvider = TileProviderFactory.fromMap(wmtsConfig);

  print('Created XYZ provider: ${xyzProvider.name}');
  print('Created WMTS provider: ${wmtsProvider.name}');

  // Serialize back to configuration
  final xyzSerialized = xyzProvider.toMap();
  final wmtsSerialized = wmtsProvider.toMap();

  print('XYZ serialized: $xyzSerialized');
  print('WMTS serialized: $wmtsSerialized');
}

/// Example: Using helper functions for URL generation
void urlGenerationExample() {
  print('\n=== URL Generation Helper Example ===');

  // XYZ URL generation
  final xyzTile = XYZ(x: 548, y: 372, z: 10);
  final xyzUrl = TileUrlHelper.generateXYZUrl(
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    xyzTile,
  );
  print('XYZ URL: $xyzUrl');

  // Quadkey XYZ URL generation
  final quadkeyUrl = TileUrlHelper.generateXYZUrl(
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    xyzTile,
  );
  print('Quadkey URL: $quadkeyUrl');

  // WMTS RESTful URL generation
  final wmtsRestfulUrl = TileUrlHelper.generateWMTSRestfulUrl(
    'https://example.com/wmts/{Layer}/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.{format}',
    'satellite',
    'default',
    'WebMercatorQuad',
    10,
    372,
    548,
    'png',
  );
  print('WMTS RESTful URL: $wmtsRestfulUrl');

  // WMTS KVP URL generation
  final wmtsKvpUrl = TileUrlHelper.generateWMTSKvpUrl(
    'https://example.com/wmts',
    'satellite',
    'default',
    'WebMercatorQuad',
    10,
    372,
    548,
    'png',
  );
  print('WMTS KVP URL: $wmtsKvpUrl');
} 