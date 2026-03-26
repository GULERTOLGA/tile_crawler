import 'dart:math';
import 'tile_provider.dart';
import '../model/tile.dart';
import '../model/wmts_tile.dart';

/// Custom WMTS tile provider with support for custom coordinate systems,
/// origins, resolutions, and authentication parameters
class CustomWMTSTileProvider extends TileProvider {
  final String _urlTemplate;
  final String _name;
  final String layer;
  final String style;
  final String tileMatrixSet;
  final String format;
  final String? sid;
  final List<double> resolutions;
  final double originX;
  final double originY;
  final int tileSize;
  final String? customParams;

  CustomWMTSTileProvider({
    required String urlTemplate,
    required this.layer,
    required this.style,
    required this.tileMatrixSet,
    required this.format,
    this.sid,
    required this.resolutions,
    required this.originX,
    required this.originY,
    this.tileSize = 256,
    this.customParams,
    String? name,
  })  : _urlTemplate = urlTemplate,
        _name = name ?? 'Custom WMTS Provider';

  @override
  String get urlTemplate => _urlTemplate;

  @override
  String get name => _name;

  @override
  bool get isValid {
    return urlTemplate.isNotEmpty &&
        layer.isNotEmpty &&
        style.isNotEmpty &&
        tileMatrixSet.isNotEmpty &&
        format.isNotEmpty &&
        resolutions.isNotEmpty &&
        originX != 0 &&
        originY != 0;
  }

  @override
  Future<List<Tile>> generateTiles({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int minZoomLevel,
    required int maxZoomLevel,
  }) async {
    final tiles = <Tile>[];

    // Convert bbox to projected coordinates if needed
    final bbox = [topLeftLng, bottomRightLat, bottomRightLng, topLeftLat];

    for (int zoom = minZoomLevel; zoom <= maxZoomLevel; zoom++) {
      final zoomTiles = await generateTilesForZoom(
        topLeftLat: topLeftLat,
        topLeftLng: topLeftLng,
        bottomRightLat: bottomRightLat,
        bottomRightLng: bottomRightLng,
        zoomLevel: zoom,
      );
      tiles.addAll(zoomTiles);
    }

    return tiles;
  }

  @override
  Future<List<Tile>> generateTilesForZoom({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int zoomLevel,
  }) async {
    final tiles = <Tile>[];

    if (zoomLevel >= resolutions.length) {
      // Skip zoom levels that don't have resolution data
      return tiles;
    }

    final bbox = [topLeftLng, bottomRightLat, bottomRightLng, topLeftLat];
    final tileRange = _bboxToTileRange(bbox, zoomLevel);
    final minCol = tileRange[0];
    final maxCol = tileRange[1];
    final minRow = tileRange[2];
    final maxRow = tileRange[3];

    for (int col = minCol; col <= maxCol; col++) {
      for (int row = minRow; row <= maxRow; row++) {
        final tile = CustomWMTSTile(
          x: col,
          y: row,
          zoomLevel: zoomLevel,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          sid: sid,
          customParams: customParams,
          baseUrl: urlTemplate,
        );
        tiles.add(tile);
      }
    }

    return tiles;
  }

  @override
  Tile createTileFromMap(Map<String, dynamic> map) {
    return CustomWMTSTile.fromMap(map);
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'custom_wmts',
      'urlTemplate': urlTemplate,
      'name': name,
      'layer': layer,
      'style': style,
      'tileMatrixSet': tileMatrixSet,
      'format': format,
      'sid': sid,
      'resolutions': resolutions,
      'originX': originX,
      'originY': originY,
      'tileSize': tileSize,
      'customParams': customParams,
    };
  }

  /// Convert bounding box to tile range using custom origin and resolutions
  List<int> _bboxToTileRange(List<double> bbox, int zoom) {
    final minx = bbox[0];
    final miny = bbox[1];
    final maxx = bbox[2];
    final maxy = bbox[3];
    final res = resolutions[zoom];

    final minCol = ((minx - originX) / (tileSize * res)).floor();
    final maxCol = ((maxx - originX) / (tileSize * res)).floor();
    final minRow = ((originY - maxy) / (tileSize * res)).floor();
    final maxRow = ((originY - miny) / (tileSize * res)).floor();

    return [minCol, maxCol, minRow, maxRow];
  }
}

/// Custom WMTS tile with authentication and custom parameters
class CustomWMTSTile extends WMTSTile {
  final String? sid;
  final String? customParams;
  final String baseUrl;

  CustomWMTSTile({
    required int x,
    required int y,
    required int zoomLevel,
    required String layer,
    required String style,
    required String tileMatrixSet,
    required String format,
    this.sid,
    this.customParams,
    required this.baseUrl,
  }) : super(
          x: x,
          y: y,
          zoomLevel: zoomLevel,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          useRestful: false, // Use KVP format
        );

  @override
  String buildUrl(String urlTemplate) {
    final params = <String, String>{
      'layer': layer,
      'style': style,
      'tilematrixset': tileMatrixSet,
      'Service': 'WMTS',
      'Request': 'GetTile',
      'Version': '1.0.0',
      'Format': 'image%2F${format.toLowerCase()}',
      'TileMatrix': zoomLevel.toString(),
      'TileCol': x.toString(),
      'TileRow': y.toString(),
    };

    // Add SID if provided
    if (sid != null && sid!.isNotEmpty) {
      params['@sid'] = sid!;
    }

    // Add custom parameters if provided
    if (customParams != null && customParams!.isNotEmpty) {
      // Parse custom params and add to the map
      final customParamPairs = customParams!.split('&');
      for (final pair in customParamPairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2) {
          params[keyValue[0]] = keyValue[1];
        }
      }
    }

    // Build query string
    final queryString =
        params.entries.map((entry) => '${entry.key}=${entry.value}').join('&');

    return '$baseUrl?$queryString';
  }

  @override
  String get filePath => '$zoomLevel/$x/$y.$format';

  @override
  String get id => 'custom_wmts_${zoomLevel}_${x}_${y}';

  @override
  Map<String, dynamic> toMap() {
    return {
      ...super.toMap(),
      'sid': sid,
      'customParams': customParams,
      'baseUrl': baseUrl,
    };
  }

  static CustomWMTSTile fromMap(Map<String, dynamic> map) {
    return CustomWMTSTile(
      x: map['x'] as int,
      y: map['y'] as int,
      zoomLevel: map['z'] as int,
      layer: map['layer'] as String,
      style: map['style'] as String,
      tileMatrixSet: map['tileMatrixSet'] as String,
      format: map['format'] as String,
      sid: map['sid'] as String?,
      customParams: map['customParams'] as String?,
      baseUrl: map['baseUrl'] as String,
    );
  }

  @override
  String toString() {
    return 'CustomWMTSTile(z: $zoomLevel, x: $x, y: $y, layer: $layer, sid: $sid)';
  }
}

/// Predefined custom WMTS providers
class CustomWMTSProviders {
  /// Turkish Land Registry WMTS provider
  static CustomWMTSTileProvider get turkishLandRegistry =>
      CustomWMTSTileProvider(
        urlTemplate: 'https://your-wmts-server.com/wmts',
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
        tileSize: 256,
        customParams: 'NCWS=wmtstest',
        name: 'Turkish Land Registry WMTS',
      );

  /// NetGIS Plan1000 WMTS provider - Real server test
  static CustomWMTSTileProvider get netgisPlan1000 => CustomWMTSTileProvider(
        urlTemplate: 'https://ssltest.netcad.com.tr/netgisnew/wmts.ashx',
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
        tileSize: 256,
        customParams: 'NCWS=WMTSTEST2',
        name: 'NetGIS Plan1000',
      );

  /// Create a custom WMTS provider with authentication
  static CustomWMTSTileProvider createWithAuth({
    required String baseUrl,
    required String sid,
    required String layer,
    required String style,
    required String tileMatrixSet,
    required String format,
    required List<double> resolutions,
    required double originX,
    required double originY,
    String? customParams,
    int tileSize = 256,
    String? name,
  }) {
    return CustomWMTSTileProvider(
      urlTemplate: baseUrl,
      layer: layer,
      style: style,
      tileMatrixSet: tileMatrixSet,
      format: format,
      sid: sid,
      resolutions: resolutions,
      originX: originX,
      originY: originY,
      tileSize: tileSize,
      customParams: customParams,
      name: name ?? 'Custom WMTS with Auth',
    );
  }
}
