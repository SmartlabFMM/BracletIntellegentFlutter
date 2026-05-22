import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dashboard_screen.dart';
import 'alerts_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'charts_screen.dart';
import 'login_screen.dart';

class MainScreen extends StatefulWidget {
  final String patientId;
  final String role;

  const MainScreen({Key? key, required this.patientId, required this.role})
    : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  String _patientName = '';
  bool _pdfGenerating = false;

  final GlobalKey<ChartsScreenState> _chartsKey =
      GlobalKey<ChartsScreenState>();
  final ScreenshotController _bpmScreenshot = ScreenshotController();
  final ScreenshotController _spo2Screenshot = ScreenshotController();

  Map<String, dynamic>? _patientInfo;
  List<Map<String, dynamic>> _alerts = [];
  List<Map<String, dynamic>> _notes = [];

  int bpmMin = 50, bpmMax = 120;
  double spo2Min = 90, tempMin = 35, tempMax = 38.5;
  int bpm = 0;
  double spo2 = 0, temperature = 0;
  bool fallDetected = false;

  @override
  void initState() {
    super.initState();
    _loadPatientName();
    if (widget.role == 'doctor') _loadPDFData();
  }

  Future<void> _loadPatientName() async {
    try {
      final data = await Supabase.instance.client
          .from('patients')
          .select('name')
          .eq('id', widget.patientId)
          .maybeSingle();
      if (mounted && data != null)
        setState(() => _patientName = data['name'] ?? '');
    } catch (e) {}
  }

  Future<void> _loadPDFData() async {
    try {
      final patient = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.patientId)
          .maybeSingle();
      final thresholds = await Supabase.instance.client
          .from('thresholds')
          .select()
          .eq('patient_id', widget.patientId)
          .maybeSingle();
      final alerts = await Supabase.instance.client
          .from('alerts')
          .select()
          .eq('patient_id', widget.patientId)
          .order('timestamp', ascending: false)
          .limit(20);
      final notes = await Supabase.instance.client
          .from('medical_notes')
          .select()
          .eq('patient_id', widget.patientId)
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false);
      final vitals = await Supabase.instance.client
          .from('vitals')
          .select()
          .eq('patient_id', widget.patientId)
          .order('timestamp', ascending: false)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _patientInfo = patient;
          _alerts = List<Map<String, dynamic>>.from(alerts);
          _notes = List<Map<String, dynamic>>.from(notes);
          if (thresholds != null) {
            bpmMin = thresholds['bpm_min'] ?? 50;
            bpmMax = thresholds['bpm_max'] ?? 120;
            spo2Min = double.parse((thresholds['spo2_min'] ?? 90).toString());
            tempMin = double.parse((thresholds['temp_min'] ?? 35).toString());
            tempMax = double.parse((thresholds['temp_max'] ?? 38.5).toString());
          }
          if (vitals != null) {
            bpm = vitals['heart_rate'] ?? 0;
            spo2 = double.parse((vitals['spo2'] ?? 0).toString());
            temperature = double.parse((vitals['temperature'] ?? 0).toString());
            fallDetected = vitals['fall_detected'] ?? false;
          }
        });
      }
    } catch (e) {}
  }

  // ══════════════════════════════════════════════
  // DIALOG CHOIX COURBES
  // ══════════════════════════════════════════════

  Future<void> _showPDFChoiceDialog() async {
    bool includeBPM = true;
    bool includeSpo2 = true;
    String selectedPeriod = '24h';

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Color(0xFF1B3F6B)),
              SizedBox(width: 8),
              Text(
                "Generer le PDF",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3F6B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Courbes a inclure :",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1B3F6B),
                ),
              ),
              SizedBox(height: 8),

              // BPM
              Container(
                decoration: BoxDecoration(
                  color: includeBPM
                      ? Color(0xFF1B3F6B).withOpacity(0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: includeBPM
                        ? Color(0xFF1B3F6B).withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  value: includeBPM,
                  onChanged: (v) => setDialogState(() => includeBPM = v!),
                  activeColor: Color(0xFF1B3F6B),
                  title: Row(
                    children: [
                      Icon(Icons.favorite, color: Colors.red, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "BPM - Freq. Cardiaque",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),

              SizedBox(height: 8),

              // SpO2
              Container(
                decoration: BoxDecoration(
                  color: includeSpo2
                      ? Color(0xFF1B3F6B).withOpacity(0.05)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: includeSpo2
                        ? Color(0xFF1B3F6B).withOpacity(0.3)
                        : Colors.grey.shade200,
                  ),
                ),
                child: CheckboxListTile(
                  value: includeSpo2,
                  onChanged: (v) => setDialogState(() => includeSpo2 = v!),
                  activeColor: Color(0xFF1B3F6B),
                  title: Row(
                    children: [
                      Icon(Icons.air, color: Colors.blue, size: 16),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "SpO2 - Saturation O2",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                  dense: true,
                ),
              ),

              SizedBox(height: 16),
              Text(
                "Periode :",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF1B3F6B),
                ),
              ),
              SizedBox(height: 8),

              Row(
                children: ['24h', '7j', '30j']
                    .map(
                      (p) => Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => selectedPeriod = p),
                          child: Container(
                            margin: EdgeInsets.only(right: p != '30j' ? 8 : 0),
                            padding: EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selectedPeriod == p
                                  ? Color(0xFF1B3F6B)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                p,
                                style: TextStyle(
                                  color: selectedPeriod == p
                                      ? Colors.white
                                      : Colors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Les courbes seront capturees automatiquement.",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("Annuler", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              onPressed: (!includeBPM && !includeSpo2)
                  ? null
                  : () => Navigator.pop(ctx, true),
              icon: Icon(Icons.picture_as_pdf, color: Colors.white, size: 16),
              label: Text(
                "Generer",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1B3F6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _generatePDF(
        includeBPM: includeBPM,
        includeSpo2: includeSpo2,
        period: selectedPeriod,
      );
    }
  }

  // ══════════════════════════════════════════════
  // GÉNÉRATION PDF
  // ══════════════════════════════════════════════

  Future<void> _generatePDF({
    required bool includeBPM,
    required bool includeSpo2,
    required String period,
  }) async {
    setState(() => _pdfGenerating = true);

    Uint8List? bpmImg;
    Uint8List? spo2Img;

    try {
      setState(() => _currentIndex = 1);
      await Future.delayed(Duration(milliseconds: 500));
      await _chartsKey.currentState?.switchPeriodAndCapture(period);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 12),
                Text("Capture des courbes ($period)..."),
              ],
            ),
            duration: Duration(seconds: 6),
            backgroundColor: Color(0xFF1B3F6B),
          ),
        );
      }

      if (includeBPM) {
        _chartsKey.currentState?.switchTab(0);
        await Future.delayed(Duration(seconds: 2));
        bpmImg = await _bpmScreenshot.capture();
      }

      if (includeSpo2) {
        _chartsKey.currentState?.switchTab(1);
        await Future.delayed(Duration(seconds: 2));
        spo2Img = await _spo2Screenshot.capture();
      }

      setState(() => _currentIndex = 0);
      await Future.delayed(Duration(milliseconds: 300));

      final pdf = pw.Document();
      final now = DateTime.now();
      final dateStr =
          "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
      final patientName = _patientInfo?['name'] ?? 'Patient';
      final patientAge = _patientInfo?['age'] ?? '--';
      final diseases = (_patientInfo?['diseases'] as List?)?.join(', ') ?? '--';
      final periodLabel = period == '24h'
          ? 'Dernieres 24 heures'
          : period == '7j'
          ? '7 derniers jours'
          : '30 derniers jours';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (pw.Context context) => [
            // En-tête
            pw.Container(
              padding: pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#1B3F6B'),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'SeniorCare AI',
                        style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        'Rapport Medical',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.grey300,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    'Date : $dateStr',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.white),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Infos patient
            pw.Text(
              'Informations Patient',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1B3F6B'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F7FA'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
              ),
              child: pw.Table(
                children: [
                  _pdfRow('Nom', patientName),
                  _pdfRow('Age', '$patientAge ans'),
                  _pdfRow('Maladies', diseases),
                  _pdfRow('Seuil BPM', '$bpmMin - $bpmMax bpm'),
                  _pdfRow('Seuil SpO2', '>= ${spo2Min.toStringAsFixed(1)} %'),
                  _pdfRow(
                    'Seuil Temp.',
                    '${tempMin.toStringAsFixed(1)} - ${tempMax.toStringAsFixed(1)} C',
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Dernières mesures
            pw.Text(
              'Dernieres Mesures',
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('#1B3F6B'),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F5F7FA'),
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColor.fromHex('#E0E0E0')),
              ),
              child: pw.Table(
                children: [
                  _pdfRow('Frequence Cardiaque', '$bpm bpm'),
                  _pdfRow('Saturation O2', '${spo2.toStringAsFixed(1)} %'),
                  _pdfRow('Temperature', '${temperature.toStringAsFixed(1)} C'),
                  _pdfRow('Chute detectee', fallDetected ? 'OUI' : 'Non'),
                ],
              ),
            ),

            pw.SizedBox(height: 20),

            // Courbes côte à côte
            if (bpmImg != null || spo2Img != null) ...[
              pw.Text(
                'Courbes - Periode : $periodLabel',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1B3F6B'),
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (bpmImg != null)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BPM',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.red,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                color: PdfColor.fromHex('#E0E0E0'),
                              ),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(bpmImg),
                              height: 160,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (bpmImg != null && spo2Img != null) pw.SizedBox(width: 12),
                  if (spo2Img != null)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'SpO2',
                            style: pw.TextStyle(
                              fontSize: 12,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue,
                            ),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Container(
                            decoration: pw.BoxDecoration(
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                color: PdfColor.fromHex('#E0E0E0'),
                              ),
                            ),
                            child: pw.Image(
                              pw.MemoryImage(spo2Img),
                              height: 160,
                              fit: pw.BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),
            ],

            // Alertes
            if (_alerts.isNotEmpty) ...[
              pw.Text(
                'Historique des Alertes',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1B3F6B'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: ['Date/Heure', 'Type', 'Severite', 'Message'],
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  fontSize: 10,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#1B3F6B'),
                ),
                cellStyle: pw.TextStyle(fontSize: 9),
                oddRowDecoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F5F7FA'),
                ),
                cellAlignment: pw.Alignment.center,
                data: _alerts.take(20).map((a) {
                  final ts = a['timestamp'] != null
                      ? DateTime.tryParse(a['timestamp'])?.toLocal()
                      : null;
                  final d = ts != null
                      ? "${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}"
                      : '--';
                  return [
                    d,
                    a['type'] ?? '--',
                    a['severity'] ?? '--',
                    a['message'] ?? '--',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            // Notes médicales
            if (_notes.isNotEmpty) ...[
              pw.Text(
                'Notes Medicales',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1B3F6B'),
                ),
              ),
              pw.SizedBox(height: 8),
              ..._notes.map((note) {
                final ts = note['created_at'] != null
                    ? DateTime.tryParse(note['created_at'])?.toLocal()
                    : null;
                final d = ts != null
                    ? "${ts.day.toString().padLeft(2, '0')}/${ts.month.toString().padLeft(2, '0')}/${ts.year} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}"
                    : '--';
                final isPinned = note['is_pinned'] == true;
                return pw.Container(
                  margin: pw.EdgeInsets.only(bottom: 8),
                  padding: pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: isPinned
                        ? PdfColor.fromHex('#EBF0F8')
                        : PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(
                      color: isPinned
                          ? PdfColor.fromHex('#1B3F6B')
                          : PdfColor.fromHex('#E0E0E0'),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            d,
                            style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey600,
                            ),
                          ),
                          if (isPinned)
                            pw.Text(
                              'IMPORTANTE',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColor.fromHex('#1B3F6B'),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        note['content'] ?? '',
                        style: pw.TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'Rapport genere par SeniorCare AI le $dateStr',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Rapport_${patientName}_$dateStr.pdf',
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Erreur PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  pw.TableRow _pdfRow(String label, String value) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Text(
            label,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: pw.Text(value, style: pw.TextStyle(fontSize: 10)),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════
  // SCREENS & NAV
  // ══════════════════════════════════════════════

  List<Widget> get _screens {
    if (widget.role == 'doctor') {
      return [
        DashboardScreen(patientId: widget.patientId, role: 'doctor'),
        ChartsScreen(
          key: _chartsKey,
          patientId: widget.patientId,
          bpmScreenshot: _bpmScreenshot,
          spo2Screenshot: _spo2Screenshot,
        ),
        AlertsScreen(patientId: widget.patientId, role: 'doctor'),
        // Paramètres médecin (inclut Seuils)
        SettingsScreen(patientId: widget.patientId, role: 'doctor'),
      ];
    } else {
      return [
        DashboardScreen(patientId: widget.patientId, role: 'family'),
        AlertsScreen(patientId: widget.patientId, role: 'family'),
        MapScreen(patientId: widget.patientId),
        SettingsScreen(patientId: widget.patientId, role: 'family'),
      ];
    }
  }

  List<BottomNavigationBarItem> get _navItems {
    if (widget.role == 'doctor') {
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.show_chart), label: "Courbes"),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: "Alertes",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: "Parametres",
        ),
      ];
    } else {
      return [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: "Dashboard",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: "Alertes",
        ),
        BottomNavigationBarItem(icon: Icon(Icons.map), label: "Carte"),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: "Parametres",
        ),
      ];
    }
  }

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = widget.role == 'doctor';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Icon(Icons.monitor_heart, size: 22),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SeniorCare AI",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                if (_patientName.isNotEmpty)
                  Text(
                    _patientName,
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDoctor
                  ? Colors.blue.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isDoctor ? Icons.medical_services : Icons.family_restroom,
                  size: 13,
                  color: Colors.white,
                ),
                SizedBox(width: 4),
                Text(
                  isDoctor ? "Medecin" : "Famille",
                  style: TextStyle(fontSize: 11, color: Colors.white),
                ),
              ],
            ),
          ),
          SizedBox(width: 4),

          // Bouton PDF
          if (isDoctor)
            _pdfGenerating
                ? Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : IconButton(
                    icon: Icon(Icons.picture_as_pdf, color: Colors.white),
                    tooltip: "Generer PDF",
                    onPressed: _showPDFChoiceDialog,
                  ),

          if (isDoctor)
            IconButton(
              icon: Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.pop(context),
            ),

          if (!isDoctor)
            IconButton(icon: Icon(Icons.logout, size: 20), onPressed: _logout),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Color(0xFF1B3F6B),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 10),
        onTap: (index) => setState(() => _currentIndex = index),
        items: _navItems,
      ),
    );
  }
}
