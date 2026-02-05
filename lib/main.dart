import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const DolomitiSkiApp());
}

class DolomitiSkiApp extends StatelessWidget {
  const DolomitiSkiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dolomiti Superski',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  LatLng userLocation = LatLng(46.5, 11.8); // posizione iniziale di default

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
        _mapController.move(userLocation, 12);
      });
    } catch (e) {
      print("Errore GPS: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dolomiti Superski")),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(initialCenter: userLocation, initialZoom: 12),
        children: [
          TileLayer(
            urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
            subdomains: const ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                width: 40,
                height: 40,
                point: userLocation,
                // qui serve il child, non builder
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
              Marker(
                width: 40,
                height: 40,
                point: LatLng(46.505, 11.81),
                child: const Icon(
                  Icons.downhill_skiing,
                  color: Colors.blue,
                  size: 35,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
