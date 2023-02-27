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
      : client = client ?? HttpClient();
}
