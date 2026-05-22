import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/doctor_patients_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://duqlioodzxbfqelpmvpa.supabase.co',
    anonKey: 'sb_publishable_xzqDiu3MTvPAa6m3W0NyZQ_NfL7aVdN',
  );

  runApp(SeniorCareApp());
}

class SeniorCareApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SeniorCare AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Color(0xFFF5F7FA),
      ),
      home: SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeIn));

    _textController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _textOpacity = Tween<double>(begin: 0, end: 1).animate(_textController);
    _textSlide = Tween<Offset>(
      begin: Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _textController, curve: Curves.easeOut));

    _progressController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    _progressValue = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _startAnimations();
  }

  void _startAnimations() async {
    await Future.delayed(Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(Duration(milliseconds: 500));
    _textController.forward();

    await Future.delayed(Duration(milliseconds: 300));
    _progressController.forward();

    await Future.delayed(Duration(milliseconds: 1800));
    _navigateNext();
  }

  void _navigateNext() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // Pas connecté → Login
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
      return;
    }

    // Connecté → lire le rôle
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', session.user.id)
          .maybeSingle();

      final role = profile?['role'] ?? 'family';

      if (!mounted) return;

      if (role == 'doctor') {
        // Médecin → liste patients
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => DoctorPatientsScreen(),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: Duration(milliseconds: 500),
          ),
        );
      } else {
        // Famille → chercher son patient
        final patient = await Supabase.instance.client
            .from('patients')
            .select('id')
            .eq('user_id', session.user.id)
            .maybeSingle();

        if (!mounted) return;

        if (patient != null) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  MainScreen(patientId: patient['id'], role: 'family'),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        } else {
          // Famille sans patient → Login
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => LoginScreen(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
              transitionDuration: Duration(milliseconds: 500),
            ),
          );
        }
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1B3F6B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.monitor_heart,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 32),

            SlideTransition(
              position: _textSlide,
              child: FadeTransition(
                opacity: _textOpacity,
                child: Column(
                  children: [
                    Text(
                      "SeniorCare AI",
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Surveillance médicale intelligente",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 60),

            AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return Column(
                  children: [
                    SizedBox(
                      width: 200,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progressValue.value,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      _progressValue.value < 0.5
                          ? "Initialisation..."
                          : _progressValue.value < 0.9
                          ? "Connexion..."
                          : "Prêt !",
                      style: TextStyle(fontSize: 12, color: Colors.white38),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
