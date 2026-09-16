import '../../../../core/storage/token_storage.dart';
import '../../../auth/data/models/user_model.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
    required TokenStorage tokenStorage,
  }) : _remoteDataSource = remoteDataSource,
       _tokenStorage = tokenStorage;

  @override
  Future<ProfileResult> getProfile() async {
    try {
      final response = await _remoteDataSource.getProfile();
      final userData = response['user'] as Map<String, dynamic>?;

      if (userData == null) {
        return ProfileResult.failure('Profil bilgileri alinamadi');
      }

      final user = UserModel.fromJson(userData);
      return ProfileResult.success(user: user);
    } on ProfileException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Bir hata olustu: $e');
    }
  }

  @override
  Future<ProfileResult> updateProfile({String? name, String? phone}) async {
    try {
      final response = await _remoteDataSource.updateProfile(
        name: name,
        phone: phone,
      );
      final userData = response['user'] as Map<String, dynamic>?;

      if (userData == null) {
        return ProfileResult.failure('Profil guncellenemedi');
      }

      final user = UserModel.fromJson(userData);
      return ProfileResult.success(
        user: user,
        message: response['message'] as String?,
      );
    } on ProfileException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Bir hata olustu: $e');
    }
  }

  @override
  Future<ProfileResult> deleteAccount() async {
    try {
      await _remoteDataSource.deleteAccount();
      await _tokenStorage.clearTokens();
      return ProfileResult.success(message: 'Hesabiniz basariyla silindi');
    } on ProfileException catch (e) {
      return ProfileResult.failure(e.message);
    } catch (e) {
      return ProfileResult.failure('Hesap silinirken bir hata olustu: $e');
    }
  }

  @override
  Future<void> logout() async {
    await _remoteDataSource.logout();
    await _tokenStorage.clearTokens();
  }
}
