import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';

class EnterCodeScreen extends StatefulWidget {
  @override
  _EnterCodeScreenState createState() => _EnterCodeScreenState();
}

class _EnterCodeScreenState extends State<EnterCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _error = "Entrez le code reçu du médecin");
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      // Chercher le patient avec ce code
      final patient = await Supabase.instance.client
          .from('patients')
          .select('id, name, age')
          .eq('share_code', code)
          .maybeSingle();

      if (patient == null) {
        setState(() {
          _error = "Code invalide. Vérifiez avec votre médecin.";
          _isLoading = false;
        });
        return;
      }

      final patientId = patient['id'];
      final familyUserId = Supabase.instance.client.auth.currentUser!.id;

      // Vérifier si accès déjà existant
      final existingAccess = await Supabase.instance.client
          .from('family_access')
          .select('id')
          .eq('patient_id', patientId)
          .eq('family_user_id', familyUserId)
          .maybeSingle();

      // Créer l'accès famille si pas encore existant
      if (existingAccess == null) {
        await Supabase.instance.client.from('family_access').insert({
          'patient_id': patientId,
          'family_user_id': familyUserId,
        });
      }

      if (!mounted) return;

      // Naviguer vers le dashboard famille
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => MainScreen(patientId: patientId, role: 'family'),
        ),
      );

    } catch (e) {
      setState(() {
        _error = "Erreur : $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Accès Patient"),
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 40),

            // Icône
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Color(0xFF1B3F6B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.vpn_key_rounded, size: 52, color: Color(0xFF1B3F6B)),
            ),

            SizedBox(height: 24),

            Text(
              "Entrez le code",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B3F6B)),
            ),
            SizedBox(height: 8),
            Text(
              "Votre médecin vous a fourni un code\npour accéder au suivi du patient.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),

            SizedBox(height: 40),

            // Champ code
            TextField(
              controller: _codeController,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: Color(0xFF1B3F6B),
              ),
              decoration: InputDecoration(
                hintText: "SC-XXXX",
                hintStyle: TextStyle(
                  fontSize: 28,
                  color: Colors.grey.shade300,
                  letterSpacing: 6,
                ),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Color(0xFF1B3F6B), width: 2),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.red, width: 2),
                ),
              ),
              onChanged: (v) {
                // Auto-formater : SC-XXXX
                if (v.length == 2 && !v.contains('-')) {
                  _codeController.text = v + '-';
                  _codeController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _codeController.text.length),
                  );
                }
                setState(() => _error = null);
              },
            ),

            // Erreur
            if (_error != null) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red, fontSize: 13))),
                  ],
                ),
              ),
            ],

            SizedBox(height: 32),

            // Bouton valider
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF1B3F6B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "ACCÉDER AU SUIVI",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
              ),
            ),

            SizedBox(height: 24),

            // Info
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Le code est fourni par votre médecin lors de la création du dossier patient.",
                      style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
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
}