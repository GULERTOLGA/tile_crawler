part of tile_crawler;

class MapProviders {
  static const String googleStreets =
      "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}";

  static const String openStreetMap =
      "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png";

  static const String bingSattellite =
      "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90";
}
