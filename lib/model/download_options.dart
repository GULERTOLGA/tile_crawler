part of tile_crawler;

typedef GenerateWmsUrl = String Function(XYZ xyz);

class DownloadOptions with TileCrawlerHelper {
  final LatLng topLeft;
  final LatLng bottomRight;
  final int minZoomLevel;
  final int maxZoomLevel;
  String downloadFolder;
  final HttpClient client;
  List<XYZ> _queue = [];
  final List<TileUrlProvider> tileProviders;

  DownloadOptions(
      {required this.topLeft,
      required this.bottomRight,
      required this.minZoomLevel,
      required this.maxZoomLevel,
      required this.tileProviders,
      HttpClient? client,
      this.downloadFolder = ''})
      : assert(tileProviders.isNotEmpty),
        assert(topLeft.latitude != 0),
        assert(topLeft.longitude != 0),
        assert(bottomRight.latitude != 0),
        assert(bottomRight.longitude != 0),
        assert(minZoomLevel != 0),
        assert(maxZoomLevel != 0),
        assert(minZoomLevel <= maxZoomLevel),
        client = client ?? HttpClient();
  DownloadOptions.tiles(
    List<XYZ> tiles,
    this.downloadFolder,
    this.tileProviders, {
    HttpClient? client,
  })  : topLeft = LatLng(0, 0),
        bottomRight = LatLng(0, 0),
        minZoomLevel = 0,
        maxZoomLevel = 0,
        _queue = tiles,
        client = client ?? HttpClient();

  double get area {
    var _area = _calculateArea(topLeft.latitude, topLeft.longitude,
        bottomRight.latitude, bottomRight.longitude);
    return _area / 1000000;
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    double R = 6371e3; // Dünya'nın ortalama yarıçapı (metre cinsinden)
    double phi1 = pi / 180 * lat1;
    double phi2 = pi / 180 * lat2;
    double delta_phi = pi / 180 * (lat2 - lat1);
    double delta_lambda = pi / 180 * (lon2 - lon1);
    double a = sin(delta_phi / 2) * sin(delta_phi / 2) +
        cos(phi1) * cos(phi2) * sin(delta_lambda / 2) * sin(delta_lambda / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double d = R * c;
    return d;
  }

  double _calculateArea(double lat1, double lon1, double lat2, double lon2) {
    double width = _calculateDistance(lat1, lon1, lat1, lon2);
    double height = _calculateDistance(lat1, lon1, lat2, lon1);
    return width * height;
  }

  Future<List<XYZ>> get queue async {
    if (_queue.isNotEmpty) return _queue;
    await Future.microtask(() {
      for (int z = minZoomLevel; z <= maxZoomLevel; z++) {
        _queue.addAll(calculateRectIN(calculateRect(topLeft, bottomRight, z)));
      }
    });
    return _queue;
  }

  Future<TileCrawlerSummary> get summary async {
    var _tempQueue = await queue;
    return TileCrawlerSummary(area, _tempQueue.length);
  }
}

abstract class TileUrlProvider {
  final String providerKey;
  String tileUrlFormat(XYZ xyz);
  TileUrlProvider(this.providerKey);
}

class WmsTileUrlProvider extends TileUrlProvider {
  WmsTileUrlProvider(this.generateWmsUrl, String providerKey)
      : super(providerKey);
  final GenerateWmsUrl generateWmsUrl;
  @override
  String tileUrlFormat(XYZ xyz) {
    return generateWmsUrl.call(xyz);
  }
}

class XYZTileUrlProvider extends TileUrlProvider {
  XYZTileUrlProvider(this.tileUrl, String providerKey) : super(providerKey);
  final String tileUrl;

  @override
  String tileUrlFormat(XYZ xyz) {
    return tileUrl
        .replaceAll('{x}', xyz.x.toString())
        .replaceAll('{y}', xyz.y.toString())
        .replaceAll('{z}', xyz.z.toString());
  }
}
