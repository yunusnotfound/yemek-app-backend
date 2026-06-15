import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/constants.dart';

abstract class TokenStorage {
  Future<void> saveAccessToken(String token);
  Future<void> saveRefreshToken(String token);
  Future<String?> getAccessToken();
  Future<String?> getRefreshToken();
  Future<void> saveUserRole(String role);
  Future<String?> getUserRole();
  Future<void> saveUserData(String json);
  Future<String?> getUserData();
  Future<void> clearTokens();
}

// Secure storage implementation for production
// Uses flutter_secure_storage for encrypted token storage
class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _secureStorage;

  SecureTokenStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage =
          secureStorage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  @override
  Future<void> saveAccessToken(String token) async {
    await _secureStorage.write(key: AppConstants.accessTokenKey, value: token);
  }

  @override
  Future<void> saveRefreshToken(String token) async {
    await _secureStorage.write(key: AppConstants.refreshTokenKey, value: token);
  }

  @override
  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: AppConstants.accessTokenKey);
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: AppConstants.refreshTokenKey);
  }

  @override
  Future<void> saveUserRole(String role) async {
    await _secureStorage.write(key: AppConstants.userRoleKey, value: role);
  }

  @override
  Future<String?> getUserRole() async {
    return await _secureStorage.read(key: AppConstants.userRoleKey);
  }

  @override
  Future<void> saveUserData(String json) async {
    await _secureStorage.write(key: AppConstants.userDataKey, value: json);
  }

  @override
  Future<String?> getUserData() async {
    return await _secureStorage.read(key: AppConstants.userDataKey);
  }

  @override
  Future<void> clearTokens() async {
    await _secureStorage.delete(key: AppConstants.accessTokenKey);
    await _secureStorage.delete(key: AppConstants.refreshTokenKey);
    await _secureStorage.delete(key: AppConstants.userRoleKey);
    await _secureStorage.delete(key: AppConstants.userDataKey);
  }
}

/// Factory function to create the default token storage.
/// Uses SecureTokenStorage for production security.
TokenStorage createDefaultTokenStorage() => SecureTokenStorage();
