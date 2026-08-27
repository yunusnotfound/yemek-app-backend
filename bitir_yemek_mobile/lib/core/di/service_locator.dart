import '../network/dio_client.dart';
import '../storage/onboarding_storage.dart';
import '../storage/token_storage.dart';

/// Uygulama ömrü boyunca paylaşılan tekil örnekler.
///
/// Sayfa/bloc başına yeni `DioClient`/`TokenStorage` yaratmak yerine bunları
/// kullanın: HTTP bağlantı havuzu (keep-alive) korunur, interceptor'lar bir kez
/// kurulur ve tek bir token-refresh kuyruğu paylaşılır.
///
/// Dart top-level `final` değişkenleri ilk erişimde tembel (lazy) kurulur.
final TokenStorage appTokenStorage = createDefaultTokenStorage();
final DioClient appDioClient = DioClient(tokenStorage: appTokenStorage);

/// Tanıtım ekranının bir daha gösterilip gösterilmeyeceğini belirleyen işaret.
/// Bilerek [appTokenStorage]'tan ayrıdır — çıkışta silinmemesi gerekir.
final OnboardingStorage appOnboardingStorage = createDefaultOnboardingStorage();
