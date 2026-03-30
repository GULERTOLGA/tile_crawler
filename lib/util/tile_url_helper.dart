import '../model/xyz.dart' as xyz_model;

/// Helpers for filling URL templates for XYZ and WMTS.
class TileUrlHelper {
  /// Generate XYZ tile URL from a template.
  static String generateXYZUrl(String template, xyz_model.XYZ tile) {
    var url = template;

    if (url.contains('{quadkey}')) {
      url = url.replaceAll('{quadkey}', tile.toQuadKey());
    } else {
      url = url
          .replaceAll('{x}', tile.x.toString())
          .replaceAll('{y}', tile.y.toString())
          .replaceAll('{z}', tile.z.toString());
    }

    return url;
  }

  /// WMTS RESTful URL.
  static String generateWMTSRestfulUrl(
    String template,
    String layer,
    String style,
    String tileMatrixSet,
    int tileMatrix,
    int tileRow,
    int tileCol,
    String format,
  ) {
    return template
        .replaceAll('{Layer}', layer)
        .replaceAll('{Style}', style)
        .replaceAll('{TileMatrixSet}', tileMatrixSet)
        .replaceAll('{TileMatrix}', tileMatrix.toString())
        .replaceAll('{TileRow}', tileRow.toString())
        .replaceAll('{TileCol}', tileCol.toString())
        .replaceAll('{format}', format);
  }

  /// WMTS KVP URL.
  static String generateWMTSKvpUrl(
    String baseUrl,
    String layer,
    String style,
    String tileMatrixSet,
    int tileMatrix,
    int tileRow,
    int tileCol,
    String format,
  ) {
    final url = baseUrl.contains('?') ? baseUrl : '$baseUrl?';
    final params = <String, String>{
      'SERVICE': 'WMTS',
      'REQUEST': 'GetTile',
      'VERSION': '1.0.0',
      'LAYER': layer,
      'STYLE': style,
      'TILEMATRIXSET': tileMatrixSet,
      'TILEMATRIX': tileMatrix.toString(),
      'TILEROW': tileRow.toString(),
      'TILECOL': tileCol.toString(),
      'FORMAT': 'image/$format',
    };

    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return url.endsWith('?') ? '$url$queryString' : '$url&$queryString';
  }
}
