import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:math';

import '../../../../config/constants.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage;

  @override
  Future<OtpRequestResult> requestOtp(String email) async {
    try {
      final response = await _remoteDataSource.requestOtp(email);
      final isNewUser = response['isNewUser'] as bool? ?? false;
      final message =
          response['message'] as String? ?? 'Giriş kodu gönderildi';
      return OtpRequestResult.success(isNewUser: isNewUser, message: message);
    } on AuthException catch (e) {
      return OtpRequestResult.failure(e.message);
    } catch (e) {
      return OtpRequestResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
    String? name,
    String? phone,
  }) async {
    try {
      final response = await _remoteDataSource.verifyOtp(
        email: email,
        code: code,
        name: name,
        phone: phone,
      );

      final accessToken = response['accessToken'] as String?;
      final refreshToken = response['refreshToken'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userData == null) {
        return AuthResult.failure('Giriş bilgileri alınamadı');
      }

      // Save tokens and user data
      await _tokenStorage.saveAccessToken(accessToken);
      await _tokenStorage.saveRefreshToken(refreshToken);

      final user = UserModel.fromJson(userData);
      await _tokenStorage.saveUserRole(user.role);
      await _tokenStorage.saveUserData(jsonEncode(user.toJson()));

      return AuthResult.success(user: user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Bir hata oluştu: $e');
    }
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
    await _tokenStorage.clearTokens();
  }

  @override
  Future<AuthResult> googleLogin({required String role}) async {
    try {
      final clientId = AppConstants.googleClientId;

      final googleSignIn = GoogleSignIn(
        clientId: clientId.isNotEmpty ? clientId : null,
        serverClientId: clientId.isNotEmpty ? clientId : null,
        scopes: ['email', 'profile'],
      );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google ile giriş iptal edildi');
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        return AuthResult.failure('Google kimlik doğrulama başarısız');
      }

      final response = await _remoteDataSource.googleLogin(
        idToken: idToken,
        role: role,
      );

      final accessToken = response['accessToken'] as String?;
      final refreshToken = response['refreshToken'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userData == null) {
        return AuthResult.failure('Giriş bilgileri alınamadı');
      }

      await _tokenStorage.saveAccessToken(accessToken);
      await _tokenStorage.saveRefreshToken(refreshToken);

      final user = UserModel.fromJson(userData);
      await _tokenStorage.saveUserRole(user.role);
      await _tokenStorage.saveUserData(jsonEncode(user.toJson()));

      return AuthResult.success(user: user);
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Google ile giriş başarısız: $e');
    }
  }

  @override
  Future<AuthResult> appleLogin({required String role}) async {
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final identityToken = credential.identityToken;
      if (identityToken == null) {
        return AuthResult.failure('Apple kimlik doğrulama başarısız');
      }

      // Build full name from Apple credential
      String? fullName;
      if (credential.givenName != null || credential.familyName != null) {
        fullName = [
          credential.givenName,
          credential.familyName,
        ].where((e) => e != null && e.isNotEmpty).join(' ');
        if (fullName.isEmpty) fullName = null;
      }

      final response = await _remoteDataSource.appleLogin(
        identityToken: identityToken,
        userIdentifier: credential.userIdentifier ?? '',
        email: credential.email,
        fullName: fullName,
        role: role,
      );

      final accessToken = response['accessToken'] as String?;
      final refreshToken = response['refreshToken'] as String?;
      final userData = response['user'] as Map<String, dynamic>?;

      if (accessToken == null || refreshToken == null || userData == null) {
        return AuthResult.failure('Giriş bilgileri alınamadı');
      }

      await _tokenStorage.saveAccessToken(accessToken);
      await _tokenStorage.saveRefreshToken(refreshToken);

      final user = UserModel.fromJson(userData);
      await _tokenStorage.saveUserRole(user.role);
      await _tokenStorage.saveUserData(jsonEncode(user.toJson()));

      return AuthResult.success(user: user);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult.failure('Apple ile giriş iptal edildi');
      }
      return AuthResult.failure('Apple ile giriş başarısız: ${e.message}');
    } on AuthException catch (e) {
      return AuthResult.failure(e.message);
    } catch (e) {
      return AuthResult.failure('Apple ile giriş başarısız: $e');
    }
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<String?> getAccessToken() async {
    return await _tokenStorage.getAccessToken();
  }

  @override
  Future<String?> getRefreshToken() async {
    return await _tokenStorage.getRefreshToken();
  }

  @override
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null;
  }

  @override
  Future<String?> getSavedUserRole() async {
    return await _tokenStorage.getUserRole();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final userData = await _tokenStorage.getUserData();
      if (userData != null) {
        return UserModel.fromJson(jsonDecode(userData) as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

}

class AuthResult {
  final bool isSuccess;
  final UserModel? user;
  final String? message;
  final String? error;
  final String? registeredEmail;

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.error,
    this.registeredEmail,
  });

  factory AuthResult.success({
    UserModel? user,
    String? message,
    String? registeredEmail,
  }) {
    return AuthResult._(
      isSuccess: true,
      user: user,
      message: message,
      registeredEmail: registeredEmail,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}

class OtpRequestResult {
  final bool isSuccess;
  final bool isNewUser;
  final String? message;
  final String? error;

  OtpRequestResult._({
    required this.isSuccess,
    this.isNewUser = false,
    this.message,
    this.error,
  });

  factory OtpRequestResult.success({
    required bool isNewUser,
    String? message,
  }) {
    return OtpRequestResult._(
      isSuccess: true,
      isNewUser: isNewUser,
      message: message,
    );
  }

  factory OtpRequestResult.failure(String error) {
    return OtpRequestResult._(isSuccess: false, error: error);
  }
}
