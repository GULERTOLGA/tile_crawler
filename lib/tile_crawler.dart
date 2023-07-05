library tile_crawler;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:latlong2/latlong.dart';
import 'package:tile_crawler/model/crawler_summary.dart';
import 'package:tile_crawler/tile_crawler_helper.dart';
part 'model/xyz.dart';
part 'model/download_options.dart';
part 'model/rectangle.dart';

part 'model/download_status.dart';
part 'model/map_providers.dart';
//https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
//https://a.tile.openstreetmap.org/{z}/{x}/{y}.png
//https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90

typedef OnStart = void Function(int totalTileCount, double area);

typedef OnProcess = void Function(int tileDownloaded, XYZ xyz);
typedef OnProcessError = void Function(
    XYZ xyz, Object error, StackTrace stackTrace);
typedef OnEnd = void Function();
typedef OnComplete = void Function(bool success, XYZ xyz);

class TileCrawler {
  int tileCount = 0;

  final DownloadOptions options;
  static final List<XYZ> _queue = [];
  static int _completedIsolateCount = 0;
  static int allTileCount = 0;
  static int installedTileCount = 0;
  TileCrawler(this.options);
  static final List<ReceivePort?> _isolateList = [];
  bool _cancel = false;

  Future<void> download(
      {OnStart? onStart,
      OnProcess? onProcess,
      OnEnd? onEnd,
      OnProcessError? onProcessError}) async {
    _queue.clear();
    _cancel = false;
    _queue.addAll(await options.queue);
    allTileCount = _queue.length * options.tileProviders.length;
    if (onStart != null) {
      onStart(allTileCount, options.area);
    }
    _downloadWithIsolate(onStart, onProcess, onEnd, onProcessError);
  }

  void cancel() {
    _cancel = true;
    dev.log("Cancelled isolate: ${_isolateList.length}",
        name: "TileCrawler:cancelled", level: 1800);
    for (var element in _isolateList) {
      element?.close();
    }
    _isolateList.clear();
    _queue.clear();
  }

  /// Returns the optimal thread count for the current platform.

  int getOptimumThreadCount(int tileCount) {
    final int availableProcessors = Platform.numberOfProcessors;
    if (tileCount < (availableProcessors * availableProcessors)) {
      return (availableProcessors / 2).ceil();
    } else {
      var threadCount = (tileCount / availableProcessors).ceil();
      var maxThreadCount = availableProcessors * 3;
      return threadCount < maxThreadCount ? threadCount : maxThreadCount;
    }
  }

  Future<void> _downloadWithIsolate(OnStart? onStart, OnProcess? onProcess,
      OnEnd? onEnd, OnProcessError? onProcessError) async {
    var startCount = _queue.length;
    installedTileCount = allTileCount;
    _completedIsolateCount = 0;
    int concurrent = getOptimumThreadCount(startCount);
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
      if (_cancel) break;

      final receivePort = ReceivePort();
      Isolate.spawn<IsolateDispatcher>(
          _download,
          IsolateDispatcher(
              parsedList[i], receivePort.sendPort, options.client));
      _isolateList.add(receivePort);
      receivePort.listen((message) {
        if (message is DownloadStatus) {
          dev.log(message.toString());
          if (message.status == DownloadStatusEnum.completed) {
            _completedIsolateCount++;
            Future.microtask(() {
              dev.log("$_completedIsolateCount",
                  name: "TileCrawler:completed", level: 1700);
              receivePort.close();
            });
            if (_completedIsolateCount == concurrent) {
              if (onEnd != null) {
                onEnd.call();
              }
            }
          } else if (message.status == DownloadStatusEnum.error) {
            if (onProcess != null) {
              dev.log(message.error.toString(),
                  name: "TileCrawler:error",
                  level: 2000,
                  error: message.error.toString() + message.xyz.toString());
              onProcess.call(
                allTileCount - --installedTileCount,
                message.xyz!,
              );
            }
            if (onProcessError != null) {
              onProcessError.call(
                  message.xyz!, message.error!, message.stackTrace!);
            }
          } else if (message.status == DownloadStatusEnum.downloading) {
            if (onProcess != null) {
              Future.microtask(() {
                dev.log(message.xyz.toString(),
                    name: "TileCrawler:downloaded", level: 500);
                onProcess.call(
                  allTileCount - --installedTileCount,
                  message.xyz!,
                );
              });
            }
          }
        }
      });
    }
  }

  void _download(IsolateDispatcher dispatcher) async {
    final xyzList = dispatcher.xyzList;
    final sendPort = dispatcher.sendPort;
    final client = dispatcher.client;
    while (!_cancel && xyzList.isNotEmpty) {
      var current = xyzList.removeLast();
      for (var tileProvider in options.tileProviders) {
        try {
          String url = tileProvider.tileUrlFormat(current).toLowerCase();
          dev.log(tileProvider.providerKey,
              name: "TileCrawler:key", level: 1000);
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
              "${options.downloadFolder}/${tileProvider.providerKey}/${current.z}/${current.x}";
          final dirPath = await Directory(pathString).create(recursive: true);
          await response
              .pipe(File('${dirPath.path}/${current.y}.png').openWrite());
          sendPort.send(DownloadStatus.downloading(current));
        } catch (e, s) {
          sendPort.send(DownloadStatus.error(e, s, current));
        }
      }
    }
    sendPort.send(DownloadStatus.completed());
  }
}

class IsolateDispatcher {
  final List<XYZ> xyzList;
  final SendPort sendPort;
  final HttpClient client;
  IsolateDispatcher(this.xyzList, this.sendPort, this.client);
}
