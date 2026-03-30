import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tile_crawler/tile_crawler.dart';

void main() {
  test('XYZ creation', () {
    const xyz = XYZ(x: 10, y: 20, z: 5);
    expect(xyz.x, 10);
    expect(xyz.y, 20);
    expect(xyz.z, 5);
  });

  test('DownloadOptions queue size for bbox and zoom range', () async {
    final options = DownloadOptions(
      topLeftLatLng: [40.7580, -73.9855],
      bottomRightLatLng: [40.7489, -73.9441],
      minZoomLevel: 10,
      maxZoomLevel: 10,
      tileUrlFormat: MapProviders.openStreetMap,
      downloadFolder: '/tmp/tiles',
    );
    final q = await options.queue;
    expect(q.isNotEmpty, true);
    expect(q.every((t) => t.z == 10), true);
  });

  test('TileUrlHelper XYZ URL', () {
    const xyz = XYZ(x: 1, y: 2, z: 3);
    final u = TileUrlHelper.generateXYZUrl('https://a/{z}/{x}/{y}.png', xyz);
    expect(u, 'https://a/3/1/2.png');
  });

  test('ResolvedDownload.fromXyz path slippy vs TMS', () {
    const xyz = XYZ(x: 0, y: 0, z: 1);
    final slippy = ResolvedDownload.fromXyz(
      xyz: xyz,
      urlTemplate: 'https://t/{z}/{x}/{y}.png',
      storageLayout: StorageLayout.slippyMapXyz,
    );
    expect(slippy.relativePath, '1/0/0.png');
    final tms = ResolvedDownload.fromXyz(
      xyz: xyz,
      urlTemplate: 'https://t/{z}/{x}/{y}.png',
      storageLayout: StorageLayout.tmsGlobalMercatorY,
    );
    expect(tms.relativePath, '1/0/1.png');
    const xyz2 = XYZ(x: 0, y: 1, z: 1);
    final tms2 = ResolvedDownload.fromXyz(
      xyz: xyz2,
      urlTemplate: 'https://t/{z}/{x}/{y}.png',
      storageLayout: StorageLayout.tmsGlobalMercatorY,
    );
    expect(tms2.relativePath, '1/0/0.png');
  });

  test('XYZTile storageRelativePath', () {
    final t = XYZTile(x: 3, y: 4, zoomLevel: 2);
    expect(
      t.storageRelativePath(StorageLayout.slippyMapXyz),
      '2/3/4.png',
    );
  });

  test('safeTileFilePath rejects traversal', () {
    final root = Directory.systemTemp.createTempSync('tile_crawler_safe_');
    try {
      expect(
        () => safeTileFilePath(root.path, '../etc/passwd'),
        throwsArgumentError,
      );
    } finally {
      root.deleteSync(recursive: true);
    }
  });

  test('extensionForTilePayload uses magic bytes', () {
    final png = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    expect(extensionForTilePayload(bytes: png, contentTypeHeader: null), 'png');
  });

  test('TileProjectionRegistry EPSG:7933 WGS84 to projected', () {
    final reg = TileProjectionRegistry.instance;
    final p = reg.wgs84ToProjected(
      projectionCode: KnownProjections.epsg7933Code,
      projectionDef: KnownProjections.epsg7933Def,
      longitude: 32.85,
      latitude: 39.93,
    );
    expect(p.x > 400000 && p.x < 600000, true);
    expect(p.y > 4e6 && p.y < 5e6, true);
  });
}
