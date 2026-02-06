import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Dolomiti Ski Map',
      theme: ThemeData.dark(),
      home: const SkiMapPage(),
    );
  }
}

class SkiMapPage extends StatefulWidget {
  const SkiMapPage({super.key});

  @override
  State<SkiMapPage> createState() => _SkiMapPageState();
}

class _SkiMapPageState extends State<SkiMapPage> {
  LatLng? currentLocation;
  double heading = 0; // Direzione reale
  double mapRotation = 0; // Rotazione della mappa
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _determinePosition();

    // Aggiorna heading dal sensore
    FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() {
          heading = event.heading!;
        });
      }
    });
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      currentLocation = LatLng(position.latitude, position.longitude);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentLocation != null) {
        mapController.move(currentLocation!, 14);
      }
    });
  }

  // Tap sulla bussola riallinea al nord
  void resetMapRotation() {
    setState(() {
      mapRotation = 0; // Aggiorna stato
      mapController.rotate(0); // Imposta la rotazione della mappa a nord
    });
  }

  @override
  Widget build(BuildContext context) {
    const String mapTilerKey = 'k2jksKCxeEV932oPOyNo';

    return Scaffold(
      appBar: AppBar(title: const Text('Dolomiti Ski Map'), centerTitle: true),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: currentLocation!,
                    initialZoom: 14,
                    minZoom: 5,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          "https://api.maptiler.com/maps/basic/{z}/{x}/{y}.png?key=$mapTilerKey",
                      userAgentPackageName: 'com.example.dolomiti_ski_app',
                    ),
                    TileLayer(
                      urlTemplate:
                          "https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.dolomiti_ski_app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: currentLocation!,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blueAccent,
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // Bussola in alto a destra con rilevamento orientamento
                Positioned(
                  top: 16,
                  right: 16,
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      double screenRotation = 0;
                      if (orientation == Orientation.landscape) {
                        screenRotation = pi / 2; // 90° in radianti
                      }
                      return Transform.rotate(
                        angle: screenRotation,
                        child: CompassWidget(
                          heading: heading,
                          mapRotation: mapRotation,
                          onTap: resetMapRotation,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ====================== BUSSOLA INTERATTIVA ======================
class CompassWidget extends StatelessWidget {
  final double heading; // Heading reale dal sensore
  final double mapRotation; // Rotazione mappa
  final VoidCallback onTap; // Azione al click sulla bussola

  const CompassWidget({
    super.key,
    required this.heading,
    required this.mapRotation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Differenza tra nord e direzione mappa
    final angleDiff = (heading - mapRotation) % 360;
    final centralCardinal = _angleToCardinal(
      angleDiff < 0 ? angleDiff + 360 : angleDiff,
    );

    return GestureDetector(
      onTap: onTap, // Riallinea mappa al nord
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Corona esterna che ruota con la mappa
            Transform.rotate(
              angle: -mapRotation * pi / 180,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: _CompassCirclePainter(),
              ),
            ),
            // Lettera dinamica al centro
            Text(
              centralCardinal,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _angleToCardinal(double angle) {
    // 16 punti cardinali (22.5° ciascuno)
    if (angle >= 348.75 || angle < 11.25) return 'N';
    if (angle >= 11.25 && angle < 33.75) return 'NNE';
    if (angle >= 33.75 && angle < 56.25) return 'NE';
    if (angle >= 56.25 && angle < 78.75) return 'ENE';
    if (angle >= 78.75 && angle < 101.25) return 'E';
    if (angle >= 101.25 && angle < 123.75) return 'ESE';
    if (angle >= 123.75 && angle < 146.25) return 'SE';
    if (angle >= 146.25 && angle < 168.75) return 'SSE';
    if (angle >= 168.75 && angle < 191.25) return 'S';
    if (angle >= 191.25 && angle < 213.75) return 'SSW';
    if (angle >= 213.75 && angle < 236.25) return 'SW';
    if (angle >= 236.25 && angle < 258.75) return 'WSW';
    if (angle >= 258.75 && angle < 281.25) return 'W';
    if (angle >= 281.25 && angle < 303.75) return 'WNW';
    if (angle >= 303.75 && angle < 326.25) return 'NW';
    return 'NNW';
  }
}

class _CompassCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paintCircle = Paint()
      ..color = Colors.black87
      ..style = PaintingStyle.fill;

    final paintBorder = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // Cerchio esterno
    canvas.drawCircle(center, radius, paintCircle);
    canvas.drawCircle(center, radius, paintBorder);

    // Tacchette della bussola
    final paintTick = Paint()..strokeWidth = 1.5;

    for (int i = 0; i < 360; i += 15) {
      final angle = i * pi / 180;
      final tickLength = (i % 90 == 0) ? 10.0 : (i % 45 == 0 ? 6.0 : 4.0);

      final start = Offset(
        center.dx + (radius - tickLength - 4) * cos(angle),
        center.dy + (radius - tickLength - 4) * sin(angle),
      );
      final end = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      // Tacchetta nord fissa in rosso, le altre bianche
      paintTick.color = (i == 0) ? Colors.red : Colors.white;
      canvas.drawLine(start, end, paintTick);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
