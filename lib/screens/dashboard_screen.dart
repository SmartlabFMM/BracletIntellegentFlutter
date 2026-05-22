import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardScreen extends StatefulWidget {
  final String patientId;
  final String role;

  const DashboardScreen({
    Key? key,
    required this.patientId,
    this.role = 'family',
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int bpm = 0;
  double spo2 = 0;
  double temperature = 0;
  bool fallDetected = false;
  bool isLoading = true;

  int bpmMin = 50, bpmMax = 120;
  double spo2Min = 90, tempMin = 35, tempMax = 38.5;

  List<Map<String, dynamic>> _notes = [];
  bool _notesLoading = false;
  final _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadThresholds();
    _loadLatestVitals();
    _subscribeToRealtime();
    if (widget.role == 'doctor') _loadNotes();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadThresholds() async {
    try {
      final data = await Supabase.instance.client
          .from('thresholds')
          .select()
          .eq('patient_id', widget.patientId)
          .maybeSingle();
      if (data != null) {
        setState(() {
          bpmMin = data['bpm_min'] ?? 50;
          bpmMax = data['bpm_max'] ?? 120;
          spo2Min = double.parse((data['spo2_min'] ?? 90).toString());
          tempMin = double.parse((data['temp_min'] ?? 35).toString());
          tempMax = double.parse((data['temp_max'] ?? 38.5).toString());
        });
      }
    } catch (e) {}
  }

  Future<void> _loadLatestVitals() async {
    try {
      final data = await Supabase.instance.client
          .from('vitals')
          .select()
          .eq('patient_id', widget.patientId)
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
      setState(() => isLoading = false);
    }
  }

  void _subscribeToRealtime() {
    Supabase.instance.client
        .from('vitals')
        .stream(primaryKey: ['id'])
        .eq('patient_id', widget.patientId)
        .order('timestamp', ascending: false)
        .limit(1)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
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

  Future<void> _loadNotes() async {
    setState(() => _notesLoading = true);
    try {
      final data = await Supabase.instance.client
          .from('medical_notes')
          .select()
          .eq('patient_id', widget.patientId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      setState(() {
        _notes = List<Map<String, dynamic>>.from(data);
        _notesLoading = false;
      });
    } catch (e) {
      setState(() => _notesLoading = false);
    }
  }

  Future<void> _addNote(String content, bool isPinned) async {
    if (content.trim().isEmpty) return;
    try {
      final doctorId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('medical_notes').insert({
        'patient_id': widget.patientId,
        'doctor_id': doctorId,
        'content': content.trim(),
        'is_pinned': isPinned,
      });
      _noteController.clear();
      await _loadNotes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: $e"), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteNote(String noteId) async {
    try {
      await Supabase.instance.client
          .from('medical_notes')
          .delete()
          .eq('id', noteId);
      await _loadNotes();
    } catch (e) {}
  }

  Future<void> _togglePin(String noteId, bool currentPinned) async {
    try {
      await Supabase.instance.client
          .from('medical_notes')
          .update({'is_pinned': !currentPinned})
          .eq('id', noteId);
      await _loadNotes();
    } catch (e) {}
  }

  void _showAddNoteDialog() {
    bool isPinned = false;
    _noteController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text(
                "Nouvelle note médicale",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3F6B),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Ex: Patient sous Metformine 500mg...",
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Color(0xFF1B3F6B), width: 2),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Switch(
                    value: isPinned,
                    onChanged: (v) => setModalState(() => isPinned = v),
                    activeColor: Color(0xFF1B3F6B),
                  ),
                  SizedBox(width: 8),
                  Icon(
                    Icons.push_pin,
                    size: 18,
                    color: isPinned ? Color(0xFF1B3F6B) : Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Note importante",
                    style: TextStyle(
                      fontSize: 13,
                      color: isPinned ? Color(0xFF1B3F6B) : Colors.grey,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final text = _noteController.text;
                    Navigator.pop(ctx);
                    _addNote(text, isPinned);
                  },
                  icon: Icon(Icons.save, color: Colors.white),
                  label: Text(
                    "Sauvegarder",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1B3F6B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color getStatusColor(String type) {
    if (type == "bpm") {
      if (bpm < bpmMin || bpm > bpmMax) return Colors.red;
      if (bpm < bpmMin + 10 || bpm > bpmMax - 10) return Colors.orange;
      return Colors.green;
    }
    if (type == "spo2") {
      if (spo2 < spo2Min) return Colors.red;
      if (spo2 < spo2Min + 4) return Colors.orange;
      return Colors.green;
    }
    if (type == "temp") {
      if (temperature > tempMax || temperature < tempMin) return Colors.red;
      if (temperature > tempMax - 0.5) return Colors.orange;
      return Colors.green;
    }
    return Colors.green;
  }

  bool get hasAnomaly =>
      fallDetected ||
      bpm > bpmMax ||
      bpm < bpmMin ||
      spo2 < spo2Min ||
      temperature > tempMax ||
      temperature < tempMin;

  String _formatNoteDate(String? timestamp) {
    if (timestamp == null) return '';
    final dt = DateTime.tryParse(timestamp)?.toLocal();
    if (dt == null) return '';
    return "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} "
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.role == 'doctor';

    return isLoading
        ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
        : SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── STATUS ──
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: hasAnomaly
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasAnomaly
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasAnomaly
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: hasAnomaly ? Colors.red : Colors.green,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        hasAnomaly ? "Anomalie détectée !" : "État normal",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: hasAnomaly ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // ── SEUILS ──
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _thresholdInfo("BPM", "$bpmMin–$bpmMax"),
                      _thresholdInfo("SpO2", "≥${spo2Min.toStringAsFixed(1)}%"),
                      _thresholdInfo(
                        "Temp",
                        "${tempMin.toStringAsFixed(1)}–${tempMax.toStringAsFixed(1)}°C",
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // ── VITAUX ──
                Text(
                  "Signes Vitaux",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B3F6B),
                  ),
                ),
                SizedBox(height: 12),

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

                // ── NOTES MÉDICALES (médecin seulement) ──
                if (isDoctor) ...[
                  SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            color: Color(0xFF1B3F6B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Notes Médicales",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1B3F6B),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFF1B3F6B).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "${_notes.length}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B3F6B),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          GestureDetector(
                            onTap: _showAddNoteDialog,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF1B3F6B),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Note",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  _notesLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1B3F6B),
                          ),
                        )
                      : _notes.isEmpty
                      ? Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.note_add_outlined,
                                size: 40,
                                color: Colors.grey.shade300,
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Aucune note",
                                style: TextStyle(color: Colors.grey),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Appuyez sur + Note pour ajouter",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: _notes
                              .map((note) => _buildNoteCard(note))
                              .toList(),
                        ),

                  SizedBox(height: 24),
                ],
              ],
            ),
          );
  }

  Widget _buildNoteCard(Map<String, dynamic> note) {
    final isPinned = note['is_pinned'] == true;
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPinned
              ? Color(0xFF1B3F6B).withOpacity(0.4)
              : Colors.grey.shade200,
          width: isPinned ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isPinned) ...[
                  Icon(Icons.push_pin, size: 14, color: Color(0xFF1B3F6B)),
                  SizedBox(width: 4),
                ],
                Text(
                  _formatNoteDate(note['created_at']),
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Spacer(),
                GestureDetector(
                  onTap: () => _togglePin(note['id'], isPinned),
                  child: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                    color: isPinned ? Color(0xFF1B3F6B) : Colors.grey,
                  ),
                ),
                SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _confirmDelete(note['id']),
                  child: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red.shade300,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              note['content'] ?? '',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String noteId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Supprimer la note ?"),
        content: Text("Cette action est irréversible."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Annuler"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(noteId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _thresholdInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B3F6B),
          ),
        ),
      ],
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
