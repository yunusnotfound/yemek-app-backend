# Bitir Gitsin mobil uygulaması

Flutter uygulaması. API yapılandırması ve ortam değişkenleri için
`lib/config/constants.dart` dosyasına bakın.

## Görseller ve uygulama boyutu

Güncel yaklaşım: sekiz kategori ve altı tanıtım/dekor görselinin büyük
sürümleri `https://api.bitirgitsin.com/uploads/app-artwork-v1/` üzerinden
Cloudflare CDN'den yüklenir. Uygulamada aynı görsellerin 128×128 küçük
önizlemeleri bulunur; toplamları **49.092 bayt**. Ağ yavaşken veya çevrimdışı
ilk açılışta önizleme görünür. Kaliteli görsel gelince yerini alır ve ortak
disk önbelleğine kaydedilir. Açılış, sürpriz kutu ve oyun akışları ağ yanıtını
beklemez. Logo, Google işareti, küçük yemek kutusu ve fontlar yerelde kalır.

Kendi paketlenen varlıklarımız artık **294.351 bayt**; önceki **23.707.673
bayta** göre **23.41 MB** azalma. Bu yalnız varlık ölçümüdür; release ve canlı
CDN doğrulamaları [CDN artwork raporunda](../docs/cdn-app-artwork-2026-09-25.md).
Orijinaller `assets/images/` altında tasarım/yayın kaynağı olarak korunur;
büyük dosyalar `pubspec.yaml` asset listesinde bulunmaz.

Aynı iOS release derleme yöntemiyle toplam yerel `.app` **88.42 MB → 65.01 MB**
ölçüldü. Bu, App Store/TestFlight indirme boyutu değildir; yeni build henüz
mağazaya yüklenmedi.

Önizlemeleri yeniden üretmek için Pillow ile:

```sh
python3 tool/generate_artwork_previews.py
```

Script yalnız açıkça listelenen 14 görseli işler; orijinalleri değiştirmez.
Üretim ayarları ve içerik hashleri
[manifestte](../docs/app-artwork-cdn-2026-09-25-assets.json) kayıtlıdır.
Yayımlanmış `app-artwork-v1` içerikleri değiştirilmemeli; görsel güncellemesi
yeni sürümlü dizin ve eşleşen uygulama URL'leriyle yapılmalı. Yeni görseller
resolver listesine ve pubspec önizleme listesine de eklenmelidir.

CDN taşınmasından önceki 25 Eylül ölçümü: paketlenen `assets/` dosyaları **34.94 MB → 24.78 MB**
(10.16 MB, %29.1 azalma). On beş büyük kategori/onboarding PNG dosyası kayıpsız
WebP'ye dönüştürüldü. Çözünürlük, şeffaflık ve bütün RGBA pikselleri Git'teki
orijinalleriyle karşılaştırılarak doğrulandı. ZIP benzeri sıkıştırmada bu
dosyaların kazancı yaklaşık 9.95 MB. Buradaki MB değeri 1.000.000 bayttır.

Aynı gün yapılan kullanım incelemesinde `pubspec.yaml` görsel listesi
daraltıldı: kullanılmayan `surprise-package.webp`, eski `firin-pastane.png`
ve yalnız launcher üretiminde kullanılan `app_icon_foreground.png` çalışma
zamanı paketinden çıkarıldı. Kaynak dosyalar diskte duruyor. Bu ek değişiklik
**1.07 MB** kazandırmış, CDN taşınması öncesinde uygulamanın kendi paketlenen
varlıklarını **23.71 MB** yapmıştı.

`AppCachedImage` ve harita logoları `https://api.bitirgitsin.com/uploads/`
altındaki public görselleri Cloudflare üzerinden küçülterek indirir.
`lib/core/utils/image_cdn.dart` ekrandaki genişlik × piksel yoğunluğunu
320/640/960/1280 genişliklerinden birine yuvarlar; boyut bilinmiyorsa 960 kullanır.
Her kaynak için en fazla dört varyant üretilir. Örnek:

```text
https://api.bitirgitsin.com/cdn-cgi/image/width=640,fit=scale-down,format=webp,quality=85,onerror=redirect/uploads/demo-catalog-v1/kafe.png
```

İstek `Accept: image/webp,image/jpeg,image/png;q=0.8` gönderir. Query string,
kimlik bilgisi, özel port, farklı domain veya zaten dönüştürülmüş adresler aynen
kullanılır. Query içindeki imza/token CDN URL'sine taşınmaz.

Cloudflare Images Free aylık 5.000 farklı dönüşümü ücretsiz sunar; sınır aşımı
ücret oluşturmaz. Yeni dönüşümlerdeki 9422 hatasında `onerror=redirect` aynı
zone içindeki orijinal görsele yönlendirir. Bu seçenek için orijinal
`/uploads/` yolunu tekrar dönüşüme sokan bir flow/rewrite kuralı kurulmamalıdır.
[Fiyatlandırma](https://developers.cloudflare.com/images/pricing/) ve
[URL dönüşüm seçenekleri](https://developers.cloudflare.com/images/optimization/features/).

Harita logoları ve kartlar aynı disk önbelleğini paylaşır. Dosya indirilirken
cihazda tekrar PNG üretilmez; görsel, üst bileşenin boyutu ve ekran yoğunluğuna
göre çözülür. On beş saniye sonra yükleme göstergesi yerine yedek içerik görünür;
daha geç gelen görsel de gösterilir.

Bu değişikliklerin telefona ulaşması için yeni mobil sürüm derlenip dağıtılmalı.
CDN sunucudaki görsellerin aktarımını hızlandırır; uygulama paketini küçültmez.

## Küçük release çıktısı oluşturma

Android için `android/key.properties` ve Android SDK gerekir. İmza örneği
`android/key.properties.example` dosyasındadır. R8 ve kaynak küçültme release
yapılandırmasında açıktır.

Google Play'e yüklemek için AAB; doğrudan APK paylaşılacaksa cihaz mimarisine
göre ayrı APK üretin:

```sh
flutter build appbundle --release --split-debug-info=build/symbols/android
flutter build apk --release --split-per-abi --split-debug-info=build/symbols/android
```

iOS yayın arşivini Flutter'ın release akışıyla hazırlayın. Mevcut uygulama
ortam ayarlarını (`--dart-define-from-file` veya `--dart-define`) de geçin.
Yayın için benzersiz build numarası ve o sürüme özel sembol dizini kullanın:

```sh
flutter build ipa --release --tree-shake-icons --build-name=1.0.0 --build-number=3 --split-debug-info=build/symbols/ios/1.0.0-3
```

Bu örnekteki `1.0.0+3` yerine yayımlanacak sürüm/build ve buna karşılık gelen
dizin kullanılmalıdır. Komut yerel arşiv/IPA üretir; App Store Connect'e
yüklemez. Sembolleri ayırmadan da release
derlenebilir; ayrılmış semboller kullanılıyorsa hata raporlarını çözümlemek
için ilgili sürümün dosyaları saklanmalıdır.

`ios/Flutter/Release.xcconfig`, Profile/Release için ikon küçültmeyi açık
tutar. Böylece son simülatör/debug çalıştırmasının `Generated.xcconfig`
içine bıraktığı `TREE_SHAKE_ICONS=false`, Xcode Archive'a taşınmaz. Bu ayar
`--no-tree-shake-icons` seçeneğini de ezer; dinamik `IconData` kullanımı
eklenirse küçültmeyi kapatmak yerine önce sabit ikonlara geçilmelidir.

Boyut analizi ayrı bir derlemedir. Flutter 3.41.6'da `--analyze-size` ile
`--split-debug-info` aynı komutta kullanılamaz:

```sh
flutter build apk --release --target-platform=android-arm64 --analyze-size
flutter build ios --release --no-codesign --analyze-size
```

Her sürümün `build/symbols/` çıktısını temizleme işleminden önce sürüm numarasıyla
arşivleyin; stack trace çözümlemesi için gerekli olabilir. Bu komutlar mağazaya
yükleme/yayımlama yapmaz. İmzasız iOS `.app` yalnız analiz içindir.

Debug/simülatör boyutu veya evrensel APK, son kullanıcının indirdiği boyut değildir.
Gerçek indirme boyutunu Play Console / App Store Connect veya iOS App Thinning
raporundan karşılaştırın. Kullanıcının belirttiği 107 MB, TestFlight/App Store
boyutudur. 23 Eylül tarihli yerel Xcode arşivinin `.app` içeriği ayrıca ölçüldü:
104.19 MB. Bu değer mağazanın indirme boyutuyla aynı ölçü değildir. Güncel
karşılaştırmalar [iOS boyut incelemesinde](../docs/mobile-size-audit-2026-09-25.md).
[Flutter boyut ölçümü](https://docs.flutter.dev/perf/app-size) ve
[Flutter görsel bellek kullanımı](https://api.flutter.dev/flutter/widgets/Image-class.html).

## Kontrol

```sh
flutter analyze
flutter test test/app_artwork_image_test.dart test/image_cdn_test.dart test/app_cached_image_test.dart test/category_tiles_test.dart test/mobile_performance_test.dart test/design_ui_test.dart
```
