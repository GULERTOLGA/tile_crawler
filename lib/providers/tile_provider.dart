import '../model/tile.dart';

/// Base interface for tile providers
/// This defines the contract for different tile services like XYZ, WMTS, etc.
abstract class TileProvider {
  /// The URL template for the tile service
  String get urlTemplate;

  /// The name/identifier of this tile provider
  String get name;

  /// Generate tiles for a given bounding box and zoom levels
  Future<List<Tile>> generateTiles({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int minZoomLevel,
    required int maxZoomLevel,
  });

  /// Generate tiles for a single zoom level
  Future<List<Tile>> generateTilesForZoom({
    required double topLeftLat,
    required double topLeftLng,
    required double bottomRightLat,
    required double bottomRightLng,
    required int zoomLevel,
  });

  /// Create a tile from a map representation
  Tile createTileFromMap(Map<String, dynamic> map);

  /// Validate if the provider configuration is valid
  bool get isValid;

  /// Get configuration as a map for serialization
  Map<String, dynamic> toMap();

  /// Create provider from configuration map
  static TileProvider fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }
}
