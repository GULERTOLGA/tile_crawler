library tile_crawler;

import 'dart:async';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

//https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
//https://a.tile.openstreetmap.org/{z}/{x}/{y}.png
//https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90

typedef OnStart = void Function(int totalTileCount, double area);

typedef OnProcess = void Function(int tileDownloaded, int z, int x, int y);
typedef OnEnd = void Function();
typedef OnComplete = void Function(bool success, _XYZ xyz);

class TileCrawler {
  final int tileSize = 256;
  final DownloadOptions options;
  final List<_XYZ> _queue = [];
  static int _completedIsolateCount = 0;
  static int installedTileCount = 0;
  TileCrawler(this.options);

  bool _cancel = false;

  Future<void> download(
      {OnStart? onStart, OnProcess? onProcess, OnEnd? onEnd}) async {
    _queue.clear();
    _cancel = false;
    for (int z = options.minZoomLevel; z <= options.maxZoomLevel; z++) {
      _calculateRectIN(_calculateRect(options.topLeft, options.bottomRight, z));
    }
    downloadWithIsolate(onStart, onProcess, onEnd);
  }

  void cancel() {
    _cancel = true;
    _queue.clear();
  }

  _Rectangle _calculateRect(LatLng topLeft, LatLng bottomRight, int level) {
    _XYZ topLeftTile =
        _calculateXYZ(topLeft.latitude, topLeft.longitude, level);

    _XYZ bottomRightTile =
        _calculateXYZ(bottomRight.latitude, bottomRight.longitude, level);

    return _Rectangle(
        startX: topLeftTile.x,
        startY: topLeftTile.y,
        endX: bottomRightTile.x,
        endY: bottomRightTile.y,
        level: level);
  }

  _XYZ _calculateXYZ(double latitude, double longitude, level) {
    var sinLat = sin(latitude * pi / 180);
    var pixelX = ((longitude + 180) / 360) * tileSize * pow(2, level);
    var pixelY = (0.5 - log((1 + sinLat) / (1 - sinLat)) / (4 * pi)) *
        tileSize *
        pow(2, level);

    return _XYZ(
        x: (pixelX / tileSize).floor(),
        y: (pixelY / tileSize).floor(),
        z: level);
  }

  _calculateRectIN(_Rectangle rect) {
    for (int x = rect.startX; x <= rect.endX; x++) {
      for (int y = rect.startY; y <= rect.endY; y++) {
        var xyz = _XYZ(x: x, y: y, z: rect.level);

        _queue.add(xyz);
      }
    }
  }

  Future<void> downloadWithoutIsolate(_XYZ current) async {
    var url = options.tileUrlFormat.toLowerCase();
    if (url.contains("{quadkey}")) {
      url = url.replaceAll("{quadkey}", current.toQuadKey());
    } else {
      url = url
          .replaceAll("{x}", current.x.toString())
          .replaceAll("{y}", current.y.toString())
          .replaceAll("{z}", current.z.toString());
    }
    final request = await options.client.getUrl(Uri.parse(url));
    final response = await request.close();
    final String pathString =
        "${options.downloadFolder}/${current.z}/${current.x}";
    final dirPath = await Directory(pathString).create(recursive: true);
    await response.pipe(File('${dirPath.path}/${current.y}.png').openWrite());
  }

  Future<void> downloadWithIsolate(
      OnStart? onStart, OnProcess? onProcess, OnEnd? onEnd) async {
    var startCount = 255;
    installedTileCount = startCount;
    _completedIsolateCount = 0;
    int concurrent = 10;
    int remainingValue = startCount % concurrent;
    int divisorValue = (startCount - remainingValue) ~/ (concurrent - 1);

    List parsedList = [];
    onStart?.call(startCount, 1500.0);
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
              print(installedTileCount);
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
    final xyzList = message['xyzList'] as List<_XYZ>;
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

class LatLng {
  final double latitude;
  final double longitude;
  LatLng({required this.latitude, required this.longitude});
}

class DownloadOptions {
  final LatLng topLeft;
  final LatLng bottomRight;
  final int minZoomLevel;
  final int maxZoomLevel;
  final String tileUrlFormat;
  final String downloadFolder;
  final HttpClient client;

  DownloadOptions(
      {required this.topLeft,
      required this.bottomRight,
      required this.minZoomLevel,
      required this.maxZoomLevel,
      required this.tileUrlFormat,
      HttpClient? client,
      required this.downloadFolder})
      : client = client ?? HttpClient();
}

class _Rectangle {
  final int startX;
  final int startY;
  final int endX;
  final int endY;
  final int level;

  _Rectangle(
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

class _XYZ {
  final int x;
  final int y;
  final int z;

  _XYZ({required this.x, required this.y, required this.z});

  _XYZ copyWith({int? x, int? y, int? z}) =>
      _XYZ(x: x ?? this.x, y: y ?? this.y, z: z ?? this.z);

  String toQuadKey() {
    var quadKey = [];
    for (var i = z; i > 0; i--) {
      var digit = 0;
      var mask = 1 << (i - 1);
      if ((x & mask) != 0) {
        digit++;
      }
      if ((y & mask) != 0) {
        digit++;
        digit++;
      }
      quadKey.add(digit);
    }
    return quadKey.join('');
  }

  @override
  String toString() {
    return "$z/$x/$y";
  }
}

class MapProviders {
  static const String googleStreets =
      "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}";

  static const String openStreetMap =
      "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png";

  static const String bingSattellite =
      "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90";
}

enum DownloadStatusEnum { downloading, completed, error }

class DownloadStatus {
  final DownloadStatusEnum status;
  final _XYZ? xyz;
  final Object? error;

  DownloadStatus({required this.status, this.xyz, this.error});

  factory DownloadStatus.completed() =>
      DownloadStatus(status: DownloadStatusEnum.completed);
  factory DownloadStatus.error(String error) =>
      DownloadStatus(status: DownloadStatusEnum.error, error: error);
  factory DownloadStatus.downloading(_XYZ xyz) =>
      DownloadStatus(status: DownloadStatusEnum.downloading, xyz: xyz);
}
