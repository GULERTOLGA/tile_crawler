part of tile_crawler;


class Rectangle {
  final int startX;
  final int startY;
  final int endX;
  final int endY;
  final int level;

  Rectangle(
      {required this.startX,
      required this.startY,
      required this.endX,
      required this.level,
      required this.endY});

  @override
  String toString() {
    return "$startX, $startY $endX, $endY $level";
  }
}
