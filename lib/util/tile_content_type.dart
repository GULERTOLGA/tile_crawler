/// Picks a file extension from `Content-Type` and/or magic bytes.
String? extensionForTilePayload({
  required List<int> bytes,
  String? contentTypeHeader,
}) {
  final fromHeader = _extensionFromContentType(contentTypeHeader);
  if (fromHeader != null) {
    return fromHeader;
  }
  return _extensionFromMagic(bytes);
}

String? _extensionFromContentType(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final lower = raw.toLowerCase();
  if (lower.contains('image/png')) {
    return 'png';
  }
  if (lower.contains('image/jpeg') || lower.contains('image/jpg')) {
    return 'jpg';
  }
  if (lower.contains('image/webp')) {
    return 'webp';
  }
  if (lower.contains('image/gif')) {
    return 'gif';
  }
  return null;
}

String? _extensionFromMagic(List<int> bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4e &&
      bytes[3] == 0x47) {
    return 'png';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xff &&
      bytes[1] == 0xd8 &&
      bytes[2] == 0xff) {
    return 'jpg';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46) {
    // RIFF....WEBP
    final sig = String.fromCharCodes(bytes.sublist(8, 12));
    if (sig == 'WEBP') {
      return 'webp';
    }
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x38) {
    return 'gif';
  }
  return null;
}
