/// Maps a WMTS GetTile request URL to the same relative path layout used by
/// [StorageLayout.sourceRelativePath] / [WMTSTile.filePath] and by
/// `tile_shelf_handler` KVP / REST handlers.

import '../model/wmts_tile.dart';

/// ASCII-only upper case (OGC KVP parameter names).
String _asciiUpper(String s) {
  final codeUnits = <int>[];
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0x61 && c <= 0x7A) {
      codeUnits.add(c - 0x20);
    } else {
      codeUnits.add(c);
    }
  }
  return String.fromCharCodes(codeUnits);
}

Map<String, String> _normalizedQuery(Uri uri) {
  final out = <String, String>{};
  for (final e in uri.queryParametersAll.entries) {
    if (e.value.isEmpty) {
      continue;
    }
    out[_asciiUpper(e.key)] = e.value.first;
  }
  return out;
}

bool _isWmtsGetTileQuery(Map<String, String> q) {
  final svc = q['SERVICE'] != null ? _asciiUpper(q['SERVICE']!) : '';
  final req = q['REQUEST'] != null ? _asciiUpper(q['REQUEST']!) : '';
  return svc == 'WMTS' && req == 'GETTILE';
}

String? _extensionFromFormat(String? format) {
  if (format == null || format.isEmpty) {
    return null;
  }
  final f = format.toLowerCase().trim();
  if (f == 'image/png') {
    return 'png';
  }
  if (f == 'image/jpeg' || f == 'image/jpg') {
    return 'jpg';
  }
  if (f == 'image/webp') {
    return 'webp';
  }
  if (f == 'image/gif') {
    return 'gif';
  }
  final slash = f.indexOf('/');
  if (slash >= 0 && slash < f.length - 1) {
    return f.substring(slash + 1);
  }
  return null;
}

/// Parses [uri] (KVP GetTile or WMTS REST path) and returns the relative path
/// under the download root, or `null` if not recognized.
///
/// KVP: `SERVICE=WMTS`, `REQUEST=GetTile`, `LAYER`, `STYLE`, `TILEMATRIXSET`,
/// `TILEMATRIX` (or `TileMatrix`), `TILEROW`, `TILECOL`, optional `FORMAT`.
///
/// REST: last six path segments
/// `{Layer}/{Style}/{TileMatrixSet}/{TileMatrix}/{TileRow}/{TileCol}.ext`.
String? wmtsArchiveRelativePathFromTileUrl(Uri uri) {
  final fixed = uri.toString().contains('&&')
      ? Uri.parse(uri.toString().replaceAll('&&', '&'))
      : uri;
  final q = _normalizedQuery(fixed);
  if (_isWmtsGetTileQuery(q)) {
    final layer = q['LAYER'];
    final style = q['STYLE'];
    final tms = q['TILEMATRIXSET'];
    final tm = q['TILEMATRIX'];
    final tr = q['TILEROW'];
    final tc = q['TILECOL'];
    if (layer == null ||
        style == null ||
        tms == null ||
        tm == null ||
        tr == null ||
        tc == null) {
      return null;
    }
    final ext = _extensionFromFormat(q['FORMAT']) ?? 'png';
    return '$layer/$style/$tms/$tm/$tr/$tc.$ext';
  }
  final segs = fixed.pathSegments.where((s) => s.isNotEmpty).toList();
  if (segs.length >= 6) {
    final last = segs.last;
    final lastDot = last.lastIndexOf('.');
    if (lastDot <= 0 || lastDot == last.length - 1) {
      return null;
    }
    final tileCol = last.substring(0, lastDot);
    final ext = last.substring(lastDot + 1);
    final layer = segs[segs.length - 6];
    final style = segs[segs.length - 5];
    final tileMatrixSet = segs[segs.length - 4];
    final tileMatrix = segs[segs.length - 3];
    final tileRow = segs[segs.length - 2];
    if (layer.isEmpty ||
        style.isEmpty ||
        tileMatrixSet.isEmpty ||
        tileMatrix.isEmpty ||
        tileRow.isEmpty ||
        tileCol.isEmpty) {
      return null;
    }
    return '$layer/$style/$tileMatrixSet/$tileMatrix/$tileRow/$tileCol.$ext';
  }
  return null;
}

/// Fallback when [wmtsArchiveRelativePathFromTileUrl] returns null: build
/// [WMTSTile.filePath] from registry metadata and tile indices.
String wmtsFallbackSourceRelativePath({
  required int tileCol,
  required int tileRow,
  required int tileMatrixIndex,
  required String layer,
  required String style,
  required String tileMatrixSet,
  required String format,
}) {
  final t = WMTSTile(
    x: tileCol,
    y: tileRow,
    zoomLevel: tileMatrixIndex,
    layer: layer,
    style: style,
    tileMatrixSet: tileMatrixSet,
    format: format,
    useRestful: true,
  );
  return t.filePath;
}
