import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/auth_remote_datasource.dart';

class AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  const AuthRepository(this.remoteDataSource);

  /// Verifies that the given phone and email belong to the same active
  /// account. The server performs the comparison and returns a single
  /// boolean, so no personal data is transferred and the account cannot be
  /// enumerated from the public API key.
  Future<bool> verifyAccountPhoneEmail({
    required String phone,
    required String email,
  }) {
    return remoteDataSource.verifyAccountPhoneEmail(
      phone: phone,
      email: email,
    );
  }

  /// Whether a phone number already has an account. Returns a boolean only.
  Future<bool> phoneExists(String phone) {
    return remoteDataSource.phoneExists(phone);
  }

  Future<Map<String, dynamic>?> getCurrentProfile() {
    return remoteDataSource.getCurrentProfile();
  }

    Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) {
    return remoteDataSource.signUp(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
  }

  Future<AuthResponse> signInWithPhone({
    required String phone,
    required String password,
  }) {
    return remoteDataSource.signInWithPhone(
      phone: phone,
      password: password,
    );
  }
Future<void> updateProfile({
    required String userId,
    required String phone,
    required String fullName,
    required String email,
  }) {
    return remoteDataSource.updateProfile(
      userId: userId,
      phone: phone,
      fullName: fullName,
      email: email,
    );
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
  }) {
    return remoteDataSource.createDefaultAddress(
      userId: userId,
      recipientName: recipientName,
      phone: phone,
      governorate: governorate,
      city: city,
      area: area,
      buildingNumber: buildingNumber,
      apartmentNumber: apartmentNumber,
      addressDetails: addressDetails,
    );
  }

  Future<void> signOut() {
    return remoteDataSource.signOut();
  }
}
