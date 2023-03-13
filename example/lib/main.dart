import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
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
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

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

  void _incrementCounter() async {
    var dir = await getApplicationDocumentsDirectory();
//39.898931, 32.701024
//39.845293, 32.803630
    var endTimeMillis;
    var startTimeMillis = DateTime.now().millisecondsSinceEpoch;

    TileCrawler crawler = TileCrawler(DownloadOptions(
        /*   tileUrlFormat:
            "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90",
            https://mt{s}.google.com/vt/lyrs=m&x={x}&y={y}&z={z}
            ['0', '1', '2', '3']
      */
        tileUrlFormat: "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
        topLeft: LatLng(39.898931, 32.701024),
        bottomRight: LatLng(39.845293, 32.803630),
        minZoomLevel: 17,
        downloadFolder: dir.path,
        client: HttpClient(),
        maxZoomLevel: 18));
    _crawler = crawler;
    crawler.download(
      onStart: (totalTileCount, area) {
        setState(() {
          _tileCount = totalTileCount;
        });
      },
      onProcess: (tileDownloaded, xyz) {
        // log("tileDownloaded: $tileDownloaded, z: $z, x: $x, y: $y");
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
        title: Text(widget.title),
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
