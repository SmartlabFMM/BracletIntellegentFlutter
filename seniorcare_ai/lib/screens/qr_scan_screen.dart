import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'profile_screen.dart';

class QrScanScreen extends StatefulWidget {
  @override
  _QrScanScreenState createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _scanned = false;

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.first;
    if (barcode.rawValue != null) {
      setState(() { _scanned = true; });
      // QR scanné → aller vers profil patient
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ProfileScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("Scanner le Bracelet"),
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [

          // ── CAMERA ──
          MobileScanner(onDetect: _onDetect),

          // ── OVERLAY ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [

                // Cadre de scan
                Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Coins du cadre
                      _corner(top: 0, left: 0),
                      _corner(top: 0, right: 0, flipH: true),
                      _corner(bottom: 0, left: 0, flipV: true),
                      _corner(bottom: 0, right: 0, flipH: true, flipV: true),
                    ],
                  ),
                ),

                SizedBox(height: 32),

                Text(
                  "Pointez vers le QR code\ndu bracelet",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),

                SizedBox(height: 16),

                // Bouton ignorer (pour test sans bracelet)
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  },
                  child: Text(
                    "Passer cette étape →",
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget coin du cadre
  Widget _corner({
    double? top, double? bottom,
    double? left, double? right,
    bool flipH = false, bool flipV = false,
  }) {
    return Positioned(
      top: top, bottom: bottom,
      left: left, right: right,
      child: Transform.scale(
        scaleX: flipH ? -1 : 1,
        scaleY: flipV ? -1 : 1,
        child: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0xFF2E75B6), width: 4),
              left: BorderSide(color: Color(0xFF2E75B6), width: 4),
            ),
          ),
        ),
      ),
    );
  }
}