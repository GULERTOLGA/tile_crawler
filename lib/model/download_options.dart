part of tile_crawler;

class DownloadOptions {
  final LatLng topLeft;
  final LatLng bottomRight;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  final String downloadFolder;
  final HttpClient client;

  DownloadOptions(
      {required this.topLeft,
      required this.bottomRight,
      required this.minZoomLevel,
      required this.maxZoomLevel,
      required this.tileUrlFormat,
      HttpClient? client,
      required this.downloadFolder})
      : assert(tileUrlFormat.isNotEmpty),
        assert(downloadFolder.isNotEmpty),
        assert(topLeft.latitude != 0),
        assert(topLeft.longitude != 0),
        assert(bottomRight.latitude != 0),
        assert(bottomRight.longitude != 0),
        assert(minZoomLevel != 0),
        assert(maxZoomLevel != 0),
        assert(minZoomLevel <= maxZoomLevel),
        client = client ?? HttpClient();
}
