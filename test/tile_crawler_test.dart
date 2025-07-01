import 'package:flutter_test/flutter_test.dart';
import 'package:tile_crawler/tile_crawler.dart';

void main() {
  test('XYZ creation test', () {
    const xyz = XYZ(x: 10, y: 20, z: 5);
    expect(xyz.x, 10);
    expect(xyz.y, 20);
    expect(xyz.z, 5);
  });

  test('DownloadOptions creation test', () {
    final options = DownloadOptions(
      topLeftLatLng: [40.7580, -73.9855],
      bottomRightLatLng: [40.7489, -73.9441],
      minZoomLevel: 10,
      maxZoomLevel: 12,
      tileUrlFormat: MapProviders.openStreetMap,
      downloadFolder: '/tmp/tiles',
    );

    expect(options.minZoomLevel, 10);
    expect(options.maxZoomLevel, 12);
  });
}
