/// On-disk layout for cached tiles under a single download root.
///
/// **Slippy / XYZ (default for flutter_map, OpenLayers XYZ):** `root/{z}/{x}/{y}.ext`
/// Web Mercator tile row [y] increases south (OSM / Google Maps convention).
///
/// **TMS global Mercator:** Same path shape as Slippy but [y] is converted with
/// `yTms = (2^z - 1) - y` before writing. Use when the server uses TMS row order
/// but you still want `z/x/y.ext` files. Projection-specific WMTS may need
/// [sourceRelativePath] instead.
///
/// **Source-relative:** Uses [Tile.filePath] (e.g. WMTS layer/style/matrix/...).
/// Matches “mirror server path segments” style archives; not flutter_map-default.
/// NetGIS OnlineMapRaster offline packs use this layout: each GetTile URL maps to
/// the same relative path as [wmtsArchiveRelativePathFromTileUrl] / local WMTS REST.
enum StorageLayout {
  /// `z/x/y.ext` — Slippy Map / XYZ (flutter_map-friendly).
  slippyMapXyz,

  /// `z/x/yTms.ext` where `yTms = (1 << z) - 1 - y` (XYZ y → TMS row on disk).
  tmsGlobalMercatorY,

  /// Use each tile’s [Tile.filePath] (no coordinate rewrite).
  sourceRelativePath,
}
