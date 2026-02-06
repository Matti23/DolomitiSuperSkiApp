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
  LatLng? lastLocation;

  double heading = 0;
  double mapRotation = 0;
  double currentZoom = 14;

  late final MapController mapController;

  // 🔒 BOUNDS DOLOMITI SUPERSKI
  final LatLngBounds dolomitiBounds = LatLngBounds(
    LatLng(45.95, 10.85), // Sud-Ovest
    LatLng(46.75, 12.40), // Nord-Est
  );

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _determinePosition();

    // Bussola
    FlutterCompass.events?.listen((event) {
      if (event.heading != null) {
        setState(() => heading = event.heading!);
      }
    });

    // GPS continuo
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((position) {
      final newLocation = LatLng(position.latitude, position.longitude);

      if (!dolomitiBounds.contains(newLocation)) return;

      setState(() => currentLocation = newLocation);

      if (lastLocation == null ||
          Distance().as(LengthUnit.Meter, lastLocation!, newLocation) > 3) {
        lastLocation = newLocation;
        mapController.move(newLocation, currentZoom);
      }
    });
  }

  Future<void> _determinePosition() async {
    final fallback = LatLng(46.45, 11.75); // centro Dolomiti Superski

    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => currentLocation = fallback);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => currentLocation = fallback);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() => currentLocation = fallback);
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final loc = LatLng(position.latitude, position.longitude);

      setState(
        () => currentLocation = dolomitiBounds.contains(loc) ? loc : fallback,
      );
      lastLocation = currentLocation;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(currentLocation!, currentZoom);
      });
    } catch (_) {
      setState(() => currentLocation = fallback);
    }
  }

  void resetMapRotation() {
    setState(() {
      mapRotation = 0;
      mapController.rotate(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    const mapTilerKey = 'k2jksKCxeEV932oPOyNo';

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
                    initialZoom: currentZoom,
                    minZoom: 11,
                    maxZoom: 18,

                    // 🔒 BLOCCO AREA DOLOMITI
                    cameraConstraint: CameraConstraint.contain(
                      bounds: dolomitiBounds,
                    ),

                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    // ❄️ MAPPA INVERNALE
                    TileLayer(
                      urlTemplate:
                          "https://api.maptiler.com/maps/winter/{z}/{x}/{y}.png?key=$mapTilerKey",
                      userAgentPackageName: 'com.example.dolomiti_ski_app',
                    ),

                    // 🎿 PISTE DA SCI
                    TileLayer(
                      urlTemplate:
                          "https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png",
                      userAgentPackageName: 'com.example.dolomiti_ski_app',
                      tileBuilder: (context, tileWidget, tile) =>
                          Opacity(opacity: 0.95, child: tileWidget),
                    ),

                    // 📍 POSIZIONE
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

                // 🧭 BUSSOLA
                Positioned(
                  top: 16,
                  right: 16,
                  child: CompassWidget(
                    heading: heading,
                    mapRotation: mapRotation,
                    onTap: resetMapRotation,
                  ),
                ),
              ],
            ),
    );
  }
}

// ================= BUSSOLA =================

class CompassWidget extends StatelessWidget {
  final double heading;
  final double mapRotation;
  final VoidCallback onTap;

  const CompassWidget({
    super.key,
    required this.heading,
    required this.mapRotation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final angle = (heading - mapRotation) % 360;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -mapRotation * pi / 180,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: _CompassPainter(),
              ),
            ),
            Text(
              _cardinal(angle < 0 ? angle + 360 : angle),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _cardinal(double a) {
    const dirs = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    return dirs[((a + 11.25) % 360 ~/ 22.5)];
  }
}

class _CompassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = Colors.black87);

    for (int i = 0; i < 360; i += 15) {
      final a = i * pi / 180;
      final len = i % 90 == 0 ? 10.0 : 5.0;
      final p1 = Offset(c.dx + (r - len) * cos(a), c.dy + (r - len) * sin(a));
      final p2 = Offset(c.dx + r * cos(a), c.dy + r * sin(a));

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = i == 0 ? Colors.red : Colors.white
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
