import '../model/tile.dart';
import '../model/xyz_tile.dart';
import 'tile_provider.dart';

/// XYZ tile provider for standard web map tiles (Slippy Map)
class XYZTileProvider extends TileProvider {
  @override
  final String urlTemplate;

  @override
  final String name;

  XYZTileProvider({
    required this.urlTemplate,
    this.name = 'XYZ Provider',
  }) : assert(urlTemplate.isNotEmpty, 'URL template cannot be empty');

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

    for (int zoomLevel = minZoomLevel; zoomLevel <= maxZoomLevel; zoomLevel++) {
      final levelTiles = await generateTilesForZoom(
        topLeftLat: topLeftLat,
        topLeftLng: topLeftLng,
        bottomRightLat: bottomRightLat,
        bottomRightLng: bottomRightLng,
        zoomLevel: zoomLevel,
      );
      tiles.addAll(levelTiles);
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
    final xyzTiles = XYZTile.tilesInBounds(
      topLeftLat: topLeftLat,
      topLeftLng: topLeftLng,
      bottomRightLat: bottomRightLat,
      bottomRightLng: bottomRightLng,
      zoomLevel: zoomLevel,
    );

    return xyzTiles.cast<Tile>();
  }

  @override
  Tile createTileFromMap(Map<String, dynamic> map) {
    return XYZTile.fromMap(map);
  }

  @override
  bool get isValid {
    return urlTemplate.isNotEmpty &&
        (urlTemplate.contains('{x}') || urlTemplate.contains('{quadkey}')) &&
        (urlTemplate.contains('{y}') || urlTemplate.contains('{quadkey}')) &&
        (urlTemplate.contains('{z}') || urlTemplate.contains('{quadkey}'));
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'xyz',
      'urlTemplate': urlTemplate,
      'name': name,
    };
  }

  static XYZTileProvider fromMap(Map<String, dynamic> map) {
    return XYZTileProvider(
      urlTemplate: map['urlTemplate'] as String,
      name: map['name'] as String? ?? 'XYZ Provider',
    );
  }

  @override
  String toString() =>
      'XYZTileProvider(name: $name, urlTemplate: $urlTemplate)';
}
