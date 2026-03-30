import 'storage_layout.dart';

/// Base interface for all tile types
/// This provides a common contract for different tile systems like XYZ, WMTS, etc.
abstract class Tile {
  /// Unique identifier for the tile
  String get id;

  /// File path for storing the tile (relative to download folder)
  String get filePath;

  /// File extension for the tile (e.g., 'png', 'jpg')
  String get fileExtension;

  /// Generate the URL for downloading this tile
  String buildUrl(String urlTemplate);

  /// Resolved download URI for this tile and provider [urlTemplate].
  Uri resolveUrl(String urlTemplate) => Uri.parse(buildUrl(urlTemplate));

  /// Relative path under the download root for [layout] (no leading slash).
  String storageRelativePath(StorageLayout layout);

  /// Create a serializable representation of the tile
  Map<String, dynamic> toMap();

  /// Create a tile from a serializable representation
  static Tile fromMap(Map<String, dynamic> map) {
    throw UnimplementedError('Subclasses must implement fromMap');
  }

  /// Check if this tile is equal to another
  @override
  bool operator ==(Object other);

  /// Hash code for the tile
  @override
  int get hashCode;

  /// String representation of the tile
  @override
  String toString();
}

/// Base class for tiles with coordinate-based systems
abstract class CoordinateTile extends Tile {
  /// Zoom level of the tile
  int get zoomLevel;

  /// X coordinate
  int get x;

  /// Y coordinate
  int get y;
}
