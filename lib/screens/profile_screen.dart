import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatefulWidget {
  final String patientId;
  final String role;
  const ProfileScreen({Key? key, required this.patientId, this.role = 'doctor'})
    : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contact1Controller = TextEditingController();
  final _contact2Controller = TextEditingController();
  final _autresController = TextEditingController();

  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _autresChecked = false;

  bool get isReadOnly => widget.role == 'family';

  final Map<String, bool> _diseases = {
    "Diabète": false,
    "Hypertension": false,
    "BPCO": false,
    "Alzheimer": false,
    "Rhumatisme": false,
    "Cardiopathie": false,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contact1Controller.dispose();
    _contact2Controller.dispose();
    _autresController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    try {
      final data = await Supabase.instance.client
          .from('patients')
          .select()
          .eq('id', widget.patientId)
          .maybeSingle();

      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _ageController.text = (data['age'] ?? '').toString();
        _contact1Controller.text = data['contact1'] ?? '';
        _contact2Controller.text = data['contact2'] ?? '';

        final existingDiseases = List<String>.from(data['diseases'] ?? []);
        for (final disease in existingDiseases) {
          if (_diseases.containsKey(disease)) {
            _diseases[disease] = true;
          } else {
            _autresChecked = true;
            _autresController.text = disease;
          }
        }
      }
    } catch (e) {
      print('Erreur chargement: $e');
    } finally {
      setState(() => _isLoadingData = false);
    }
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
    if (age == null || age < 0 || age > 120) return "Âge invalide (0-120)";
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return "Contact obligatoire";
    if (!RegExp(
      r"^\+216[0-9]{8}$",
    ).hasMatch(value.trim().replaceAll(' ', ''))) {
      return "Format : +216XXXXXXXX";
    }
    return null;
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Famille → sauvegarder seulement les contacts
    if (isReadOnly) {
      setState(() => _isLoading = true);
      try {
        await Supabase.instance.client
            .from('patients')
            .update({
              'contact1': _contact1Controller.text.trim().replaceAll(' ', ''),
              'contact2': _contact2Controller.text.trim().replaceAll(' ', ''),
            })
            .eq('id', widget.patientId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Contacts mis à jour !"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Médecin → sauvegarder tout
    final selectedDiseases = _diseases.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (_autresChecked && _autresController.text.trim().isNotEmpty) {
      selectedDiseases.add(_autresController.text.trim());
    }

    if (selectedDiseases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sélectionnez au moins une maladie")),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('patients')
          .update({
            'name': _nameController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
            'diseases': selectedDiseases,
            'contact1': _contact1Controller.text.trim().replaceAll(' ', ''),
            'contact2': _contact2Controller.text.trim().replaceAll(' ', ''),
          })
          .eq('id', widget.patientId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Profil mis à jour !"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
      body: _isLoadingData
          ? Center(child: CircularProgressIndicator(color: Color(0xFF1B3F6B)))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatar(),
                    SizedBox(height: 24),

                    // Banner famille
                    if (isReadOnly) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "Seuls les contacts d'urgence peuvent être modifiés. Les informations médicales sont gérées par le médecin.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // ── Infos personnelles ──
                    _sectionTitle("Informations personnelles"),

                    // Nom — lecture seule pour famille
                    _buildFormField(
                      _nameController,
                      "Nom complet",
                      Icons.person_outline,
                      isReadOnly ? null : _validateName,
                      TextInputType.text,
                      isReadOnly,
                    ),
                    _buildFormField(
                      _ageController,
                      "Âge",
                      Icons.cake_outlined,
                      isReadOnly ? null : _validateAge,
                      TextInputType.number,
                      isReadOnly,
                    ),

                    // ── Maladies ──
                    _sectionTitle("Maladies diagnostiquées"),

                    if (isReadOnly)
                      // Famille → affichage simple
                      _buildDiseasesReadOnly()
                    else
                      // Médecin → checkboxes modifiables
                      _buildDiseaseList(),

                    // ── Contacts ──
                    _sectionTitle("Contacts d'urgence"),
                    _buildFormField(
                      _contact1Controller,
                      "Contact 1 (+216XXXXXXXX)",
                      Icons.phone_outlined,
                      _validatePhone,
                      TextInputType.phone,
                    ),
                    _buildFormField(
                      _contact2Controller,
                      "Contact 2 (+216XXXXXXXX)",
                      Icons.phone_outlined,
                      _validatePhone,
                      TextInputType.phone,
                    ),

                    SizedBox(height: 32),
                    _buildSaveButton(),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  // Maladies en lecture seule (famille)
  Widget _buildDiseasesReadOnly() {
    final allDiseases = [
      ..._diseases.entries.where((e) => e.value).map((e) => e.key),
      if (_autresChecked && _autresController.text.isNotEmpty)
        _autresController.text,
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: allDiseases.isEmpty
          ? Text(
              "Aucune maladie enregistrée",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allDiseases
                  .map(
                    (d) => Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFF1B3F6B).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Color(0xFF1B3F6B).withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.medical_services,
                            size: 12,
                            color: Color(0xFF1B3F6B),
                          ),
                          SizedBox(width: 4),
                          Text(
                            d,
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1B3F6B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  // Maladies modifiables (médecin)
  Widget _buildDiseaseList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: [
          ..._diseases.keys.map(
            (d) => CheckboxListTile(
              title: Text(d, style: TextStyle(fontSize: 14)),
              value: _diseases[d],
              activeColor: Color(0xFF1B3F6B),
              onChanged: (v) => setState(() => _diseases[d] = v!),
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          CheckboxListTile(
            title: Text(
              "Autres",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1B3F6B),
              ),
            ),
            value: _autresChecked,
            activeColor: Color(0xFF1B3F6B),
            onChanged: (v) {
              setState(() {
                _autresChecked = v!;
                if (!v) _autresController.clear();
              });
            },
          ),
          if (_autresChecked)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                controller: _autresController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Ex: Épilepsie, Parkinson...",
                  prefixIcon: Icon(
                    Icons.edit_outlined,
                    color: Color(0xFF1B3F6B),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Color(0xFF1B3F6B).withOpacity(0.05),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: Color(0xFF1B3F6B).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFF1B3F6B), width: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() => Center(
    child: Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1B3F6B).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 56, color: Color(0xFF1B3F6B)),
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
    String? Function(String?)? validator, [
    TextInputType type = TextInputType.text,
    bool readOnly = false, // ← positional optional parameter
  ]) => Padding(
    padding: EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      keyboardType: type,
      validator: validator,
      readOnly: readOnly,
      style: TextStyle(color: readOnly ? Colors.grey.shade600 : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: readOnly ? Colors.grey : Color(0xFF1B3F6B),
        ),
        suffixIcon: readOnly
            ? Icon(Icons.lock, size: 16, color: Colors.grey.shade400)
            : null,
        filled: true,
        fillColor: readOnly ? Colors.grey.shade50 : Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: readOnly ? Colors.grey.shade200 : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: readOnly ? Colors.grey.shade300 : Color(0xFF1B3F6B),
            width: 2,
          ),
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
    ),
  );

  Widget _buildSaveButton() {
    final label = isReadOnly ? "METTRE À JOUR LES CONTACTS" : "SAUVEGARDER";
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF1B3F6B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
                label,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
      ),
    );
  }
}
