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
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.blueGrey[900],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      ),
      home: const SkiMapPage(),
    );
  }
}

class SkiMapPage extends StatefulWidget {
  const SkiMapPage({super.key});

  @override
  State<SkiMapPage> createState() => _SkiMapPageState();
}

class _SkiMapPageState extends State<SkiMapPage> with TickerProviderStateMixin {
  LatLng? currentLocation;
  LatLng? lastLocation;
  double heading = 0;
  double mapRotation = 0;
  double currentZoom = 14;
  bool isScenic = false; // stato dello switch
  late final MapController mapController;
  late final AnimationController _markerController;
  late final DraggableScrollableController sheetController;

  // --- sistema menu attivo ---
  String activeMenu = ''; // '', 'resorts', 'navigator', 'home', etc.

  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();

  final Map<String, LatLng> comprensoriMap = {
    "Cortina d'Ampezzo": LatLng(46.54, 12.14),
    "Plan de Corones": LatLng(46.71, 11.65),
    "Alta Badia": LatLng(46.49, 11.87),
    "Val Gardena/Alpe di Siusi": LatLng(46.55, 11.70),
    "Val di Fassa/Carezza": LatLng(46.42, 11.70),
    "Arabba/Marmolada": LatLng(46.43, 11.78),
    "3 Cime Dolomiti": LatLng(46.63, 12.30),
    "Val di Fiemme/Obereggen": LatLng(46.30, 11.38),
    "San Martino di Castrozza/Passo Rolle": LatLng(46.33, 11.73),
    "Rio Pusteria/Bressanone": LatLng(46.83, 11.65),
    "Alpe Lusia/San Pellegrino": LatLng(46.40, 11.73),
    "Civetta": LatLng(46.45, 12.00),
  };

  List<String> get comprensori => comprensoriMap.keys.toList();
  List<TextEditingController> intermediateControllers =
      []; // lista per le tappe intermedie

  final LatLngBounds dolomitiBounds = LatLngBounds(
    LatLng(45.95, 10.85), // SW
    LatLng(46.75, 12.40), // NE
  );

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    sheetController = DraggableScrollableController();
    _determinePosition();

    _markerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    FlutterCompass.events?.listen((event) {
      if (event.heading != null) setState(() => heading = event.heading!);
    });

    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((position) {
      final newLocation = LatLng(position.latitude, position.longitude);
      if (!dolomitiBounds.contains(newLocation)) return;

      setState(() => currentLocation = newLocation);
      _markerController.forward(from: 0);

      if (lastLocation == null ||
          Distance().as(LengthUnit.Meter, lastLocation!, newLocation) > 3) {
        lastLocation = newLocation;
        mapController.move(newLocation, currentZoom);
      }
    });
  }

  Future<void> _determinePosition() async {
    final fallback = LatLng(46.45, 11.75);

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

  void _goToDestination() {
    final dest = endController.text;
    final target = comprensoriMap[dest];
    if (target != null) {
      mapController.move(target, 14);
      setState(() {
        activeMenu = '';
        startController.clear();
        endController.clear();
      });
      sheetController.animateTo(
        0.12,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Destinazione non trovata')));
    }
  }

  @override
  void dispose() {
    _markerController.dispose();
    startController.dispose();
    endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const mapTilerKey = 'k2jksKCxeEV932oPOyNo';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Dolomiti Ski Map'),
        centerTitle: true,
        backgroundColor: Colors.black.withOpacity(0.3),
      ),
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator(color: Colors.cyan))
          : Stack(
              children: [
                // --- TAP SULLA MAPPA ---
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (activeMenu != '') {
                      setState(() {
                        activeMenu = '';
                        sheetController.animateTo(
                          0.12,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      });
                    }
                  },
                  child: FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation!,
                      initialZoom: currentZoom,
                      minZoom: 11,
                      maxZoom: 18,
                      cameraConstraint: CameraConstraint.contain(
                        bounds: dolomitiBounds,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://api.maptiler.com/maps/winter/{z}/{x}/{y}.png?key=$mapTilerKey",
                        userAgentPackageName: 'com.example.dolomiti_ski_app',
                      ),
                      TileLayer(
                        urlTemplate:
                            "https://tiles.opensnowmap.org/pistes/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.example.dolomiti_ski_app',
                        tileBuilder: (context, tileWidget, tile) =>
                            Opacity(opacity: 0.95, child: tileWidget),
                      ),
                      MarkerLayer(
                        markers: [
                          if (currentLocation != null)
                            Marker(
                              point: currentLocation!,
                              width: 50,
                              height: 50,
                              child: ScaleTransition(
                                scale: Tween(begin: 0.7, end: 1.0).animate(
                                  CurvedAnimation(
                                    parent: _markerController,
                                    curve: Curves.elasticOut,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.cyanAccent,
                                        Colors.blueAccent,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.cyanAccent,
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.my_location,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // --- BUSSOLA ---
                Positioned(
                  top: kToolbarHeight + 30,
                  right: 16,
                  child: CompassWidget(
                    heading: heading,
                    mapRotation: mapRotation,
                    onTap: resetMapRotation,
                  ),
                ),

                // --- MENU SCORRIBILE ---
                DraggableScrollableSheet(
                  controller: sheetController,
                  initialChildSize: 0.12,
                  minChildSize: 0.12, // ← blocca l'abbassamento manuale
                  maxChildSize: 0.6,
                  snap:
                      false, // possiamo togliere il "snap" per avere controllo totale
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 10),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.map, // ← cambia qui da home a map
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      activeMenu =
                                          ''; // chiude qualsiasi menu aperto
                                      sheetController.animateTo(
                                        0.12, // abbassa il menu
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.terrain,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      activeMenu = 'resorts';
                                      sheetController.animateTo(
                                        0.5,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.access_time,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      activeMenu = 'time';
                                      sheetController.animateTo(
                                        0.12,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.navigation,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      activeMenu = 'navigator';
                                      sheetController.animateTo(
                                        0.6,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeOut,
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),

                          // --- contenuto menu ---
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            child: SizedBox(
                              height: activeMenu == ''
                                  ? 0
                                  : activeMenu == 'resorts'
                                  ? 250
                                  : activeMenu == 'navigator'
                                  ? 300
                                  : 150,
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                children: [
                                  if (activeMenu == 'resorts')
                                    ...comprensori.map(
                                      (resort) => GestureDetector(
                                        onTap: () {
                                          final target = comprensoriMap[resort];
                                          if (target != null) {
                                            mapController.move(target, 14);
                                          }
                                        },
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 6,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                            horizontal: 16,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.blueAccent.withOpacity(
                                                  0.7,
                                                ),
                                                Colors.cyanAccent.withOpacity(
                                                  0.7,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            resort,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (activeMenu == 'navigator') ...[
                                    const SizedBox(height: 16),
                                    const Text(
                                      'Navigatore',
                                      style: TextStyle(
                                        color: Colors.cyanAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // PARTENZA
                                    TextField(
                                      controller: startController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Partenza',
                                        hintStyle: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black38,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.my_location,
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // TAPPE INTERMEDIE
                                    ...intermediateControllers.asMap().entries.map((
                                      entry,
                                    ) {
                                      int index = entry.key;
                                      TextEditingController ctrl = entry.value;
                                      return Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: ctrl,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Tappa intermedia ${index + 1}',
                                                hintStyle: const TextStyle(
                                                  color: Colors.white54,
                                                ),
                                                filled: true,
                                                fillColor: Colors.black38,
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  borderSide: BorderSide.none,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.place,
                                                  color: Colors.cyanAccent,
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () {
                                              setState(() {
                                                intermediateControllers
                                                    .removeAt(index);
                                              });
                                            },
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),

                                    // PULSANTE AGGIUNGI TAPPA
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              intermediateControllers.add(
                                                TextEditingController(),
                                              );
                                            });
                                          },
                                          icon: const Icon(
                                            Icons.add,
                                            color: Colors.cyanAccent,
                                            size: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // ARRIVO
                                    TextField(
                                      controller: endController,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Destinazione',
                                        hintStyle: const TextStyle(
                                          color: Colors.white54,
                                        ),
                                        filled: true,
                                        fillColor: Colors.black38,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.flag,
                                          color: Colors.cyanAccent,
                                        ),
                                      ),
                                      onSubmitted: (_) => _goToDestination(),
                                    ),
                                    const SizedBox(height: 8),

                                    // SWITCH PANORAMICO / VELOCE
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'Percorso panoramico',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Switch(
                                          value: isScenic,
                                          onChanged: (value) {
                                            setState(() {
                                              isScenic = value;
                                            });
                                          },
                                          activeColor: Colors.cyanAccent,
                                        ),
                                        const Text(
                                          'Percorso veloce',
                                          style: TextStyle(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    // PULSANTE VAI
                                    ElevatedButton(
                                      onPressed: _goToDestination,
                                      child: const Text('Vai'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          Expanded(
                            child: SafeArea(
                              top: false, // non aggiunge padding sopra
                              child: ListView(
                                controller: scrollController,
                                children: const [
                                  ListTile(
                                    leading: Icon(
                                      Icons.info,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      'Informazioni piste',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  ListTile(
                                    leading: Icon(
                                      Icons.settings,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      'Impostazioni',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

// ================= BUSSOLA MODERNA =================
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
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Colors.cyanAccent, blurRadius: 4, spreadRadius: 1),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.rotate(
              angle: -mapRotation * pi / 180,
              child: CustomPaint(
                size: const Size(70, 70),
                painter: _CompassPainterModern(),
              ),
            ),
            Text(
              _cardinal(angle < 0 ? angle + 360 : angle),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
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

class _CompassPainterModern extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    canvas.drawCircle(c, r, Paint()..color = Colors.black.withOpacity(0.5));

    for (int i = 0; i < 360; i += 15) {
      final a = i * pi / 180;
      final len = i % 90 == 0 ? 10.0 : 5.0;
      final p1 = Offset(c.dx + (r - len) * cos(a), c.dy + (r - len) * sin(a));
      final p2 = Offset(c.dx + r * cos(a), c.dy + r * sin(a));

      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = i == 0 ? Colors.cyanAccent : Colors.white70
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
