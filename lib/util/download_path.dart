import 'dart:io';

import 'package:path/path.dart' as p;

/// Joins [downloadRoot] with [relativePath] and rejects `..` / odd segments.
///
/// Prevents path traversal when [relativePath] is influenced by external input.
/// Combine with [TileDownloadSecurity.isHostAllowed] for user URLs (SSRF).
String safeTileFilePath(String downloadRoot, String relativePath) {
  final dir = Directory(downloadRoot).absolute;
  final rootPath = p.normalize(
    dir.existsSync() ? dir.resolveSymbolicLinksSync() : dir.path,
  );
  final segments = relativePath
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty)
      .toList(growable: false);
  for (final seg in segments) {
    if (seg == '..' || seg == '.') {
      throw ArgumentError.value(
          relativePath, 'relativePath', 'invalid segment');
    }
  }
  final full = p.normalize(p.join(rootPath, p.joinAll(segments)));
  final rel = p.relative(full, from: rootPath);
  if (rel.startsWith('..')) {
    throw ArgumentError.value(relativePath, 'relativePath', 'escapes root');
  }
  return full;
}
