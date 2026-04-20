abstract final class AppEnv {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get hasSupabaseConfig {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  static List<String> get missingKeys {
    final List<String> keys = <String>[];
    if (supabaseUrl.isEmpty) {
      keys.add('SUPABASE_URL');
    }
    if (supabaseAnonKey.isEmpty) {
      keys.add('SUPABASE_ANON_KEY');
    }
    return List<String>.unmodifiable(keys);
  }
}
