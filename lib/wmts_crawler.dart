import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:proj4dart/proj4dart.dart';

const tileSize = 256;
const originX = -180;
const originY = 31999878;

const resolutions = [
  15624.984375,
  7812.4921875,
  3906.24609375,
  1953.123046875,
  976.5615234375,
  488.28076171875,
  244.140380859375,
  122.0701904296875,
  61.03509521484375,
  30.517547607421875,
  15.258773803710938,
  7.629386901855469,
  3.8146934509277344,
  1.9073467254638672,
  0.9536733627319336,
  0.4768366813659668,
  0.2384183406829834,
  0.1192091703414917,
];

List<int> bboxToTileRange(List<double> bbox, int zoom) {
  final minx = bbox[0];
  final miny = bbox[1];
  final maxx = bbox[2];
  final maxy = bbox[3];
  final res = resolutions[zoom];

  final minCol = ((minx - originX) / (tileSize * res)).floor();
  final maxCol = ((maxx - originX) / (tileSize * res)).floor();
  final minRow = ((originY - maxy) / (tileSize * res)).floor();
  final maxRow = ((originY - miny) / (tileSize * res)).floor();

  return [minCol, maxCol, minRow, maxRow];
}

Future<void> downloadWmtsTile({
  required String baseUrl,
  required String outputFolder,
  required String layer,
  required String style,
  required String matrixSet,
  required int zoom,
  required int col,
  required int row,
  required String sid,
}) async {
  final url =
      "$baseUrl?NCWS=wmtstest&@sid=$sid&layer=$layer&style=$style&tilematrixset=$matrixSet"
      "&Service=WMTS&Request=GetTile&Version=1.0.0&Format=image%2Fpng"
      "&TileMatrix=$zoom&TileCol=$col&TileRow=$row";

  final path = p.join(outputFolder, '$zoom', '$col');
  await Directory(path).create(recursive: true);
  final filePath = p.join(path, '$row.png');

  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      print('✔ Tile z:$zoom x:$col y:$row');
    } else {
      print('✖ Failed z:$zoom x:$col y:$row - ${response.statusCode}');
    }
  } catch (e) {
    print('⚠ Error z:$zoom x:$col y:$row - $e');
  }
}

Future<void> downloadWmtsBboxTiles({
  required List<double> bbox,
  required int minZoom,
  required int maxZoom,
  required String baseUrl,
  required String outputFolder,
  required String sid,
}) async {
  const layer = 'Plan1000';
  const style = 'default';
  const matrixSet = 'Plan1000_7933';

  for (int zoom = minZoom; zoom <= maxZoom; zoom++) {
    final range = bboxToTileRange(bbox, zoom);
    final minCol = range[0], maxCol = range[1], minRow = range[2], maxRow = range[3];

    for (int col = minCol; col <= maxCol; col++) {
      for (int row = minRow; row <= maxRow; row++) {
        await downloadWmtsTile(
          baseUrl: baseUrl,
          outputFolder: outputFolder,
          layer: layer,
          style: style,
          matrixSet: matrixSet,
          zoom: zoom,
          col: col,
          row: row,
          sid: sid,
        );
      }
    }
  }
}

List<double> convertBboxToEPSG7933(List<double> bbox) {
  final sourceCRS = Projection.get('EPSG:4326');
  final targetCRS = Projection.add('EPSG:7933',
      '+proj=tmerc +lat_0=0 +lon_0=33 +k=1 +x_0=500000 +y_0=0 +ellps=GRS80 +units=m +no_defs +towgs84=0,0,0,0,0,0,0');

  final bottomLeft = Point(x: bbox[0], y: bbox[1]);
  final topRight = Point(x: bbox[2], y: bbox[3]);

  final bl = sourceCRS!.transform(targetCRS, bottomLeft);
  final tr = sourceCRS.transform(targetCRS, topRight);

  return [bl.x, bl.y, tr.x, tr.y];
}
