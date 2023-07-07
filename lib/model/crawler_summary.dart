class TileCrawlerSummary {
  final double area;
  final int tileCount;
  TileCrawlerSummary(this.area, this.tileCount);

  @override
  String toString() {
    return "Area: $area, Tile Count: $tileCount";
  }
}
