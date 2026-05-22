import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class MapScreen extends StatefulWidget {
  final String patientId;
  const MapScreen({Key? key, required this.patientId}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  double patientLat = 36.8065;
  double patientLng = 10.1815;
  bool isInZone = true;

  LatLng zoneCenter = LatLng(36.8065, 10.1815);
  double zoneRadius = 100;

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  bool isSaving = false;
  bool isSearching = false;
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadGeofence();
    _subscribeToGPS();
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() { isSearching = true; searchResults = []; });

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'json', 'limit': '5', 'addressdetails': '1'},
        options: Options(headers: {'User-Agent': 'SeniorCareAI/1.0'}),
      );

      final results = response.data as List;
      setState(() {
        searchResults = results.map((r) => {'name': r['display_name'], 'lat': double.parse(r['lat']), 'lng': double.parse(r['lon'])}).toList();
        isSearching = false;
      });
    } catch (e) {
      setState(() => isSearching = false);
    }
  }

  void _selectLocation(Map<String, dynamic> result) {
    final newCenter = LatLng(result['lat'], result['lng']);
    setState(() { zoneCenter = newCenter; searchResults = []; _searchController.clear(); });
    _mapController.move(newCenter, 16);
  }

  Future<void> _loadGeofence() async {
    try {
      final patient = await Supabase.instance.client
          .from('patients')
          .select('geofence_lat, geofence_lng, geofence_radius')
          .eq('id', widget.patientId)
          .maybeSingle();

      if (patient != null && patient['geofence_lat'] != null) {
        setState(() {
          zoneCenter = LatLng(
            double.parse(patient['geofence_lat'].toString()),
            double.parse(patient['geofence_lng'].toString()),
          );
          zoneRadius = double.parse(patient['geofence_radius'].toString());
        });
        _mapController.move(zoneCenter, 16);
      }
    } catch (e) {}
  }

  Future<void> _saveGeofence() async {
    setState(() => isSaving = true);
    try {
      await Supabase.instance.client
          .from('patients')
          .update({'geofence_lat': zoneCenter.latitude, 'geofence_lng': zoneCenter.longitude, 'geofence_radius': zoneRadius})
          .eq('id', widget.patientId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Zone sauvegardée !"), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  void _subscribeToGPS() {
    Supabase.instance.client
        .from('vitals')
        .stream(primaryKey: ['id'])
        .eq('patient_id', widget.patientId)
        .order('timestamp', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            final lat = data[0]['gps_lat'];
            final lng = data[0]['gps_lng'];
            if (lat != null && lng != null) {
              setState(() {
                patientLat = double.parse(lat.toString());
                patientLng = double.parse(lng.toString());
                final distance = const Distance().as(
                  LengthUnit.Meter,
                  LatLng(patientLat, patientLng),
                  zoneCenter,
                );
                isInZone = distance <= zoneRadius;
              });
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Rechercher un lieu...",
                  prefixIcon: Icon(Icons.search, color: Color(0xFF1B3F6B)),
                  suffixIcon: isSearching
                      ? Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1B3F6B)))
                      : IconButton(icon: Icon(Icons.send, color: Color(0xFF1B3F6B)), onPressed: () => _searchLocation(_searchController.text)),
                  filled: true,
                  fillColor: Colors.white,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFF1B3F6B), width: 2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: _searchLocation,
              ),
              if (searchResults.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final result = searchResults[index];
                      return ListTile(
                        leading: Icon(Icons.location_on, color: Color(0xFF1B3F6B)),
                        title: Text(result['name'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12)),
                        onTap: () => _selectLocation(result),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          margin: EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isInZone ? Colors.green.shade50 : Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isInZone ? Colors.green.shade200 : Colors.red.shade200),
          ),
          child: Row(
            children: [
              Icon(isInZone ? Icons.location_on : Icons.location_off, color: isInZone ? Colors.green : Colors.red, size: 24),
              SizedBox(width: 8),
              Text(
                isInZone ? "Dans la zone sécurisée" : "Hors de la zone !",
                style: TextStyle(fontWeight: FontWeight.bold, color: isInZone ? Colors.green : Colors.red, fontSize: 14),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: zoneCenter,
                  initialZoom: 16,
                  onLongPress: (tapPosition, point) {
                    setState(() => zoneCenter = point);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Zone déplacée ! N'oubliez pas de sauvegarder."), duration: Duration(seconds: 2)),
                    );
                  },
                ),
                children: [
                  TileLayer(urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png", userAgentPackageName: 'com.example.seniorcare_ai'),
                  CircleLayer(circles: [
                    CircleMarker(point: zoneCenter, radius: zoneRadius, useRadiusInMeter: true, color: Colors.blue.withOpacity(0.1), borderColor: Colors.blue, borderStrokeWidth: 2),
                  ]),
                  MarkerLayer(markers: [
                    Marker(point: zoneCenter, width: 30, height: 30, child: Icon(Icons.home, color: Colors.blue, size: 28)),
                    Marker(point: LatLng(patientLat, patientLng), width: 50, height: 50, child: Icon(Icons.person_pin_circle, color: isInZone ? Color(0xFF1B3F6B) : Colors.red, size: 48)),
                  ]),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Périmètre de la zone", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B), fontSize: 14)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Color(0xFF1B3F6B), borderRadius: BorderRadius.circular(20)),
                    child: Text("${zoneRadius.toInt()} m", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              Slider(value: zoneRadius, min: 50, max: 500, divisions: 45, activeColor: Color(0xFF1B3F6B), inactiveColor: Colors.grey.shade300, onChanged: (value) => setState(() => zoneRadius = value)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("50 m", style: TextStyle(fontSize: 11, color: Colors.grey)),
                  Text("500 m", style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Icon(Icons.touch_app, size: 14, color: Colors.grey),
              SizedBox(width: 4),
              Text("Appui long sur la carte pour déplacer la zone", style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : _saveGeofence,
              icon: isSaving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Icon(Icons.save, color: Colors.white),
              label: Text("Sauvegarder la zone"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1B3F6B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}