import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  }
  await Supabase.initialize(
    url: 'https://rdpkrdfgsamhlrfdlehx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkcGtyZGZnc2FtaGxyZmRsZWh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNDUxMDEsImV4cCI6MjA2MDcyMTEwMX0.AYHhZTWLNLopxn08-8JQyZFFCc8-LR1sRbR9pGSqBA0',
  );
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Max Gym',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DashboardScreen(),
    );
  }
}
