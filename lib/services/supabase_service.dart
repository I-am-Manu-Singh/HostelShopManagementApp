import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://kuttseqqxdfqbzekgqll.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_2x-gJ3yNhM9yooDcEdeuWA_HQ379KgN';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  final _supabase = Supabase.instance.client;

  SupabaseClient get client => _supabase;

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
