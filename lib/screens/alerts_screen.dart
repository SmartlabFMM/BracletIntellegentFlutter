import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AlertsScreen extends StatefulWidget {
  final String patientId;
  final String role;
  const AlertsScreen({Key? key, required this.patientId, this.role = 'family'}) : super(key: key);

  @override
  _AlertsScreenState createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> alerts = [];
  bool isLoading = true;

  // Stats
  int totalAlerts = 0;
  Map<String, int> alertsByType = {};
  Map<String, int> alertsBySeverity = {};
  String mostFrequentType = '--';

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _subscribeToAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final data = await Supabase.instance.client
          .from('alerts')
          .select()
          .eq('patient_id', widget.patientId)
          .order('timestamp', ascending: false)
          .limit(50);

      final list = List<Map<String, dynamic>>.from(data);

      // Calculer stats
      final byType = <String, int>{};
      final bySeverity = <String, int>{};

      for (final alert in list) {
        final type = alert['type'] ?? 'AUTRE';
        final severity = alert['severity'] ?? 'modere';
        byType[type] = (byType[type] ?? 0) + 1;
        bySeverity[severity] = (bySeverity[severity] ?? 0) + 1;
      }

      String mostFrequent = '--';
      if (byType.isNotEmpty) {
        mostFrequent = byType.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      setState(() {
        alerts = list;
        totalAlerts = list.length;
        alertsByType = byType;
        alertsBySeverity = bySeverity;
        mostFrequentType = mostFrequent;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  void _subscribeToAlerts() {
    Supabase.instance.client
        .from('alerts')
        .stream(primaryKey: ['id'])
        .eq('patient_id', widget.patientId)
        .order('timestamp', ascending: false)
        .limit(50)
        .listen((data) {
          if (mounted) {
            setState(() {
              alerts = List<Map<String, dynamic>>.from(data);
              totalAlerts = alerts.length;
            });
          }
        });
  }

  Color _getSeverityColor(String? severity) {
    switch (severity) {
      case "critique": return Colors.red;
      case "eleve":    return Colors.orange;
      case "modere":   return Colors.amber;
      default:         return Colors.green;
    }
  }

  IconData _getSeverityIcon(String? severity) {
    switch (severity) {
      case "critique": return Icons.warning_amber_rounded;
      case "eleve":    return Icons.error_outline;
      case "modere":   return Icons.info_outline;
      default:         return Icons.check_circle_outline;
    }
  }

  IconData _getTypeIcon(String? type) {
    switch (type) {
      case "TACHYCARDIE":
      case "BRADYCARDIE": return Icons.favorite;
      case "HYPOXIE":     return Icons.air;
      case "FIÈVRE":
      case "HYPOTHERMIE": return Icons.thermostat;
      case "CHUTE":       return Icons.warning_amber_rounded;
      default:            return Icons.notifications;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return "--";
    final dt = DateTime.parse(timestamp).toLocal();
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0xFFF5F7FA),
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
          : alerts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAlerts,
                  child: ListView(
                    padding: EdgeInsets.all(16),
                    children: [
                      // Stats uniquement pour médecin
                      if (widget.role == 'doctor') ...[
                        _buildStatsSection(),
                        SizedBox(height: 20),
                        Text(
                          "Historique des alertes",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B)),
                        ),
                        SizedBox(height: 12),
                      ],

                      // Liste alertes
                      ...alerts.map((alert) => _buildAlertCard(alert)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Statistiques", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B))),
        SizedBox(height: 12),

        // Cards stats
        Row(
          children: [
            _statCard(
              icon: Icons.notifications_active,
              label: "Total",
              value: "$totalAlerts",
              color: Color(0xFF1B3F6B),
            ),
            SizedBox(width: 10),
            _statCard(
              icon: Icons.warning_amber_rounded,
              label: "Critiques",
              value: "${alertsBySeverity['critique'] ?? 0}",
              color: Colors.red,
            ),
            SizedBox(width: 10),
            _statCard(
              icon: Icons.trending_up,
              label: "Élevées",
              value: "${alertsBySeverity['eleve'] ?? 0}",
              color: Colors.orange,
            ),
          ],
        ),

        SizedBox(height: 12),

        // Type le plus fréquent
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Color(0xFF1B3F6B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.bar_chart, color: Color(0xFF1B3F6B)),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Type le plus fréquent", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(mostFrequentType, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B))),
                ],
              ),
              Spacer(),
              Text(
                "${alertsByType[mostFrequentType] ?? 0} fois",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),

        SizedBox(height: 12),

        // Répartition par type
        Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Répartition par type", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B))),
              SizedBox(height: 12),
              ...alertsByType.entries.map((entry) {
                final percent = totalAlerts > 0 ? entry.value / totalAlerts : 0.0;
                return Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(_getTypeIcon(entry.key), size: 14, color: Color(0xFF1B3F6B)),
                              SizedBox(width: 6),
                              Text(entry.key, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            ],
                          ),
                          Text("${entry.value}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B))),
                        ],
                      ),
                      SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent,
                          backgroundColor: Colors.grey.shade100,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1B3F6B)),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final color = _getSeverityColor(alert["severity"]);
    final icon = _getSeverityIcon(alert["severity"]);

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(alert["type"] ?? "ALERTE", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        subtitle: Text(alert["message"] ?? "", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_formatTime(alert["timestamp"]), style: TextStyle(color: Colors.grey, fontSize: 10)),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: Text((alert["severity"] ?? "").toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
          SizedBox(height: 16),
          Text("Aucune alerte", style: TextStyle(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.w500)),
          SizedBox(height: 8),
          Text("Le patient est en bonne santé", style: TextStyle(fontSize: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}