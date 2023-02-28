class TileCrawlerSummary {
  final double area;
  final int tileCount;
  TileCrawlerSummary(this.area, this.tileCount);
  double get tileSizeAsMB => tileCount * (256 * 256 / 1024 / 1024);
  @override
  String toString() {
    return "Area: $area, Tile Count: $tileCount, Tile Size: ${tileSizeAsMB.toStringAsFixed(2)} MB";
  }
}
