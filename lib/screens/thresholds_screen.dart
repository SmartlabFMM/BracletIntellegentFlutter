import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ThresholdsScreen extends StatefulWidget {
  final String patientId;
  final String role;
  const ThresholdsScreen({
    Key? key,
    required this.patientId,
    this.role = 'doctor',
  }) : super(key: key);

  @override
  _ThresholdsScreenState createState() => _ThresholdsScreenState();
}

class _ThresholdsScreenState extends State<ThresholdsScreen> {
  bool isLoading = true;
  bool isSaving = false;

  double bpmMin = 50;
  double bpmMax = 120;
  double spo2Min = 90;
  double tempMin = 35;
  double tempMax = 38.5;

  bool get isReadOnly => widget.role == 'family';

  @override
  void initState() {
    super.initState();
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    try {
      final threshold = await Supabase.instance.client
          .from('thresholds')
          .select()
          .eq('patient_id', widget.patientId)
          .maybeSingle();

      if (threshold != null) {
        setState(() {
          bpmMin = double.parse(threshold['bpm_min'].toString());
          bpmMax = double.parse(threshold['bpm_max'].toString());
          spo2Min = double.parse(threshold['spo2_min'].toString());
          tempMin = double.parse(threshold['temp_min'].toString());
          tempMax = double.parse(threshold['temp_max'].toString());
        });
      }
    } catch (e) {}
    setState(() => isLoading = false);
  }

  Future<void> _saveThresholds() async {
    setState(() => isSaving = true);
    try {
      final existing = await Supabase.instance.client
          .from('thresholds')
          .select('id')
          .eq('patient_id', widget.patientId)
          .maybeSingle();

      final data = {
        'bpm_min': bpmMin.toInt(),
        'bpm_max': bpmMax.toInt(),
        'spo2_min': spo2Min,
        'temp_min': tempMin,
        'temp_max': tempMax,
      };

      if (existing != null) {
        await Supabase.instance.client
            .from('thresholds')
            .update(data)
            .eq('patient_id', widget.patientId);
      } else {
        await Supabase.instance.client.from('thresholds').insert({
          ...data,
          'patient_id': widget.patientId,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Seuils sauvegardés !"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          isReadOnly ? "Seuils d'alerte (lecture seule)" : "Seuils d'alerte",
        ),
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Banner selon le rôle ──
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isReadOnly
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isReadOnly
                            ? Colors.orange.shade200
                            : Colors.blue.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isReadOnly ? Icons.lock_outline : Icons.info_outline,
                          color: isReadOnly ? Colors.orange : Colors.blue,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isReadOnly
                                ? "Ces seuils sont définis par votre médecin. Vous ne pouvez pas les modifier."
                                : "Configurez les seuils selon les recommandations médicales.",
                            style: TextStyle(
                              fontSize: 12,
                              color: isReadOnly
                                  ? Colors.orange.shade700
                                  : Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── BPM ──
                  _sectionCard(
                    icon: Icons.favorite,
                    color: Colors.red,
                    title: "Fréquence Cardiaque (BPM)",
                    children: [
                      _sliderRow(
                        label: "BPM Minimum",
                        value: bpmMin,
                        min: 30,
                        max: 80,
                        unit: "bpm",
                        color: Colors.orange,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => bpmMin = v),
                      ),
                      Divider(),
                      _sliderRow(
                        label: "BPM Maximum",
                        value: bpmMax,
                        min: 80,
                        max: 200,
                        unit: "bpm",
                        color: Colors.red,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => bpmMax = v),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ── SpO2 ──
                  _sectionCard(
                    icon: Icons.air,
                    color: Colors.blue,
                    title: "Saturation O₂ (SpO2)",
                    children: [
                      _sliderRow(
                        label: "SpO2 Minimum",
                        value: spo2Min,
                        min: 80,
                        max: 98,
                        unit: "%",
                        color: Colors.blue,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => spo2Min = v),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // ── Température ──
                  _sectionCard(
                    icon: Icons.thermostat,
                    color: Colors.orange,
                    title: "Température",
                    children: [
                      _sliderRow(
                        label: "Temp. Minimum",
                        value: tempMin,
                        min: 30,
                        max: 37,
                        unit: "°C",
                        color: Colors.blue,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => tempMin = v),
                      ),
                      Divider(),
                      _sliderRow(
                        label: "Temp. Maximum",
                        value: tempMax,
                        min: 37,
                        max: 42,
                        unit: "°C",
                        color: Colors.red,
                        onChanged: isReadOnly
                            ? null
                            : (v) => setState(() => tempMax = v),
                      ),
                    ],
                  ),

                  SizedBox(height: 24),

                  // ── Résumé ──
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xFF1B3F6B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Résumé des seuils",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 12),
                        _summaryRow(
                          "BPM",
                          "${bpmMin.toInt()} — ${bpmMax.toInt()} bpm",
                        ),
                        _summaryRow(
                          "SpO2",
                          ">= ${spo2Min.toStringAsFixed(1)}%",
                        ),
                        _summaryRow(
                          "Temp.",
                          "${tempMin.toStringAsFixed(1)} — ${tempMax.toStringAsFixed(1)}°C",
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 24),

                  // ── Bouton sauvegarder (médecin seulement) ──
                  if (!isReadOnly)
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _saveThresholds,
                        icon: isSaving
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.save, color: Colors.white),
                        label: Text(
                          "SAUVEGARDER LES SEUILS",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF1B3F6B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required Color color,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                if (isReadOnly) ...[
                  Spacer(),
                  Icon(Icons.lock, size: 14, color: color.withOpacity(0.5)),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _sliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required String unit,
    required Color color,
    required Function(double)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isReadOnly
                    ? Colors.grey.shade100
                    : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${value.toStringAsFixed(1)} $unit",
                style: TextStyle(
                  color: isReadOnly ? Colors.grey.shade600 : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            disabledActiveTrackColor: Colors.grey.shade300,
            disabledInactiveTrackColor: Colors.grey.shade200,
            disabledThumbColor: Colors.grey.shade400,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: ((max - min) * 2).toInt(),
            activeColor: isReadOnly ? Colors.grey.shade300 : color,
            inactiveColor: Colors.grey.shade200,
            onChanged: onChanged, // null = désactivé automatiquement
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "$min $unit",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
            Text(
              "$max $unit",
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
