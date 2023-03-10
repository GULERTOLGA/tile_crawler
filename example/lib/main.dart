import 'dart:io';

import 'package:flutter/material.dart';
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
  int _tileDownloaded = 0;
  int _x = 0;
  int _y = 0;
  int _z = 0;

  void _incrementCounter() async {
    var dir = await getApplicationDocumentsDirectory();
//39.898931, 32.701024
//39.845293, 32.803630

    TileCrawler crawler = TileCrawler(DownloadOptions(
        tileUrlFormat:
            "https://ecn.t1.tiles.virtualearth.net/tiles/h{quadkey}.jpeg?g=90",
        topLeft: LatLng(latitude: 39.898931, longitude: 32.701024),
        bottomRight: LatLng(latitude: 39.845293, longitude: 32.803630),
        minZoomLevel: 10,
        downloadFolder: dir.path,
        client: HttpClient(),
        maxZoomLevel: 19));

    crawler.download(
        onStart: (totalTileCount, area) {
          setState(() {
            _tileCount = totalTileCount;
          });
        },
        onProcess: (tileDownloaded, z, x, y) {
          setState(() {
            _tileDownloaded = tileDownloaded;
            _x = x;
            _y = y;
            _z = z;
          });
        },
        onEnd: () {});
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
              '$_tileDownloaded',
              style: Theme.of(context).textTheme.headline4,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
