import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tile_crawler/tile_crawler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _tileCount = 0;
  int _tileDownloadedWithErrors = 0;
  int _tileDownloaded = 0;
  int _x = 0;
  int _y = 0;
  int _z = 0;
  TileCrawler? _crawler;
  var startTimeMillis = DateTime.now().millisecondsSinceEpoch;
  var endTimeMillis;
  void _incrementCounter() async {
    var dir = await getApplicationDocumentsDirectory();
//39.898931, 32.701024
//39.845293, 32.803630

    TileCrawler crawler = TileCrawler(DownloadOptions(
      /*   tileUrlFormat:
            "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90",
            https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
            ['0', '1', '2', '3']
      */
      tileProviders: [
        XYZTileUrlProvider(
            "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}", "online"),
        WmsTileUrlProvider(
            (xyz) => WMSTileLayerOptions(
                  baseUrl:
                      'http://91.93.170.251:8080/geoserver/netigmamobil/wms?',
                  version: "1.3.0",
                  transparent: true,
                  layers: ['mahalle'],
                ).getUrl(TileCoordinates(xyz.x, xyz.y, xyz.z), 256, false),
            "wms")
      ],
      topLeft: LatLng(39.898931, 32.701024),
      bottomRight: LatLng(39.845293, 32.803630),
      minZoomLevel: 14,
      downloadFolder: dir.path + "/tiles",
      client: HttpClient(),
      maxZoomLevel: 15,
    ));
    _crawler = crawler;
    crawler.download(
      onStart: (totalTileCount, area) {
        setState(() {
          _tileCount = totalTileCount;
        });
      },
      onProcess: (tileDownloaded, xyz) {
        log("tileDownloaded: $tileDownloaded, z: ${xyz.z}, x: ${xyz.x}, y: ${xyz.y}");
        setState(() {
          _tileDownloaded = tileDownloaded;
          _x = xyz.x;
          _y = xyz.y;
          _z = xyz.z;
        });
      },
      onEnd: () {
        log("end");
        endTimeMillis = DateTime.now().millisecondsSinceEpoch;
        var currentMillisecondsSinceEpoch =
            DateTime.now().millisecondsSinceEpoch - startTimeMillis;
        setState(() {});
        log("time: $currentMillisecondsSinceEpoch");
      },
      onProcessError: (xyz, error, stackTrace) {
        setState(() {
          _tileDownloadedWithErrors++;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Tile Crawler Example"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Total $_tileCount,(z:$_z,x:$_x, y:$_y)  ',
            ),
            Text(
              'Başarılı indirilen tile sayısı\n$_tileDownloaded',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
              'Hatalı indirilen tile sayısı\n $_tileDownloadedWithErrors',
              style: Theme.of(context).textTheme.headline4,
            ),
            Text(
                "Timer ${DateTime.now().millisecondsSinceEpoch - startTimeMillis}")
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FloatingActionButton(
            onPressed: _cancelDownload,
            tooltip: 'Increment',
            child: const Icon(Icons.cancel),
          ),
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        ],
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  void _cancelDownload() {
    _crawler?.cancel();
  }
}
