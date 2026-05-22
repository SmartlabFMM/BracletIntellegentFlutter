import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class CreatePatientScreen extends StatefulWidget {
  @override
  _CreatePatientScreenState createState() => _CreatePatientScreenState();
}

class _CreatePatientScreenState extends State<CreatePatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();

  bool _isLoading = false;

  final Map<String, bool> _diseases = {
    "Diabète": false,
    "Alzheimer": false,
    "Arythmie": false,
    "BPCO": false,
    "Hypertension": false,
    "Insuffisance cardiaque": false,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    super.dispose();
  }

  // Générer un code unique ex: SC-4829
  String _generateShareCode() {
    final random = Random();
    final number = random.nextInt(9000) + 1000;
    return "SC-$number";
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Nom obligatoire";
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(value.trim()))
      return "Lettres uniquement";
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value ?? "");
    if (value == null || value.trim().isEmpty) return "Âge obligatoire";
    if (age == null || age < 0 || age > 120) return "Âge invalide";
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return "Contact obligatoire";
    final cleaned = value.trim().replaceAll(' ', '');
    if (!RegExp(r"^\+216[0-9]{8}$").hasMatch(cleaned))
      return "Format : +216XXXXXXXX";
    return null;
  }

  void _createPatient() async {
    if (!_formKey.currentState!.validate()) return;

    final selectedDiseases = _diseases.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedDiseases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sélectionnez au moins une maladie")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      String shareCode = _generateShareCode();

      // Vérifier unicité du code
      bool codeExists = true;
      while (codeExists) {
        final existing = await Supabase.instance.client
            .from('patients')
            .select('id')
            .eq('share_code', shareCode)
            .maybeSingle();
        if (existing == null) {
          codeExists = false;
        } else {
          shareCode = _generateShareCode();
        }
      }

      // Créer le patient
      final patient = await Supabase.instance.client
          .from('patients')
          .insert({
            'user_id': userId,
            'doctor_id': userId,
            'name': _nameController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
            'diseases': selectedDiseases,
            'contact1': _contact1Controller.text.trim().replaceAll(' ', ''),
            'contact2': _contact2Controller.text.trim().replaceAll(' ', ''),
            'share_code': shareCode,
          })
          .select('id, share_code')
          .single();

      // Insérer seuils par défaut
      await Supabase.instance.client.from('thresholds').insert({
        'patient_id': patient['id'],
        'bpm_min': 50,
        'bpm_max': 120,
        'spo2_min': 90.0,
        'temp_min': 35.0,
        'temp_max': 38.5,
      });

      if (!mounted) return;

      // Afficher le code généré
      _showCodeDialog(shareCode, patient['id']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCodeDialog(String code, String patientId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, color: Colors.green, size: 36),
            ),
            SizedBox(height: 12),
            Text(
              "Patient créé !",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B3F6B),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Partagez ce code avec la famille du patient :",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            SizedBox(height: 20),
            // Code affiché
            Container(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Color(0xFF1B3F6B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                code,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
            SizedBox(height: 12),
            // Bouton copier
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Code copié !"),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              icon: Icon(Icons.copy, size: 16),
              label: Text("Copier le code"),
            ),
            SizedBox(height: 8),
            Text(
              "La famille doit entrer ce code dans l'application pour accéder au suivi.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Fermer dialog
                Navigator.pop(context); // Retour liste patients
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1B3F6B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                "Terminer",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Nouveau Patient"),
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF1B3F6B).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFF1B3F6B).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF1B3F6B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Un code de partage sera généré automatiquement pour la famille.",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1B3F6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 24),
              _sectionTitle("Informations personnelles"),
              _buildField(
                _nameController,
                "Nom complet",
                Icons.person_outline,
                _validateName,
              ),
              SizedBox(height: 12),
              _buildField(
                _ageController,
                "Âge",
                Icons.cake_outlined,
                _validateAge,
                TextInputType.number,
              ),

              SizedBox(height: 24),
              _sectionTitle("Maladies diagnostiquées"),
              _buildDiseaseList(),

              SizedBox(height: 24),
              _sectionTitle("Contacts d'urgence"),
              _buildField(
                _contact1Controller,
                "Contact 1 (+216XXXXXXXX)",
                Icons.phone_outlined,
                _validatePhone,
                TextInputType.phone,
              ),
              SizedBox(height: 12),
              _buildField(
                _contact2Controller,
                "Contact 2 (+216XXXXXXXX)",
                Icons.phone_outlined,
                _validatePhone,
                TextInputType.phone,
              ),

              SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _createPatient,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.person_add, color: Colors.white),
                  label: Text(
                    "CRÉER LE PATIENT",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B3F6B),
      ),
    ),
  );

  Widget _buildField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String? Function(String?) validator, [
    TextInputType type = TextInputType.text,
  ]) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF1B3F6B)),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF1B3F6B), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade200),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
      ),
    );
  }

  Widget _buildDiseaseList() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
      ],
    ),
    child: Column(
      children: _diseases.keys
          .map(
            (d) => CheckboxListTile(
              title: Text(d, style: TextStyle(fontSize: 14)),
              value: _diseases[d],
              activeColor: Color(0xFF1B3F6B),
              onChanged: (v) => setState(() => _diseases[d] = v!),
            ),
          )
          .toList(),
    ),
  );
}
