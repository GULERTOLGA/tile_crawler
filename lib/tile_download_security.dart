/// Optional host allow-list for tile HTTP requests (mitigate SSRF from templates).
class TileDownloadSecurity {
  const TileDownloadSecurity({this.allowedHosts});

  /// Lowercase hostnames without port, e.g. `{'tile.openstreetmap.org'}`.
  /// Null or empty = no host restriction (caller is responsible for trust).
  final Set<String>? allowedHosts;

  bool isHostAllowed(String host) {
    final allow = allowedHosts;
    if (allow == null || allow.isEmpty) {
      return true;
    }
    final h = host.toLowerCase();
    return allow.contains(h);
  }
}
