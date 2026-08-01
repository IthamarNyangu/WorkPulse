import 'package:pulseclock/core/supabase/supabase_bootstrap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeviceTokenService {
  DeviceTokenService({SupabaseClient? client})
    : _client = client ?? SupabaseBootstrap.client;

  final SupabaseClient _client;

  Future<void> registerAndroidToken(String token) async {
    await _client.rpc<void>(
      'register_device_token',
      params: <String, dynamic>{
        'p_token': token,
        'p_platform': 'android',
      },
    );
  }

  Future<void> unregisterToken(String token) async {
    await _client.rpc<void>(
      'unregister_device_token',
      params: <String, dynamic>{'p_token': token},
    );
  }
}
