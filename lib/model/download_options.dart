part of tile_crawler;

class DownloadOptions with TileCrawlerHelper {
  final LatLng topLeft;
  final LatLng bottomRight;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  String downloadFolder;
  final HttpClient client;
  final List<XYZ> _queue = [];

  DownloadOptions(
      {required this.topLeft,
      required this.bottomRight,
      required this.minZoomLevel,
      required this.maxZoomLevel,
      required this.tileUrlFormat,
      HttpClient? client,
      this.downloadFolder = ''})
      : assert(tileUrlFormat.isNotEmpty),
        assert(topLeft.latitude != 0),
        assert(topLeft.longitude != 0),
        assert(bottomRight.latitude != 0),
        assert(bottomRight.longitude != 0),
        assert(minZoomLevel != 0),
        assert(maxZoomLevel != 0),
        assert(minZoomLevel <= maxZoomLevel),
        client = client ?? HttpClient() {
    for (int z = minZoomLevel; z <= maxZoomLevel; z++) {
      _queue.addAll(
          calculateRectIN(calculateRect(this.topLeft, this.bottomRight, z)));
    }
  }

  double get area {
    var _area = _calculateArea(this.topLeft.latitude, this.topLeft.longitude,
        this.bottomRight.latitude, this.bottomRight.longitude);
    return _area;
  }

  double _calculateArea(double lat1, double lng1, double lat2, double lng2) {
    var r = 6371000;
    double area = ((lng2 - lng1) * pi / 180) *
        ((sin(lat2 * pi / 180) - sin(lat1 * pi / 180)) *
            (cos(lng1 * pi / 180) + cos(lng2 * pi / 180)) /
            2);
    var m2 = (area * pow(r, 2));
    var km2 = m2 / 1000000;
    return km2;
  }

  List<XYZ> get queue => _queue;

  TileCrawlerSummary get summary => TileCrawlerSummary(area, queue.length);

  /*  String getTileUrl(XYZ xyz) {
    return tileUrlFormat
        .replaceAll('{x}', xyz.x.toString())
        .replaceAll('{y}', xyz.y.toString())
        .replaceAll('{z}', xyz.z.toString());
  } */
}
