import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String _url = 'https://rgduddzzytnnjvzzxyrs.supabase.co';
  static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJnZHVkZHp6eXRubmp2enp4eXJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NzE4MzUsImV4cCI6MjA5MDM0NzgzNX0.8gKBtus7pArFyIO8aAtTTRrPBWLNZU2gG_GF9DQCN8w';

  Future<void> initialize() async {
    await Supabase.initialize(
      url: _url,
      anonKey: _anonKey,
    );
  }

  SupabaseClient get client => Supabase.instance.client;

  // --- Authentication ---

  Future<AuthResponse> signIn(String email, String password) async {
    return await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp(String email, String password) async {
    return await client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  bool get isAuthenticated => client.auth.currentSession != null;
  User? get currentUser => client.auth.currentUser;
}
