import 'package:proj4dart/proj4dart.dart';

import '../model/tile.dart';
import '../model/wmts_tile.dart';
import '../util/tile_projection_registry.dart';
import 'tile_provider.dart';

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
  final bool useRestful;

  /// CRS code registered with proj4dart (e.g. `EPSG:7933`).
  final String projectionCode;

  /// PROJ.4 definition string for [projectionCode]; used for WGS84 → grid
  /// conversion when computing tile indices.
  final String projectionDef;

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
    required this.projectionCode,
    required this.projectionDef,
    this.tileSize = 256,
    this.customParams,
    this.useRestful = false,
    String? name,
    TileProjectionRegistry? projectionRegistry,
  })  : _projectionRegistry =
            projectionRegistry ?? TileProjectionRegistry.instance,
        _urlTemplate = urlTemplate,
        _name = name ?? 'Custom WMTS Provider';

  final TileProjectionRegistry _projectionRegistry;

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
        projectionCode.isNotEmpty &&
        projectionDef.isNotEmpty &&
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

    final topLeftProj = _toProjected(topLeftLng, topLeftLat);
    final bottomRightProj = _toProjected(bottomRightLng, bottomRightLat);
    final bbox = [
      topLeftProj.x,
      bottomRightProj.y,
      bottomRightProj.x,
      topLeftProj.y
    ];
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
          useRestful: useRestful,
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
      'useRestful': useRestful,
      'projectionCode': projectionCode,
      'projectionDef': projectionDef,
    };
  }

  /// WGS84 (lng, lat) → projected coordinates in [projectionCode].
  Point _toProjected(double lng, double lat) {
    return _projectionRegistry.wgs84ToProjected(
      projectionCode: projectionCode,
      projectionDef: projectionDef,
      longitude: lng,
      latitude: lat,
    );
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
    bool useRestful = false,
  }) : super(
          x: x,
          y: y,
          zoomLevel: zoomLevel,
          layer: layer,
          style: style,
          tileMatrixSet: tileMatrixSet,
          format: format,
          useRestful: useRestful,
        );

  @override
  String buildUrl(String urlTemplate) {
    if (useRestful) {
      final baseRestUrl = super.buildUrl(urlTemplate);
      final additionalQuery = _buildAdditionalQuery();
      if (additionalQuery.isEmpty) {
        return baseRestUrl;
      }
      final separator = baseRestUrl.contains('?') ? '&' : '?';
      return '$baseRestUrl$separator$additionalQuery';
    }

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

    _appendAdditionalParams(params);

    // Build query string
    final queryString =
        params.entries.map((entry) => '${entry.key}=${entry.value}').join('&');

    return '$baseUrl?$queryString';
  }

  @override
  String get id => 'custom_wmts_${zoomLevel}_${x}_$y';

  void _appendAdditionalParams(Map<String, String> params) {
    if (sid != null && sid!.isNotEmpty) {
      params['@sid'] = sid!;
    }
    if (customParams != null && customParams!.isNotEmpty) {
      final customParamPairs = customParams!.split('&');
      for (final pair in customParamPairs) {
        final keyValue = pair.split('=');
        if (keyValue.length == 2 &&
            keyValue[0].isNotEmpty &&
            keyValue[1].isNotEmpty) {
          params[keyValue[0]] = keyValue[1];
        }
      }
    }
  }

  String _buildAdditionalQuery() {
    final params = <String, String>{};
    _appendAdditionalParams(params);
    return params.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }

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
      useRestful: map['useRestful'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'CustomWMTSTile(z: $zoomLevel, x: $x, y: $y, layer: $layer, sid: $sid)';
  }
}

/// Predefined custom WMTS providers
class CustomWMTSProviders {
  /// Resolution ladder shared by NetGIS Plan1000 / Alanya sample configs.
  static const List<double> netgisPlan1000Resolutions = [
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
    0.119209170341491796875,
  ];

  /// Turkish Land Registry WMTS provider
  static CustomWMTSTileProvider get turkishLandRegistry =>
      CustomWMTSTileProvider(
        urlTemplate: 'https://your-wmts-server.com/wmts',
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
        layer: 'AlanyaPlanWMS',
        style: 'default',
        tileMatrixSet: 'AlanyaPlanWMS_7933',
        format: 'png',
        projectionCode: KnownProjections.epsg7933Code,
        projectionDef: KnownProjections.epsg7933Def,
        resolutions: netgisPlan1000Resolutions,
        originX: -180,
        originY: 31999878,
        tileSize: 256,
        customParams: 'NCWS=ALANYA_BELNETMAP6',
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
    required String projectionCode,
    required String projectionDef,
    String? customParams,
    int tileSize = 256,
    bool useRestful = false,
    String? name,
    TileProjectionRegistry? projectionRegistry,
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
      projectionCode: projectionCode,
      projectionDef: projectionDef,
      tileSize: tileSize,
      customParams: customParams,
      useRestful: useRestful,
      name: name ?? 'Custom WMTS with Auth',
      projectionRegistry: projectionRegistry,
    );
  }
}
