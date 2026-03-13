import 'package:flutter/material.dart';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Position simulée du patient
  double patientLat = 36.8065;
  double patientLng = 10.1815;
  bool isInZone = true;

  void simulateExitZone() {
    setState(() {
      isInZone = false;
    });
  }

  void simulateEnterZone() {
    setState(() {
      isInZone = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF5F7FA),
      child: Column(
        children: [
          // ── STATUS ZONE ──
          Container(
            width: double.infinity,
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isInZone ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isInZone ? Colors.green.shade200 : Colors.red.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isInZone ? Icons.location_on : Icons.location_off,
                  color: isInZone ? Colors.green : Colors.red,
                  size: 28,
                ),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isInZone
                          ? "Dans la zone sécurisée"
                          : "⚠️ Hors de la zone !",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isInZone ? Colors.green : Colors.red,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      "Lat: $patientLat — Lng: $patientLng",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── CARTE SIMULÉE ──
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Stack(
                children: [
                  // Fond carte simulé
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map, size: 80, color: Colors.grey.shade400),
                        SizedBox(height: 12),
                        Text(
                          "Google Maps sera intégré\naprès configuration API",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Marqueur patient
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 80),
                        Icon(
                          Icons.person_pin_circle,
                          color: isInZone ? Color(0xFF1B3F6B) : Colors.red,
                          size: 48,
                        ),
                        Text(
                          "Patient",
                          style: TextStyle(
                            color: Color(0xFF1B3F6B),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── BOUTONS TEST ──
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: simulateExitZone,
                    icon: Icon(Icons.location_off, color: Colors.white),
                    label: Text("Sortir zone"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: simulateEnterZone,
                    icon: Icon(Icons.location_on, color: Colors.white),
                    label: Text("Rentrer zone"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
