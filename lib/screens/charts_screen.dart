import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:screenshot/screenshot.dart';

class ChartsScreen extends StatefulWidget {
  final String patientId;
  final ScreenshotController? bpmScreenshot;
  final ScreenshotController? spo2Screenshot;

  const ChartsScreen({
    Key? key,
    required this.patientId,
    this.bpmScreenshot,
    this.spo2Screenshot,
  }) : super(key: key);

  @override
  ChartsScreenState createState() => ChartsScreenState();
}

class ChartsScreenState extends State<ChartsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _vitals = [];
  bool _isLoading = true;

  // Seuils
  int bpmMin = 50, bpmMax = 120;
  double spo2Min = 90, tempMin = 35, tempMax = 38.5;

  // Période
  String _period = '24h';
  final List<String> _periods = ['24h', '7j', '30j'];

  ScreenshotController get bpmCtrl =>
      widget.bpmScreenshot ?? ScreenshotController();
  ScreenshotController get spo2Ctrl =>
      widget.spo2Screenshot ?? ScreenshotController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadThresholds();
    _loadVitals();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Méthode exposée pour changer période depuis MainScreen ──
  Future<void> switchPeriodAndCapture(String period) async {
    setState(() {
      _period = period;
    });
    await _loadVitals();
    await Future.delayed(Duration(milliseconds: 800));
  }

  // ── Méthode exposée pour changer onglet ──
  void switchTab(int index) {
    _tabController.animateTo(index);
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

  Future<void> _loadVitals() async {
    setState(() => _isLoading = true);
    try {
      DateTime since;
      final now = DateTime.now();
      switch (_period) {
        case '7j':
          since = now.subtract(Duration(days: 7));
          break;
        case '30j':
          since = now.subtract(Duration(days: 30));
          break;
        default:
          since = now.subtract(Duration(hours: 24));
      }

      final data = await Supabase.instance.client
          .from('vitals')
          .select('heart_rate, spo2, temperature, timestamp')
          .eq('patient_id', widget.patientId)
          .gte('timestamp', since.toIso8601String())
          .order('timestamp', ascending: true)
          .limit(200);

      setState(() {
        _vitals = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<FlSpot> _getSpots(String field) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _vitals.length; i++) {
      final val = _vitals[i][field];
      if (val != null)
        spots.add(FlSpot(i.toDouble(), double.parse(val.toString())));
    }
    return spots;
  }

  String _getXLabel(int index) {
    if (index < 0 || index >= _vitals.length) return '';
    final ts = _vitals[index]['timestamp'];
    if (ts == null) return '';
    final dt = DateTime.tryParse(ts)?.toLocal();
    if (dt == null) return '';
    if (_period == '24h') return "${dt.hour}h";
    return "${dt.day}/${dt.month}";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Période selector
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                "Période :",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B3F6B),
                ),
              ),
              SizedBox(width: 12),
              ..._periods.map(
                (p) => Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _period = p);
                      _loadVitals();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _period == p
                            ? Color(0xFF1B3F6B)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        p,
                        style: TextStyle(
                          color: _period == p ? Colors.white : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh, color: Color(0xFF1B3F6B)),
                onPressed: _loadVitals,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ),

        // Tabs — seulement BPM et SpO2
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Color(0xFF1B3F6B),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF1B3F6B),
            tabs: [
              Tab(icon: Icon(Icons.favorite, size: 18), text: "BPM"),
              Tab(icon: Icon(Icons.air, size: 18), text: "SpO2"),
            ],
          ),
        ),

        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(color: Color(0xFF1B3F6B)),
                )
              : _vitals.isEmpty
              ? _buildEmptyState()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildChartTab(
                      screenshotController: bpmCtrl,
                      label: "Frequence Cardiaque",
                      unit: "bpm",
                      color: Colors.red,
                      spots: _getSpots('heart_rate'),
                      minThreshold: bpmMin.toDouble(),
                      maxThreshold: bpmMax.toDouble(),
                      minY: 30,
                      maxY: 180,
                    ),
                    _buildChartTab(
                      screenshotController: spo2Ctrl,
                      label: "Saturation O2",
                      unit: "%",
                      color: Colors.blue,
                      spots: _getSpots('spo2'),
                      minThreshold: spo2Min,
                      maxThreshold: null,
                      minY: 80,
                      maxY: 100,
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey.shade300),
          SizedBox(height: 16),
          Text(
            "Aucune donnee",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Les donnees apparaitront ici",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildChartTab({
    required ScreenshotController screenshotController,
    required String label,
    required String unit,
    required Color color,
    required List<FlSpot> spots,
    required double? minThreshold,
    required double? maxThreshold,
    required double minY,
    required double maxY,
  }) {
    if (spots.isEmpty) return _buildEmptyState();

    final values = spots.map((s) => s.y).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    int anomalies = 0;
    for (final v in values) {
      if (minThreshold != null && v < minThreshold)
        anomalies++;
      else if (maxThreshold != null && v > maxThreshold)
        anomalies++;
    }

    final chartWidget = Screenshot(
      controller: screenshotController,
      child: Container(
        color: Colors.white,
        height: 280,
        padding: EdgeInsets.all(16),
        child: LineChart(
          LineChartData(
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: (maxY - minY) / 5,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: Colors.grey.shade100, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  interval: (maxY - minY) / 5,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: spots.length > 10
                      ? (spots.length / 5).roundToDouble()
                      : 1,
                  getTitlesWidget: (value, meta) => Text(
                    _getXLabel(value.toInt()),
                    style: TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (minThreshold != null)
                  HorizontalLine(
                    y: minThreshold,
                    color: Colors.orange.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (line) =>
                          "min: ${minThreshold.toStringAsFixed(1)}",
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (maxThreshold != null)
                  HorizontalLine(
                    y: maxThreshold,
                    color: Colors.red.withOpacity(0.7),
                    strokeWidth: 1.5,
                    dashArray: [5, 5],
                    label: HorizontalLineLabel(
                      show: true,
                      labelResolver: (line) =>
                          "max: ${maxThreshold.toStringAsFixed(1)}",
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: spots.length < 30,
                  getDotPainter: (spot, percent, barData, index) {
                    bool isAnomaly =
                        (minThreshold != null && spot.y < minThreshold) ||
                        (maxThreshold != null && spot.y > maxThreshold);
                    return FlDotCirclePainter(
                      radius: 3,
                      color: isAnomaly ? Colors.red : color,
                      strokeWidth: 0,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: color.withOpacity(0.08),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (spot) => Color(0xFF1B3F6B),
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
                        "${s.y.toStringAsFixed(1)} $unit",
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ),
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statCard(
                "Moyenne",
                "${avg.toStringAsFixed(1)} $unit",
                Colors.blue,
              ),
              SizedBox(width: 8),
              _statCard("Min", "${min.toStringAsFixed(1)} $unit", Colors.green),
              SizedBox(width: 8),
              _statCard(
                "Max",
                "${max.toStringAsFixed(1)} $unit",
                Colors.orange,
              ),
              SizedBox(width: 8),
              _statCard(
                "Anomalies",
                "$anomalies",
                anomalies > 0 ? Colors.red : Colors.green,
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              _legendItem(color, label),
              SizedBox(width: 16),
              if (minThreshold != null)
                _legendItem(Colors.orange.withOpacity(0.7), "Seuil min"),
              SizedBox(width: 8),
              if (maxThreshold != null)
                _legendItem(Colors.red.withOpacity(0.7), "Seuil max"),
            ],
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: chartWidget,
            ),
          ),
          SizedBox(height: 20),
          if (anomalies > 0)
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "$anomalies valeur(s) hors seuil detectee(s) sur la periode.",
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 13,
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

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
