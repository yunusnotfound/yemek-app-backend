import '../../data/models/user_model.dart';
import '../../data/repositories/auth_repository_impl.dart';

abstract class AuthRepository {
  /// Request a one-time login code for [email].
  /// Returns whether the email belongs to a brand-new account.
  Future<OtpRequestResult> requestOtp(String email);

  /// Verify the OTP [code] for [email]. For new accounts [name] is required.
  Future<AuthResult> verifyOtp({
    required String email,
    required String code,
    String? name,
    String? phone,
  });

  Future<void> logout();

  Future<AuthResult> googleLogin({required String role});

  Future<AuthResult> appleLogin({required String role});

  Future<String?> getAccessToken();

  Future<String?> getRefreshToken();

  Future<bool> isLoggedIn();

  Future<String?> getSavedUserRole();

  Future<UserModel?> getCurrentUser();
}
