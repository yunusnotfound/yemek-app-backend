# Google ile giriş yapılandırması

## Düzeltilen hata

Mobil uygulama aynı `GOOGLE_CLIENT_ID` değerini hem yerel `clientId` hem `serverClientId` olarak gönderiyordu. Yerel simülasyon ayarında bu değer, iOS `Info.plist` içindeki `GIDClientID` ile de aynıydı. iOS kimliği sunucu/web OAuth kimliği alanına gönderilmemeli.

Yeni yapılandırma, iOS'un mevcut yerel kimliğini `Info.plist` üzerinden kullanmasına izin verir. Mevcut yerel kurulumda Dart üzerinden bir sunucu kimliği gönderilmez; ID token'ın hedefi yerel iOS kimliği olur. Backend zaten bu kimliği doğrular. Sunucudaki imza, audience ve doğrulanmış e-posta kontrolleri korunmuştur.

## Ayarlar

| Hedef | Mobil ayarlar | Backend `GOOGLE_CLIENT_ID` |
| --- | --- | --- |
| Mevcut iOS kurulumu | `GIDClientID` ve ona ait ters URL şeması `ios/Runner/Info.plist` içinde; yeni Dart kimlikleri boş | Aynı yerel iOS istemci kimliği |
| iOS ve ortak web sunucu kimliği | `GOOGLE_IOS_CLIENT_ID` yerel iOS kimliği, `GOOGLE_SERVER_CLIENT_ID` ayrı web OAuth kimliği; URL şeması iOS kimliğiyle uyumlu olmalı | Web/sunucu kimliği |
| Android | `GOOGLE_SERVER_CLIENT_ID` web OAuth kimliği; geriye uyumluluk için yoksa `GOOGLE_CLIENT_ID` kullanılır. Android paket adı ve imza parmak izi Google projesinde ayrıca doğru tanımlanmalıdır. | Web/sunucu kimliği |
| Web | `GOOGLE_SERVER_CLIENT_ID` veya eski `GOOGLE_CLIENT_ID`, SDK'ya yalnız `clientId` olarak verilir. SDK'ya `serverClientId` gönderilmez. | Aynı web kimliği |

Kurulu iOS plugin sürümünde Dart üzerinden yalnız sunucu kimliği vermek yeterli değildir: yerel iOS kimliği de birlikte gerekir. Bu eksik ayar ve iki alanın aynı kimliği taşıması artık giriş başlamadan yakalanır. Google ayarları yalnız Google düğmesine basılınca oluşturulur; hatalı Google ayarı e-posta girişini engellemez.

`.vscode/mobile.local.json` gibi yerel dosyalara değişiklik yapıldıktan sonra uygulama yeni Dart tanımlarıyla yeniden derlenmelidir. Yalnız hot reload, derleme ortamı değerlerini güncellemez. Bu düzeltmede gerçek OAuth hesabı veya sunucu ortam değerleri değiştirilmedi.

## Hata davranışı

Boş ID token API'ye gönderilmez. Kullanıcı iptal edince ya da Google başarısız olunca mevcut uygulama oturumu üzerine yazılmaz. Native SDK hata ayrıntıları kullanıcıya ham biçimde gösterilmez. Backend'in güvenlik mesajları korunur; örneğin Gmail/Workspace dışı bir hesabın ilk eşlemesinde e-posta koduyla doğrulama istenebilir.

## Kaynaklar

- [Google: iOS ile backend kimlik doğrulaması](https://developers.google.com/identity/sign-in/ios/backend-auth)
- [Google: GIDConfiguration ve serverClientID](https://developers.google.com/identity/sign-in/ios/reference/Classes/GIDConfiguration)
- [Flutter Google Sign-In iOS kurulumu](https://pub.dev/packages/google_sign_in_ios)

Test dosyası: `bitir_yemek_mobile/test/google_sign_in_test.dart`. Google için 16 yeni test ve toplam 81 Flutter testi başarılı; genel Flutter analizi temiz. Gerçek GoogleSignIn Dart SDK'sı kullanılır; yalnız native kanal ve HTTP sınırları test çiftleriyle karşılanır. Gerçek hesaba giriş için son Google hesap/parola adımını kullanıcı tamamlar.
