import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

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
      home: LoginScreen(),
    );
  }
}
