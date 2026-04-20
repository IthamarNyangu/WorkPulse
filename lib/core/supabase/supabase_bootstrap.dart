import 'package:flutter/foundation.dart';
import 'package:pulseclock/core/config/app_env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract final class SupabaseBootstrap {
  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized || !AppEnv.hasSupabaseConfig) {
      if (!_isInitialized && !AppEnv.hasSupabaseConfig) {
        debugPrint(
          'Supabase not initialized. Missing: ${AppEnv.missingKeys.join(', ')}',
        );
      }
      return;
    }

    await Supabase.initialize(
      url: AppEnv.supabaseUrl,
      anonKey: AppEnv.supabaseAnonKey,
    );
    _isInitialized = true;
  }

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError(
        'Supabase is not initialized. Run with SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }
    return Supabase.instance.client;
  }
}
