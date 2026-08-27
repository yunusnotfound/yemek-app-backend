import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının bu cihazda daha önce hesabına girip girmediğini tutar.
///
/// Tek amacı: bir kez giriş yapmış kullanıcıya tanıtım (onboarding) ekranını
/// bir daha göstermemek. Çıkış yapan ya da oturumu düşen kullanıcı doğrudan
/// giriş ekranına gider — üç tanıtım sayfasını yeniden geçmesi gerekmez.
///
/// NEDEN AYRI BİR KATMAN: bu işaret [TokenStorage]'ta DURMAMALI. Oradaki
/// `clearTokens()` çıkışta her şeyi siler; işaret de silinseydi kullanıcı her
/// çıkışta tanıtımı yeniden görürdü — yani çözmek istediğimiz sorun aynen
/// devam ederdi.
///
/// Ayrıca bilinçli olarak secure storage değil `SharedPreferences` kullanılır:
/// bu bir sır değildir ve iOS'ta Keychain kayıtları uygulama silinip yeniden
/// kurulduğunda bile kalabildiğinden, temiz bir kurulumda tanıtımın yine
/// gösterilmesi için uygulamayla birlikte silinen depolama doğru olandır.
abstract class OnboardingStorage {
  /// Bu cihazda daha önce başarılı bir giriş yapıldı mı?
  Future<bool> hasSignedInBefore();

  /// Başarılı girişten sonra çağrılır. Tekrar tekrar çağrılması zararsızdır.
  Future<void> markSignedIn();
}

class PrefsOnboardingStorage implements OnboardingStorage {
  static const String _key = 'has_signed_in_before';

  @override
  Future<bool> hasSignedInBefore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      // Depolama okunamıyorsa tanıtımı göstermek güvenli varsayılandır:
      // kullanıcıyı giriş ekranında kilitlemektense fazladan bir ekran gösterilir.
      return false;
    }
  }

  @override
  Future<void> markSignedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, true);
    } catch (_) {
      // Yazılamazsa sessizce geç: girişin kendisi başarısız sayılmamalı.
    }
  }
}

OnboardingStorage createDefaultOnboardingStorage() => PrefsOnboardingStorage();
