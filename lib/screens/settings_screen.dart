import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'thresholds_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String patientId;
  final String role;
  const SettingsScreen({Key? key, required this.patientId, this.role = 'family'}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String userEmail   = "";
  String patientName = "";
  bool isLoading     = true;

  bool get isDoctor => widget.role == 'doctor';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final patient = await Supabase.instance.client
          .from('patients').select('name').eq('id', widget.patientId).maybeSingle();

      setState(() {
        userEmail   = user?.email ?? "";
        patientName = patient?['name'] ?? "Non configuré";
        isLoading   = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Déconnexion"),
        content: Text("Voulez-vous vraiment vous déconnecter ?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("Annuler")),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Déconnecter", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF5F7FA),
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),

                  // ── PROFIL CARD ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Color(0xFF1B3F6B), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(30)),
                          child: Icon(isDoctor ? Icons.medical_services : Icons.person, color: Colors.white, size: 32),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(userEmail, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
                              SizedBox(height: 6),
                              Row(children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDoctor ? Colors.blue.withOpacity(0.4) : Colors.green.withOpacity(0.4),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(isDoctor ? "Médecin" : "Famille", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                                SizedBox(width: 8),
                                Expanded(child: Text("Patient : $patientName", style: TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── SECTION PATIENT ──
                  _sectionTitle("Patient"),
                  SizedBox(height: 8),

                  _settingsTile(
                    icon: Icons.person_outline,
                    title: isDoctor ? "Modifier le profil patient" : "Profil patient",
                    subtitle: isDoctor
                        ? "Nom, âge, maladies, contacts"
                        : "Voir le profil / modifier les contacts",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(patientId: widget.patientId, role: widget.role)),
                    ),
                  ),

                  _settingsTile(
                    icon: Icons.tune,
                    title: "Seuils d'alerte",
                    subtitle: isDoctor
                        ? "Configurer BPM, SpO2, Température"
                        : "Voir les seuils définis par le médecin",
                    trailing: isDoctor
                        ? null
                        : Icon(Icons.lock, size: 16, color: Colors.grey.shade400),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ThresholdsScreen(patientId: widget.patientId, role: widget.role)),
                    ),
                  ),

                  SizedBox(height: 16),

                  // ── SECTION APPLICATION ──
                  _sectionTitle("Application"),
                  SizedBox(height: 8),

                  _settingsTile(
                    icon: Icons.notifications_outlined,
                    title: "Notifications",
                    subtitle: "Gérer les alertes",
                    trailing: Switch(value: true, onChanged: (v) {}, activeColor: Color(0xFF1B3F6B)),
                    onTap: () {},
                  ),

                  _settingsTile(
                    icon: Icons.info_outline,
                    title: "À propos",
                    subtitle: "SeniorCare AI v1.0.0",
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: "SeniorCare AI",
                      applicationVersion: "1.0.0",
                      applicationIcon: Icon(Icons.monitor_heart, color: Color(0xFF1B3F6B), size: 48),
                      children: [Text("Surveillance médicale intelligente pour les personnes âgées.")],
                    ),
                  ),

                  SizedBox(height: 16),

                  // ── SECTION SESSION ──
                  _sectionTitle("Session"),
                  SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.logout, color: Colors.red, size: 22),
                      ),
                      title: Text("Se déconnecter", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      trailing: Icon(Icons.chevron_right, color: Colors.red),
                      onTap: _logout,
                    ),
                  ),

                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1),
      );

  Widget _settingsTile({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, Widget? trailing}) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
      ),
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: Color(0xFF1B3F6B).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Color(0xFF1B3F6B), size: 22),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}