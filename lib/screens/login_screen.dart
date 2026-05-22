import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';
import 'enter_code_screen.dart';
import 'main_screen.dart';
import 'doctor_patients_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _isLoading = true);

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null && mounted) {
        // Lire le rôle
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();

        final role = profile?['role'] ?? 'family';

        if (!mounted) return;

        if (role == 'doctor') {
          // Médecin → liste patients
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => DoctorPatientsScreen()),
          );
        } else {
          // Famille → vérifier si déjà lié à un patient via family_access
          final access = await Supabase.instance.client
              .from('family_access')
              .select('patient_id')
              .eq('family_user_id', response.user!.id)
              .maybeSingle();

          if (!mounted) return;

          if (access != null) {
            // Déjà lié → Dashboard directement
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    MainScreen(patientId: access['patient_id'], role: 'family'),
              ),
            );
          } else {
            // Pas encore lié → saisir le code
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => EnterCodeScreen()),
            );
          }
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 48),
              _buildLogoSection(),
              SizedBox(height: 48),

              _buildLabel("Email"),
              _buildTextField(
                controller: _emailController,
                hint: "exemple@email.com",
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),

              SizedBox(height: 20),
              _buildLabel("Mot de passe"),
              _buildTextField(
                controller: _passwordController,
                hint: "••••••••",
                icon: Icons.lock_outline,
                obscure: !_isPasswordVisible,
                suffix: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: () =>
                      setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),

              SizedBox(height: 32),
              _buildLoginButton(),
              SizedBox(height: 24),
              _buildRegisterSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterSection() {
    return Column(
      children: [
        Center(
          child: Text(
            "Pas encore de compte ?",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(role: 'family'),
                  ),
                ),
                icon: Icon(Icons.family_restroom, size: 18),
                label: Text("Famille"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green,
                  side: BorderSide(color: Colors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RegisterScreen(role: 'doctor'),
                  ),
                ),
                icon: Icon(Icons.medical_services, size: 18),
                label: Text("Médecin"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFF1B3F6B),
                  side: BorderSide(color: Color(0xFF1B3F6B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoSection() => Center(
    child: Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Color(0xFF1B3F6B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.monitor_heart, color: Colors.white, size: 45),
        ),
        SizedBox(height: 16),
        Text(
          "SeniorCare AI",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1B3F6B),
          ),
        ),
        Text(
          "Connectez-vous à votre compte",
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildLoginButton() => SizedBox(
    width: double.infinity,
    height: 54,
    child: ElevatedButton(
      onPressed: _isLoading ? null : _login,
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF1B3F6B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isLoading
          ? CircularProgressIndicator(color: Colors.white)
          : Text(
              "SE CONNECTER",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
    ),
  );

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: Color(0xFF1B3F6B)),
        suffixIcon: suffix,
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
      ),
    );
  }
}
