import 'package:proj4dart/proj4dart.dart' as proj4;

/// Well-known CRS identifiers and PROJ.4 [def strings][def] used by this
/// package’s WMTS helpers.
///
/// [def]: https://proj.org/usage/quickstart.html
abstract class KnownProjections {
  /// Türkiye Ulusal Grid / TM3 (GRS80), common for cadastral WMTS layers.
  static const String epsg7933Code = 'EPSG:7933';

  /// PROJ.4 definition for [epsg7933Code].
  static const String epsg7933Def =
      '+proj=tmerc +lat_0=0 +lon_0=33 +k=1 +x_0=500000 +y_0=0 '
      '+ellps=GRS80 +units=m +no_defs';
}

/// Registers CRS definitions with proj4dart and performs WGS84 → projected
/// transforms for custom WMTS tile math.
///
/// Uses the global [proj4.Projection] store; [ensureRegistered] only calls
/// [proj4.Projection.add] when [projectionCode] is not yet present, avoiding
/// duplicate registration warnings when possible.
class TileProjectionRegistry {
  TileProjectionRegistry._();

  /// Shared instance for app-wide registration.
  static final TileProjectionRegistry instance = TileProjectionRegistry._();

  static final proj4.Projection _wgs84 = proj4.Projection.get('EPSG:4326')!;

  /// Returns the [proj4.Projection] for [projectionCode], registering
  /// [defString] first if the code is missing from the store.
  proj4.Projection ensureRegistered(
    String projectionCode,
    String defString,
  ) {
    final existing = proj4.Projection.get(projectionCode);
    if (existing != null) {
      return existing;
    }
    return proj4.Projection.add(projectionCode, defString);
  }

  /// Transforms WGS84 geographic coordinates to the target CRS.
  ///
  /// [longitude] and [latitude] are in degrees (EPSG:4326 axis order).
  proj4.Point wgs84ToProjected({
    required String projectionCode,
    required String projectionDef,
    required double longitude,
    required double latitude,
  }) {
    final target = ensureRegistered(projectionCode, projectionDef);
    return _wgs84.transform(
      target,
      proj4.Point(x: longitude, y: latitude),
    );
  }
}
