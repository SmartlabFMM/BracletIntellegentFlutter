import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';
import 'login_screen.dart';
import 'create_patient_screen.dart';

class DoctorPatientsScreen extends StatefulWidget {
  @override
  _DoctorPatientsScreenState createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _patients = [];
  Map<String, dynamic> _lastVitals = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final patients = await supabase
          .from('patients')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      Map<String, dynamic> vitalsMap = {};
      for (final patient in patients) {
        final vitals = await supabase
            .from('vitals')
            .select('heart_rate, spo2, temperature, timestamp, fall_detected')
            .eq('patient_id', patient['id'])
            .order('timestamp', ascending: false)
            .limit(1)
            .maybeSingle();

        if (vitals != null) vitalsMap[patient['id']] = vitals;
      }

      setState(() {
        _patients = List<Map<String, dynamic>>.from(patients);
        _lastVitals = vitalsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // Statut bracelet basé sur dernière donnée
  Map<String, dynamic> _getBraceletStatus(String? timestamp) {
    if (timestamp == null)
      return {
        'label': 'Jamais',
        'color': Colors.grey,
        'icon': Icons.device_unknown,
      };
    final dt = DateTime.tryParse(timestamp);
    if (dt == null)
      return {
        'label': 'Inconnu',
        'color': Colors.grey,
        'icon': Icons.device_unknown,
      };

    final diff = DateTime.now().difference(dt.toLocal());

    if (diff.inMinutes < 1)
      return {'label': 'En ligne', 'color': Colors.green, 'icon': Icons.circle};
    if (diff.inMinutes < 60)
      return {
        'label': 'Il y a ${diff.inMinutes}min',
        'color': Colors.orange,
        'icon': Icons.circle,
      };
    return {'label': 'Hors ligne', 'color': Colors.red, 'icon': Icons.circle};
  }

  void _logout() async {
    await supabase.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.medical_services, size: 22),
            SizedBox(width: 8),
            Text("Mes Patients", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadPatients),
          IconButton(icon: Icon(Icons.logout), onPressed: _logout),
        ],
      ),

      // Bouton créer patient
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CreatePatientScreen()),
          );
          _loadPatients(); // Refresh après création
        },
        backgroundColor: Color(0xFF1B3F6B),
        icon: Icon(Icons.person_add, color: Colors.white),
        label: Text(
          "Nouveau Patient",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),

      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
          : _patients.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadPatients,
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: _patients.length,
                itemBuilder: (context, index) =>
                    _buildPatientCard(_patients[index]),
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            "Aucun patient",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Appuyez sur + pour créer votre premier patient",
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreatePatientScreen()),
              );
              _loadPatients();
            },
            icon: Icon(Icons.person_add, color: Colors.white),
            label: Text(
              "Créer un patient",
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF1B3F6B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Map<String, dynamic> patient) {
    final patientId = patient['id'];
    final vitals = _lastVitals[patientId];
    final diseases = (patient['diseases'] as List?)?.join(', ') ?? 'Aucune';
    final shareCode = patient['share_code'] ?? '--';
    final braceletStatus = _getBraceletStatus(vitals?['timestamp']);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(patientId: patientId, role: 'doctor'),
        ),
      ).then((_) => _loadPatients()),
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Color(0xFF1B3F6B).withOpacity(0.05),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(0xFF1B3F6B),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        patient['name']?[0]?.toUpperCase() ?? '?',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient['name'] ?? 'Patient',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B3F6B),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "${patient['age'] ?? '?'} ans • $diseases",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Statut bracelet
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 8,
                            color: braceletStatus['color'],
                          ),
                          SizedBox(width: 4),
                          Text(
                            braceletStatus['label'],
                            style: TextStyle(
                              fontSize: 11,
                              color: braceletStatus['color'],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Vitaux
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  vitals != null
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildVitalMini(
                              icon: Icons.favorite,
                              color: Colors.red,
                              label: "BPM",
                              value: "${vitals['heart_rate'] ?? '--'}",
                            ),
                            _buildDivider(),
                            _buildVitalMini(
                              icon: Icons.air,
                              color: Colors.blue,
                              label: "SpO2",
                              value: "${vitals['spo2'] ?? '--'}%",
                            ),
                            _buildDivider(),
                            _buildVitalMini(
                              icon: Icons.thermostat,
                              color: Colors.orange,
                              label: "Temp",
                              value:
                                  "${vitals['temperature']?.toStringAsFixed(1) ?? '--'}°C",
                            ),
                            _buildDivider(),
                            _buildVitalMini(
                              icon: vitals['fall_detected'] == true
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline,
                              color: vitals['fall_detected'] == true
                                  ? Colors.red
                                  : Colors.green,
                              label: "Chute",
                              value: vitals['fall_detected'] == true
                                  ? "OUI"
                                  : "Non",
                            ),
                          ],
                        )
                      : Center(
                          child: Text(
                            "Aucune donnée disponible",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),

                  SizedBox(height: 12),

                  // Code de partage
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Color(0xFF1B3F6B).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color(0xFF1B3F6B).withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.vpn_key_rounded,
                          size: 14,
                          color: Color(0xFF1B3F6B),
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Code famille : ",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          shareCode,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1B3F6B),
                            letterSpacing: 2,
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: shareCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Code copié !"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          child: Icon(
                            Icons.copy,
                            size: 14,
                            color: Color(0xFF1B3F6B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalMini({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B3F6B),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildDivider() =>
      Container(height: 40, width: 1, color: Colors.grey.shade200);

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '--';
    final dt = DateTime.tryParse(timestamp);
    if (dt == null) return '--';
    final local = dt.toLocal();
    return "${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}";
  }
}
