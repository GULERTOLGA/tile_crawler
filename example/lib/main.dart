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

  int minZoomLevel = 14;
  int maxZoomLevel = 18;
  String tileUrlFormat = "http://127.0.0.1:5001/vectors/geoyol/{z}/{x}/{y}.mvt";

  final TextEditingController _minZoomLevelController = TextEditingController();
  final TextEditingController _maxZoomLevelController = TextEditingController();
  final TextEditingController _tileUrlFormatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Set the initial value
    _minZoomLevelController.text = '14';
    _maxZoomLevelController.text = '18';
    _tileUrlFormatController.text = 'http://127.0.0.1:5001/vectors/geoyol/{z}/{x}/{y}.mvt';
  }

  void _incrementCounter() async {
    var dir = await getApplicationDocumentsDirectory();
    //39.898931, 32.701024
    //39.845293, 32.803630

    //36.824855, 31.750683

    //36.223266, 32.354829

    // Create a TextEditingController

    // In your build method

    TileCrawler crawler = TileCrawler(DownloadOptions(
        tileUrlFormat: tileUrlFormat,
        topLeft: LatLng(latitude: 36.824855, longitude: 31.750683),
        bottomRight: LatLng(latitude: 36.223266, longitude: 32.354829),
        minZoomLevel: minZoomLevel,
        downloadFolder: dir.path,
        client: HttpClient(),
        maxZoomLevel: maxZoomLevel));

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
            TextField(
              controller: _tileUrlFormatController,
              decoration: InputDecoration(
                hintText: 'Enter your tile url format',
              ),
              onChanged: (value) {
                setState(() {
                  tileUrlFormat = value;
                });
              },
            ),
            TextField(
              controller:_minZoomLevelController,
              decoration: InputDecoration(
                hintText: 'Enter your min zoom level',
              ),
              onChanged: (value) {
                setState(() {
                  minZoomLevel = int.tryParse(value) ?? 14;
                });
              },
            ),
            TextField(
              controller:_maxZoomLevelController,
              decoration: InputDecoration(
                hintText: 'Enter your max zoom level',
              ),
              onChanged: (value) {
                setState(() {
                  maxZoomLevel =  int.tryParse(value) ?? 18;
                });
              },
            ),
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
