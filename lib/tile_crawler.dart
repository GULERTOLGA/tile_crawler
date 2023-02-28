library tile_crawler;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:tile_crawler/model/crawler_summary.dart';
import 'package:tile_crawler/tile_crawler_helper.dart';
part 'model/xyz.dart';
part 'model/download_options.dart';
part 'model/rectangle.dart';
part 'model/lat_lng.dart';
part 'model/download_status.dart';
part 'model/map_providers.dart';
//https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
//https://a.tile.openstreetmap.org/{z}/{x}/{y}.png
//https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90

typedef OnStart = void Function(int totalTileCount, double area);

typedef OnProcess = void Function(int tileDownloaded, int z, int x, int y);
typedef OnEnd = void Function();
typedef OnComplete = void Function(bool success, XYZ xyz);

class TileCrawler with TileCrawlerHelper {
  int tileCount = 0;
  double _area = 0;
  final DownloadOptions options;
  static final List<XYZ> _queue = [];
  static int _completedIsolateCount = 0;
  static int installedTileCount = 0;
  TileCrawler(this.options);

  bool _cancel = false;
  void onInitial() {
    for (int z = options.minZoomLevel; z <= options.maxZoomLevel; z++) {
      calculateRectIN(calculateRect(options.topLeft, options.bottomRight, z));
    }
  }

  TileCrawlerSummary getCrawlerSummary() {
    onInitial();
    return TileCrawlerSummary(getArea(), tileCount);
  }

  double getArea() {
    _area = calculateArea(options.topLeft.latitude, options.topLeft.longitude,
        options.bottomRight.latitude, options.bottomRight.longitude);
    return _area;
  }

  Future<void> download(
      {OnStart? onStart, OnProcess? onProcess, OnEnd? onEnd}) async {
    _queue.clear();
    _cancel = false;
    onInitial();
    if (onStart != null) {
      onStart(_queue.length, _area);
    }
    downloadWithIsolate(onStart, onProcess, onEnd);
  }

  void cancel() {
    _cancel = true;
    _queue.clear();
  }

  Future<void> downloadWithIsolate(
      OnStart? onStart, OnProcess? onProcess, OnEnd? onEnd) async {
    var startCount = _queue.length;
    installedTileCount = startCount;
    _completedIsolateCount = 0;
    int concurrent = 10;
    int remainingValue = startCount % concurrent;
    int divisorValue = (startCount - remainingValue) ~/ (concurrent - 1);

    List parsedList = [];

    for (int i = 0; i < concurrent; i++) {
      if (i == concurrent - 1) {
        parsedList.add(_queue.sublist(i * divisorValue, startCount));
      } else {
        parsedList.add(
            _queue.sublist(i * divisorValue, i * divisorValue + divisorValue));
      }
    }

    for (var i = 0; i < concurrent; i++) {
      final receivePort = ReceivePort();
      Isolate.spawn(_download, {
        'sendPort': receivePort.sendPort,
        'xyzList': parsedList[i],
        'client': options.client,
      });
      receivePort.listen((message) {
        if (message is DownloadStatus) {
          if (message.status == DownloadStatusEnum.completed) {
            _completedIsolateCount++;
            dev.log("$_completedIsolateCount",
                name: "TileCrawler:completed", level: 2000);
            if (_completedIsolateCount == concurrent) {
              if (onEnd != null) {
                onEnd.call();
              }
            }
          } else if (message.status == DownloadStatusEnum.error) {
            if (onEnd != null) {
              onEnd.call();
            }
          } else if (message.status == DownloadStatusEnum.downloading) {
            if (onProcess != null) {
              dev.log(message.xyz.toString(),
                  name: "TileCrawler:downloaded", level: 500);
              onProcess.call(
                _queue.length - --installedTileCount,
                message.xyz!.z,
                message.xyz!.x,
                message.xyz!.y,
              );
            }
          }
        }
      });
    }
  }

  void _download(Map<String, dynamic> message) async {
    final xyzList = message['xyzList'] as List<XYZ>;
    final sendPort = message['sendPort'] as SendPort;
    final client = message['client'] as HttpClient;
    try {
      while (!_cancel && xyzList.isNotEmpty) {
        var current = xyzList.removeLast();
        var url = options.tileUrlFormat.toLowerCase();
        if (url.contains("{quadkey}")) {
          url = url.replaceAll("{quadkey}", current.toQuadKey());
        } else {
          url = url
              .replaceAll("{x}", current.x.toString())
              .replaceAll("{y}", current.y.toString())
              .replaceAll("{z}", current.z.toString());
        }

        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final String pathString =
            "${options.downloadFolder}/${current.z}/${current.x}";
        final dirPath = await Directory(pathString).create(recursive: true);
        await response
            .pipe(File('${dirPath.path}/${current.y}.png').openWrite());
        sendPort.send(DownloadStatus.downloading(current));
      }
      sendPort.send(DownloadStatus.completed());
    } catch (e) {
      dev.log(e.toString(), name: "TileCrawler:error", level: 1000, error: e);
      sendPort.send(DownloadStatus.error(e.toString()));
    }
  }
}
