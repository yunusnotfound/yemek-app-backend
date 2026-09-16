# Mobil platform uyumluluğu ve son doğrulama

8 Eylül 2026. İnceleme, çalışma dizinindeki güncel kaynaklar ve kurulu Flutter 3.41.5 / çözümlenmiş bağımlılık dosyaları üzerinden yapıldı. iOS profil çalışmasının ayrı staging dizinine dokunulmadı.

## Doğrulama

- `flutter analyze --no-pub lib test integration_test/phone_performance_test.dart test_driver/phone_performance.dart`: başarılı, sorun yok. Log: `flutter-analyze-final.log`.
- `flutter test --no-pub test --reporter expanded`: **41/41 başarılı**. Log: `flutter-unit-tests-final.log`.
- Yukarıdaki test sayısı fiziksel cihaz entegrasyon koşumunu içermez; entegrasyon testi ve sürücüsü statik analize dahildir.
- Önceki `design_ui_test.dart` lint uyarısı son koşumda yoktu; bu inceleme o dosyayı değiştirmedi.
- Kaynak parmak izleri: `mobile-validation-source-fingerprints.json`.

## iPhone 11 / iOS

Runner hedefinin Debug, Profile ve Release yapılandırmalarında `IPHONEOS_DEPLOYMENT_TARGET = 15.6` vardır: `ios/Runner.xcodeproj/project.pbxproj`, satırlar 501, 689 ve 717. Proje düzeyindeki 13.0 değeri Runner hedefinin açık 15.6 değeri tarafından geçersiz kılınır.

Podfile alt sınırı 14.0'dır ve pod hedefleri de 14.0'a ayarlanır (`ios/Podfile:2`, `:47`). Çözümlenmiş `mapbox_maps_flutter 2.21.0` podspec ve Swift Package bildirimi de iOS 14.0 ister. Dolayısıyla uygulamanın geçerli alt sınırı **iOS 15.6**; Podfile yorumuna bakarak iOS 14 desteği iddia edilmemelidir.

iPhone 11, iOS 15.6 veya üstü yüklüyse bu sürüm hedefini karşılar. Apple iOS 15.6'nın iPhone 6s ve daha yenileri için kullanılabilir olduğunu belirtir: [Apple iOS 15.6 destek kaydı](https://support.apple.com/en-la/102892). Bu, iPhone 11 üzerinde ölçülmüş FPS veya fiziksel cihaz testi sonucu değildir.

Yeni hız düzeltmeleri Flutter/Dart katmanındadır; iOS native hedeflerini veya pod sürümlerini değiştirmedi. Eklenen `integration_test` geliştirme bağımlılığıdır. Native üretim bağımlılık sürümleri `pubspec.lock` farkında değiştirilmemiştir.

## Android

Somut eski yapılandırma uyumsuzluğu bulundu ve yalnız bir satır düzeltildi:

```diff
- minSdk = 21
+ minSdk = flutter.minSdkVersion
```

Dosya: `android/app/build.gradle.kts:45`. İmza, package ID, targetSdk, compileSdk ve manifest ayarları korunmuştur.

Kurulu Flutter 3.41.5'in `packages/flutter_tools/gradle/src/main/kotlin/FlutterExtension.kt` dosyası **minSdkVersion 24**, compileSdkVersion 36 ve targetSdkVersion 36 tanımlar (satırlar 23, 26, 34). `.dart_tool/package_config.json` ile doğrulanan `shared_preferences_android 2.4.20` paketinin `android/build.gradle:53` dosyası minimum 24 ister. `geolocator_android 4.6.2/android/build.gradle:32` de `flutter.minSdkVersion` kullanır. Önceki minimum 21 bu bağımlılık alt sınırını karşılamıyordu.

Yeni ayarın gerçek alt sınırı **API 24 / Android 7.0**'dır. API 21 / Android 5 desteği iddia edilmez. [Resmi Flutter 3.35 duyurusu](https://flutter.dev/blog/whats-new-in-flutter-3-35) da Flutter'ın minimum Android SDK değerinin API 24 olduğunu doğrular.

Ana manifestte internet, hassas/yaklaşık konum izinleri ve donanım hızlandırma açık. Harita, konum ve mevcut HTTPS ağ kullanımının ihtiyaçları korunuyor. `usesCleartextTraffic=false` korunmuştur; geliştirme için üretim ağ güvenliği gevşetilmemiştir.

Bu makinede `ANDROID_HOME` / `ANDROID_SDK_ROOT` ayarlı değil ve standart Android SDK dizini bulunmuyor. Son `flutter doctor` kaydı `flutter-doctor-final.log` dosyasına alınmıştır. Bu nedenle Android APK/manifest birleştirme veya Android fiziksel cihaz çalışması bu doğrulamaya dahil değildir. SDK hedeflerini hizalamak, cihaz üzerinde performans sonucu elde edildiği anlamına gelmez.
