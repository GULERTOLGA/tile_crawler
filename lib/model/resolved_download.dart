import 'package:tile_crawler/model/storage_layout.dart';
import 'package:tile_crawler/model/tile.dart' show CoordinateTile, Tile;
import 'package:tile_crawler/model/xyz.dart' as xyz_model;
import 'package:tile_crawler/util/tile_url_helper.dart';

/// One concrete HTTP GET and destination path for a single map tile.
///
/// Produced from a [Tile] plus [TileProvider.urlTemplate] and [StorageLayout],
/// or from legacy [xyz_model.XYZ] + URL template for XYZ-only flows.
class ResolvedDownload {
  ResolvedDownload({
    required this.url,
    required this.relativePath,
    this.expectedContentType,
    required this.tileId,
    required this.progressXYZ,
  });

  /// Resolved request URL (user-controlled strings must be validated separately).
  final Uri url;

  /// Path segments under the download root, e.g. `12/3456/789.png`.
  final String relativePath;

  /// Hint from tile format or template (e.g. `image/png`); may be null.
  final String? expectedContentType;

  /// Stable id for logging and callbacks (matches [Tile.id] when applicable).
  final String tileId;

  /// Index used by legacy progress callbacks ([OnTileProcess]).
  final xyz_model.XYZ progressXYZ;

  /// Build from a generic [Tile] and provider template.
  factory ResolvedDownload.fromTile({
    required Tile tile,
    required String urlTemplate,
    required StorageLayout storageLayout,
  }) {
    final coord = tile is CoordinateTile ? tile : null;
    if (coord == null) {
      throw ArgumentError.value(tile, 'tile', 'must be CoordinateTile');
    }
    return ResolvedDownload(
      url: tile.resolveUrl(urlTemplate),
      relativePath: tile.storageRelativePath(storageLayout),
      expectedContentType: _hintContentType(tile),
      tileId: tile.id,
      progressXYZ: xyz_model.XYZ(
        x: coord.x,
        y: coord.y,
        z: coord.zoomLevel,
      ),
    );
  }

  /// Legacy XYZ index + Slippy/TMS layout (no [Tile] instance).
  factory ResolvedDownload.fromXyz({
    required xyz_model.XYZ xyz,
    required String urlTemplate,
    required StorageLayout storageLayout,
    String fileExtensionHint = 'png',
  }) {
    final url = Uri.parse(TileUrlHelper.generateXYZUrl(urlTemplate, xyz));
    final relative = _xyzRelativePath(xyz, storageLayout, fileExtensionHint);
    return ResolvedDownload(
      url: url,
      relativePath: relative,
      expectedContentType: _hintFromExtension(fileExtensionHint),
      tileId: '${xyz.z}/${xyz.x}/${xyz.y}',
      progressXYZ: xyz,
    );
  }

  static String _xyzRelativePath(
    xyz_model.XYZ xyz,
    StorageLayout layout,
    String ext,
  ) {
    final yOut = switch (layout) {
      StorageLayout.slippyMapXyz => xyz.y,
      StorageLayout.tmsGlobalMercatorY => (1 << xyz.z) - 1 - xyz.y,
      StorageLayout.sourceRelativePath =>
        '${xyz.z}/${xyz.x}/${xyz.y}.$ext', // same as slippy for raw XYZ
    };
    return '${xyz.z}/${xyz.x}/$yOut.$ext';
  }

  static String? _hintContentType(Tile tile) {
    final e = tile.fileExtension.toLowerCase();
    return _hintFromExtension(e);
  }

  static String? _hintFromExtension(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }
}
