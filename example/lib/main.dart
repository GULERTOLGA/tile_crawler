import 'package:example/tile_test_screen.dart';
import 'package:flutter/material.dart';
import 'flutter_map_offline_screen.dart';
import 'xyz_download_screen.dart';
import 'wmts_download_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tile Crawler Demo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tile Crawler Demo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Icon(Icons.map, size: 80, color: Colors.blue.shade600),
                  const SizedBox(height: 20),
                  Text(
                    'Tile Crawler Demo',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Harita karolarınızı indirmek için bir seçenek seçin',
                    style: Theme.of(
                      context,
                    )
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: Colors.blue.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  _buildDownloadCard(
                    context,
                    title: 'flutter_map — çevrimdışı demo',
                    subtitle: 'Haritada OSM, indir, yerel HTTP ile offline',
                    description:
                        'Görünür alanı indirip çevrimdışı katmana geçiş',
                    icon: Icons.map_outlined,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => const FlutterMapOfflineScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // XYZ Download Button
                  _buildDownloadCard(
                    context,
                    title: 'XYZ Tile İndirme',
                    subtitle: 'OpenStreetMap, Google Maps vb.',
                    description: 'Standart XYZ formatında harita karoları',
                    icon: Icons.grid_on,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const XYZDownloadScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // WMTS Download Button
                  _buildDownloadCard(
                    context,
                    title: 'WMTS Tile İndirme',
                    subtitle: 'ArcGIS, NetGIS vb.',
                    description: 'WMTS protokolü ile harita karoları',
                    icon: Icons.satellite,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WMTSDownloadScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // WMTS Download Button
                  _buildDownloadCard(
                    context,
                    title: 'Tile Test',
                    subtitle: 'ArcGIS, NetGIS vb.',
                    description: 'Tile test için',
                    icon: Icons.satellite,
                    color: Colors.pink,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TileTestScreen(),
                        ),
                      );
                    },
                  ),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade600,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Her iki seçenek de yüksek performanslı indirme ve otomatik önbellek yönetimi sunar.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: _getDarkerColor(color)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _getDarkerColor(color),
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _getLighterColor(color),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  color: _getLighterColor(color), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods to generate darker/lighter colors
  Color _getDarkerColor(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 0.7).round(),
      (color.green * 0.7).round(),
      (color.blue * 0.7).round(),
    );
  }

  Color _getLighterColor(Color color) {
    return Color.fromARGB(
      color.alpha,
      (color.red * 0.8).round(),
      (color.green * 0.8).round(),
      (color.blue * 0.8).round(),
    );
  }
}
