import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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

  // ── VALIDATIONS ──

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Nom obligatoire";
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(value.trim()))
      return "Lettres uniquement";
    return null;
  }

  String? _validateAge(String? value) {
    final age = int.tryParse(value ?? "");
    if (value == null || value.trim().isEmpty) return "Âge obligatoire";
    if (age == null || age < 0 || age > 100) return "Âge invalide (0-100)";
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || !RegExp(r"^\+216+ [0-9]{8}$").hasMatch(value.trim())) {
      return "Format : +216 XXXXXXXX";
    }
    return null;
  }

  // ── ACTIONS ──

  void _saveProfile() async {
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
      final user = Supabase.instance.client.auth.currentUser;
      final client = Supabase.instance.client.from('patients');

      final existing = await client
          .select('id')
          .eq('user_id', user!.id)
          .maybeSingle();

      final data = {
        'user_id': user.id,
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text.trim()),
        'diseases': selectedDiseases,
        'contact1': _contact1Controller.text.trim(),
        'contact2': _contact2Controller.text.trim(),
      };

      if (existing != null) {
        await client.update(data).eq('user_id', user.id);
      } else {
        await client.insert(data);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text("Profil du Patient"),
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
              _buildAvatar(),
              _sectionTitle("Informations personnelles"),
              _buildFormField(
                _nameController,
                "Nom complet",
                Icons.person_outline,
                _validateName,
              ),
              _buildFormField(
                _ageController,
                "Âge",
                Icons.cake_outlined,
                _validateAge,
                TextInputType.number,
              ),

              _sectionTitle("Maladies diagnostiquées"),
              _buildDiseaseList(),

              _sectionTitle("Contacts d'urgence"),
              _buildFormField(
                _contact1Controller,
                "Contact 1",
                Icons.phone_outlined,
                _validatePhone,
                TextInputType.phone,
              ),
              _buildFormField(
                _contact2Controller,
                "Contact 2",
                Icons.phone_outlined,
                _validatePhone,
                TextInputType.phone,
              ),

              SizedBox(height: 32),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI HELPERS ──

  Widget _buildAvatar() => Center(
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF1B3F6B).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 48, color: Color(0xFF1B3F6B)),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1B3F6B),
      ),
    ),
  );

  Widget _buildFormField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    String? Function(String?) validator, [
    TextInputType type = TextInputType.text,
  ]) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF1B3F6B)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );

  Widget _buildDiseaseList() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
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

  Widget _buildSaveButton() => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _saveProfile,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF1B3F6B),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Text("SAUVEGARDER", style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
