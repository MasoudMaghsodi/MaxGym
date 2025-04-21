import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'https://rdpkrdfgsamhlrfdlehx.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJkcGtyZGZnc2FtaGxyZmRsZWh4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUxNDUxMDEsImV4cCI6MjA2MDcyMTEwMX0.AYHhZTWLNLopxn08-8JQyZFFCc8-LR1sRbR9pGSqBA0',
    );
  }
}
