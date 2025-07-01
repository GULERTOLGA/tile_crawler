class CrawlerSummary {
  final double area;
  final int tileCount;

  const CrawlerSummary({
    required this.area,
    required this.tileCount,
  });

  @override
  String toString() =>
      'CrawlerSummary(area: ${area.toStringAsFixed(2)} km², tiles: $tileCount)';
}
