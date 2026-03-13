import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int bpm = 0;
  double spo2 = 0;
  double temperature = 0;
  bool fallDetected = false;
  bool isLoading = true;
  bool isSimulating = false;

  @override
  void initState() {
    super.initState();
    _loadLatestVitals();
    _subscribeToRealtime();
  }

  Future<String> _getPatientId() async {
    final user = Supabase.instance.client.auth.currentUser;
    final data = await Supabase.instance.client
        .from('patients')
        .select('id')
        .eq('user_id', user!.id)
        .order('created_at', ascending: true)
        .limit(1)
        .single();
    return data['id'];
  }

  Future<void> _loadLatestVitals() async {
    try {
      final data = await Supabase.instance.client
          .from('vitals')
          .select()
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      setState(() {
        bpm = (data['heart_rate'] ?? 0) as int;
        spo2 = double.parse((data['spo2'] ?? 0).toString());
        temperature = double.parse((data['temperature'] ?? 0).toString());
        fallDetected = data['fall_detected'] ?? false;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _subscribeToRealtime() {
    Supabase.instance.client
        .from('vitals')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty) {
            setState(() {
              bpm = (data[0]['heart_rate'] ?? 0) as int;
              spo2 = double.parse((data[0]['spo2'] ?? 0).toString());
              temperature = double.parse(
                (data[0]['temperature'] ?? 0).toString(),
              );
              fallDetected = data[0]['fall_detected'] ?? false;
              isLoading = false;
            });
          }
        });
  }

  // ── Simuler une alerte via Edge Function ──
  void simulateAlert() async {
    setState(() {
      isSimulating = true;
    });
    try {
      final patientId = await _getPatientId();
      await Supabase.instance.client.functions.invoke(
        'check-vitals',
        body: {
          'patient_id': patientId,
          'heart_rate': 135,
          'spo2': 87.0,
          'temperature': 39.2,
          'fall_detected': true,
        },
      );
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() {
        isSimulating = false;
      });
    }
  }

  // ── Remettre les valeurs normales ──
  void resetNormal() async {
    setState(() {
      isSimulating = true;
    });
    try {
      final patientId = await _getPatientId();
      await Supabase.instance.client
          .from('vitals')
          .update({
            'heart_rate': 72,
            'spo2': 98.0,
            'temperature': 36.5,
            'fall_detected': false,
          })
          .eq('patient_id', patientId);
    } catch (e) {
      print('Erreur: $e');
    } finally {
      setState(() {
        isSimulating = false;
      });
    }
  }

  Color getStatusColor(String type) {
    if (type == "bpm") {
      if (bpm < 50 || bpm > 120) return Colors.red;
      if (bpm < 60 || bpm > 100) return Colors.orange;
      return Colors.green;
    }
    if (type == "spo2") {
      if (spo2 < 90) return Colors.red;
      if (spo2 < 94) return Colors.orange;
      return Colors.green;
    }
    if (type == "temp") {
      if (temperature > 38.5 || temperature < 35) return Colors.red;
      if (temperature > 37.5) return Colors.orange;
      return Colors.green;
    }
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8),

                // ── STATUS GLOBAL ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: fallDetected || bpm > 120 || spo2 < 90
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: fallDetected || bpm > 120 || spo2 < 90
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        fallDetected || bpm > 120 || spo2 < 90
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: fallDetected || bpm > 120 || spo2 < 90
                            ? Colors.red
                            : Colors.green,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        fallDetected || bpm > 120 || spo2 < 90
                            ? "Anomalie détectée !"
                            : "État normal",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: fallDetected || bpm > 120 || spo2 < 90
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                Text(
                  "Signes Vitaux",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3F6B),
                  ),
                ),

                SizedBox(height: 12),

                // ── 4 CARTES VITALES ──
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _VitalCard(
                      icon: Icons.favorite,
                      label: "Fréq. Cardiaque",
                      value: "$bpm",
                      unit: "bpm",
                      color: getStatusColor("bpm"),
                    ),
                    _VitalCard(
                      icon: Icons.air,
                      label: "Saturation O₂",
                      value: "${spo2.toStringAsFixed(1)}",
                      unit: "%",
                      color: getStatusColor("spo2"),
                    ),
                    _VitalCard(
                      icon: Icons.thermostat,
                      label: "Température",
                      value: "${temperature.toStringAsFixed(1)}",
                      unit: "°C",
                      color: getStatusColor("temp"),
                    ),
                    _VitalCard(
                      icon: fallDetected
                          ? Icons.warning_amber_rounded
                          : Icons.directions_walk,
                      label: "Détection Chute",
                      value: fallDetected ? "CHUTE" : "OK",
                      unit: "",
                      color: fallDetected ? Colors.red : Colors.green,
                    ),
                  ],
                ),

                SizedBox(height: 24),

                Text(
                  "Simulation (test)",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3F6B),
                  ),
                ),
                SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isSimulating ? null : simulateAlert,
                        icon: isSimulating
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.warning, color: Colors.white),
                        label: Text("Simuler Alerte"),
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
                        onPressed: isSimulating ? null : resetNormal,
                        icon: Icon(Icons.check_circle, color: Colors.white),
                        label: Text("Normal"),
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

                SizedBox(height: 16),

                // ── BOUTON REFRESH ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadLatestVitals,
                    icon: Icon(Icons.refresh, color: Colors.white),
                    label: Text("Actualiser"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1B3F6B),
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
          );
  }
}

class _VitalCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _VitalCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          Spacer(),
          Text(
            "$value $unit",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
