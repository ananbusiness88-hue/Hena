import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/services/fcm_service.dart';

class AuthRemoteDataSource {
  final SupabaseClient client;
  const AuthRemoteDataSource(this.client);
  Future<bool> verifyAccountPhoneEmail({
    required String phone,
    required String email,
  }) async {
    final result = await client.rpc(
      'verify_account_phone_email',
      params: {'p_phone': phone, 'p_email': email},
    );

    return result == true;
  }

  Future<bool> phoneExists(String phone) async {
    final result = await client.rpc('phone_exists', params: {'p_phone': phone});

    return result == true;
  }

  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final user = client.auth.currentUser;
    if (user == null) {
      return null;
    }
    final result = await client.rpc('get_my_profile');
    if (result == null) {
      return null;
    }
    if (result is List) {
      if (result.isEmpty) {
        return null;
      }
      final first = result.first;
      if (first is Map) {
        return Map<String, dynamic>.from(first);
      }
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    throw StateError(
      'Unexpected get_my_profile response: '
      '${result.runtimeType}',
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    // The email is the authentication identity. The phone provider is disabled
    // in the project, so passing the phone to signUp fails with
    // "phone_provider_disabled". The phone is stored as profile data instead:
    // the handle_new_user trigger copies it from the user metadata into
    // public.profiles.phone.
    return client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'phone': phone, 'email': email},
    );
  }

  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final response = await client.functions.invoke(
      'phone_password_login',
      body: {'phone': phone, 'password': password},
    );

    final data = response.data;

    if (data is! Map) {
      throw StateError(
        'Unexpected phone_password_login response: '
        '${data.runtimeType}',
      );
    }

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw AuthException('Invalid authentication response.');
    }

    final sessionResponse = await client.auth.setSession(refreshToken);

    if (sessionResponse.session == null) {
      throw AuthException('Unable to establish authentication session.');
    }

    return sessionResponse;
  }

  Future<void> updateProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String email,
  }) async {
    await client
        .from('profiles')
        .update({
          'phone': phone,
          'full_name': fullName,
          'email': email,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', userId);
  }

  Future<void> createDefaultAddress({
    required String userId,
    required String recipientName,
    required String phone,
    required String governorate,
    required String city,
    required String area,
    required String buildingNumber,
    required String apartmentNumber,
    required String addressDetails,
  }) async {
    await client.from('addresses').insert({
      'user_id': userId,
      'label': '',
      'recipient_name': recipientName,
      'phone': phone,
      'governorate': governorate,
      'city': city,
      'area': area,
      'building_number': buildingNumber,
      'apartment_number': apartmentNumber,
      'address_details': addressDetails,
      'is_default': true,
    });
  }

  Future<void> signOut() async {
    await FcmService.instance.unregisterCurrentToken();
    await client.auth.signOut();
  }
}
