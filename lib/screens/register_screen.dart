import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'enter_code_screen.dart';
import 'doctor_patients_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String role;
  const RegisterScreen({Key? key, this.role = 'family'}) : super(key: key);

  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength(String value) {
    setState(() {
      _hasMinLength = value.length >= 8;
      _hasUppercase = RegExp(r"[A-Z]").hasMatch(value);
      _hasLowercase = RegExp(r"[a-z]").hasMatch(value);
      _hasNumber = RegExp(r"[0-9]").hasMatch(value);
      _hasSpecial = RegExp(r"[!@#\$%^&*(),.?]").hasMatch(value);
    });
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return "Le nom est obligatoire";
    if (value.trim().length < 3) return "Minimum 3 caractères";
    if (!RegExp(r"^[a-zA-ZÀ-ÿ\s]+$").hasMatch(value.trim()))
      return "Lettres uniquement";
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return "L'email est obligatoire";
    if (!RegExp(r"^[\w.-]+@[\w.-]+\.[a-z]{2,}$").hasMatch(value.trim()))
      return "Email invalide";
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty)
      return "Le mot de passe est obligatoire";
    if (!(_hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecial))
      return "Mot de passe insuffisant";
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value != _passwordController.text)
      return "Les mots de passe ne correspondent pas";
    return null;
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Insérer dans profiles avec le rôle
        await Supabase.instance.client.from('profiles').insert({
          'id': response.user!.id,
          'role': widget.role,
        });

        if (!mounted) return;

        if (widget.role == 'doctor') {
          // Médecin → liste patients
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DoctorPatientsScreen()),
          );
        } else {
          // ✅ Famille → saisir le code du médecin (plus de QR)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => EnterCodeScreen()),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur : ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBackButton(),
                SizedBox(height: 32),
                _buildHeader(),
                SizedBox(height: 24),
                _buildRoleBadge(),
                SizedBox(height: 24),

                _buildLabel("Nom complet"),
                _buildTextFormField(
                  controller: _nameController,
                  hint: "",
                  icon: Icons.person_outline,
                  validator: _validateName,
                ),
                SizedBox(height: 16),

                _buildLabel("Email"),
                _buildTextFormField(
                  controller: _emailController,
                  hint: "",
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                SizedBox(height: 16),

                _buildLabel("Mot de passe"),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  onChanged: _checkPasswordStrength,
                  validator: _validatePassword,
                  decoration: _inputDecoration(
                    hint: "",
                    icon: Icons.lock_outline,
                    suffix: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                ),

                if (_passwordController.text.isNotEmpty)
                  _buildStrengthIndicator(),
                SizedBox(height: 16),

                _buildLabel("Confirmer mot de passe"),
                _buildTextFormField(
                  controller: _confirmController,
                  hint: "",
                  icon: Icons.lock_outline,
                  obscure: true,
                  validator: _validateConfirm,
                ),
                SizedBox(height: 32),

                _buildRegisterButton(),
                SizedBox(height: 24),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    final isDoctor = widget.role == 'doctor';
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDoctor
            ? Color(0xFF1B3F6B).withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDoctor ? Color(0xFF1B3F6B) : Colors.green,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isDoctor ? Icons.medical_services : Icons.family_restroom,
            color: isDoctor ? Color(0xFF1B3F6B) : Colors.green,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isDoctor ? "Compte Médecin" : "Compte Famille",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDoctor ? Color(0xFF1B3F6B) : Colors.green,
                ),
              ),
              Text(
                isDoctor
                    ? "Accès à tous vos patients"
                    : "Entrez le code fourni par votre médecin",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthIndicator() {
    return Container(
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _passwordRule(_hasMinLength, "8 caractères minimum"),
          _passwordRule(_hasUppercase, "1 lettre majuscule"),
          _passwordRule(_hasLowercase, "1 lettre minuscule"),
          _passwordRule(_hasNumber, "1 chiffre"),
          _passwordRule(_hasSpecial, "1 caractère spécial (!@#\$)"),
        ],
      ),
    );
  }

  Widget _passwordRule(bool isValid, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.cancel,
            color: isValid ? Colors.green : Colors.grey.shade300,
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? Colors.green : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF1B3F6B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
                "CRÉER MON COMPTE",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: _inputDecoration(hint: hint, icon: icon),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Color(0xFF1B3F6B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
    );
  }

  Widget _buildLabel(String text) => Padding(
    padding: EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1B3F6B),
      ),
    ),
  );

  Widget _buildBackButton() => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.arrow_back, color: Color(0xFF1B3F6B)),
    ),
  );

  Widget _buildHeader() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "Créer un compte",
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1B3F6B),
        ),
      ),
      Text(
        "Rejoignez SeniorCare AI",
        style: TextStyle(fontSize: 14, color: Colors.grey),
      ),
    ],
  );

  Widget _buildFooter() => Center(
    child: TextButton(
      onPressed: () => Navigator.pop(context),
      child: RichText(
        text: TextSpan(
          text: "Déjà un compte ? ",
          style: TextStyle(color: Colors.grey),
          children: [
            TextSpan(
              text: "Se connecter",
              style: TextStyle(
                color: Color(0xFF1B3F6B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

