# iOS uygulama boyutu incelemesi — 25 Eylül 2026

**Sonraki çalışma:** Kullanıcı büyük yerel görsellerin CDN'ye taşınmasını ve
küçük önizlemelerin pakette kalmasını seçti. Bu rapordaki 88.42 MB, o taşıma
öncesindeki ölçümdür. Güncel sonuçlar
[CDN artwork raporunda](cdn-app-artwork-2026-09-25.md).

Kullanıcının bildirdiği **107 MB**, TestFlight/App Store'da görülen boyuttur.
Bu incelemede son yerel yayın arşivi ve güncel kaynaklardan üretilen gerçek
**arm64 iOS release** çıktıları ölçüldü. MB = 1.000.000 bayt.

Son yerel, imzasız release `.app` **88.42 MB**. Bu bir App Store indirme
ölçümü değildir; yeni sürüm mağazaya yüklenmedi. Apple işleme, şifreleme ve
cihaz varyantlarına göre boyutu yeniden hesaplar. Kesin karşılaştırma yeni
build'in App Store Connect Download Size / Install Size raporuyla yapılmalı.
[Apple build bilgileri](https://developer.apple.com/help/app-store-connect/manage-builds/view-builds-and-metadata),
[Flutter boyut ölçümü](https://docs.flutter.dev/perf/app-size).

## Büyük kalemler

23 Eylül 02:44 Türkiye saati arşivi: `com.bitiryemek.bitirgitsin`, `1.0.0+2`.
Arşivdeki imzalı `.app` **104.19 MB**; kaynak kodu aynı tarihli olmadığı ve
güncel ölçüm imzasız olduğu için toplam farkın tamamı tek bir optimizasyona
atfedilemez. Aşağıdaki kalemler bu eski arşivin sıkıştırılmamış içeriğidir:

| Bileşen | MB | Değerlendirme |
| --- | ---: | --- |
| Flutter varlıkları: görseller, fontlar ve paket kaynakları | 36.86 | En güvenli küçültme alanı |
| Mapbox harita altyapısı ve Flutter bağlantısı | 36.30 | Harita özelliğinde aktif kullanılıyor |
| Derlenmiş Dart uygulama kodu | 10.13 | AOT release kodu |
| Flutter motoru | 9.99 | Uygulamanın çalışma altyapısı |
| Sentry, WebView, giriş SDK'ları ve diğer dosyalar | 10.91 | Büyük native bağımlılıklar aktif kullanılıyor |
| **Toplam** | **104.19** | **App Store indirme boyutu değildir** |

Bu bir debug veya birden fazla simulator mimarisi taşıma problemi değil:
önemli binary'ler tek `arm64`, Dart AOT kullanılıyor, `kernel_blob` yok.
Arşivdeki ayrıca **192.41 MB dSYM**, uygulama paketinin dışında; bunu silmek
kullanıcının indirmesini küçültmez.

## Yapılan ve ölçülen değişiklikler

1. Önceki CDN çalışmasındaki 15 büyük PNG → kayıpsız WebP dönüşümü korundu.
   Orijinal ve WebP görüntülerinin boyutları ve RGBA pikselleri **15/15 eşit**.
   Kaynak varlıklar toplamı **34.94 → 24.78 MB**; bu adımın dosya kazancı
   **10.16 MB**. Çözünürlük veya görüntü kalitesi azaltılmadı.
2. `pubspec.yaml` artık çalışma zamanında kullanılan **17 görseli** açıkça
   listeliyor. Kullanılmayan `surprise-package.webp` (**939.796 bayt**), eski
   `firin-pastane.png` (**116.534 bayt**) ve yalnız launcher üretiminde gereken
   `app_icon_foreground.png` (**13.513 bayt**) bundle dışına çıkarıldı. Dosyalar
   disk üzerinde korundu. Kullanılmayan `OnboardingAssets.closedBox` sabiti
   kaldırıldı. Yeni görsel eklenirken pubspec listesi de güncellenmeli.
3. Eski arşiv MaterialIcons fontunun tamamını (**1.645.184 bayt**) içeriyordu.
   Güncel release'de kullanılan ikonlar korunarak font **20.572 bayta** indi;
   fark **1.62 MB**. `ios/Flutter/Release.xcconfig` sonuna
   `TREE_SHAKE_ICONS = true` eklendi. Böylece debug çalıştırmasının ürettiği
   `Generated.xcconfig` içindeki `false`, Profile/Release arşivine taşınmıyor.
   Bu ayar CLI `--no-tree-shake-icons` seçeneğini de ezer. Mevcut uygulamada
   dinamik `IconData(...)` oluşturma bulunmadı; release build başarılı.
4. Ayrı bir release derlemesinde `--split-debug-info` denendi: **1.85 MB**
   ek kazanç doğrulandı. Dart binary **10.11 → 8.26 MB**. Semboller uygulama
   dışında tutulur; bu seçenekle yayımlanan her sürümün sembol dosyaları hata
   raporlarını çözümlemek için saklanmalı. Obfuscation açılmadı.

## Karşılaştırılabilir yerel derlemeler

Aşağıdaki üç derleme aynı bağımlılık kilit dosyaları, aynı Flutter **3.41.6** /
Dart **3.11.4**, aynı mevcut uygulama ortam tanımları ve aynı imzasız device
release yöntemiyle yapıldı. İlk satır önceki kayıpsız WebP değişikliklerini
zaten içerir. Ana çalışma alanını ve çalışan simulator derlemesini etkilememek
için geçici bir proje kopyası kullanıldı.

| Durum | `.app` MB | Kendi varlıklarımız MB | Flutter varlıkları toplam MB |
| --- | ---: | ---: | ---: |
| WebP mevcut; eski geniş asset listesi; ikon küçültme açık | 91.34 | 24.78 | 25.07 |
| Kullanılmayan üç varlık çıkarıldı | 90.27 | 23.71 | 24.00 |
| Ek olarak Dart sembolleri dışarı alındı | **88.42** | **23.71** | **24.00** |

Yalnız asset listesinin değiştirilmesi aynı derlemede **1.070.134 bayt**,
sembolleri ayırma **1.850.302 bayt** kazandırdı. İlk kazanç, dosyalarla birlikte
asset manifestinin de küçülmesini içerir. Xcode'daki ikon ayarı kalıcıdır;
sembolleri ayırma yayın komutunda ayrıca seçilir.

Son imzasız ölçüm çıktısı ve buna ait semboller, Git dışında kalan
`bitir_yemek_mobile/build/size-audit-2026-09-25/` içinde tutuldu.
Bu artifact mağazaya gönderilecek imzalı IPA değildir.
[Bayt düzeyinde ölçümler](mobile-size-audit-2026-09-25.json).

## Daha fazla küçültmek için güvenli sıra

- **Görsellerin çözünürlüğünü kullanımına göre azaltmak:** 15 kaynak WebP'nin
  tamamı hâlâ 1254×1254. Kategori kutuları 84 mantıksal piksel; mevcut decode
  sınırı 336 piksel. Bazı dekoratif onboarding görselleri 512 pikselde çözülüyor.
  Kategoriler için 512, daha büyük kahraman görselleri için 768 gibi değerler
  karşılaştırılabilir. Bu değişiklik piksel eşitliği sağlamaz; farklı ekran
  yoğunluklarında ve onboarding animasyonlarında görsel QA sonrası uygulanmalı.
  Bu turda uygulanmadı ve ölçülmemiş MB kazancı vaat edilmiyor.
- **Fotoğraf sıkıştırmasını görsel karşılaştırmayla değerlendirmek:** Kayıplı
  WebP daha küçük olabilir; şeffaflık, yazı ve dokular ayrı değerlendirilmeli.
  Yerel onboarding görselleri, giriş öncesi/çevrimdışı davranışı korumak için
  yalnız paket boyutu uğruna zorunlu ağ indirmesine çevrilmedi.
- **Native optimizasyonları ayrı denemek:** Podfile'daki bütün pod'lar için
  `BUILD_LIBRARY_FOR_DISTRIBUTION=YES` ve Swift `-Osize` seçenekleri ayrı native
  derleme/cihaz testleriyle ölçülebilir. Harita SDK'sını değiştirmek veya
  kaldırmak bu güvenli asset temizliğinden çok daha geniş bir iş olur.

Mapbox, WebView ve giriş SDK'ları kullanılıyor. `logger` doğrudan kullanılmıyor
ancak Dart-only; kaldırılması büyük bir kazanç sağlamaz. `stream_transform`
doğrudan import edilmese de `bloc_concurrency` üzerinden gerekli. `sqflite`
görsel disk önbelleği, `package_info_plus` Sentry üzerinden geliyor. Korolev
fontlarının toplamı yalnız **137 KB**; font ağırlıkları korunuyor.

Xcode effective Release ayarlarında `DEAD_CODE_STRIPPING=YES`,
`STRIP_INSTALLED_PRODUCT=YES`, Swift `-O` ve dSYM üretimi doğrulandı. Bazı
archive framework'lerinde yerel semboller bulunması tek başına mağaza
paketinin gereksiz büyük olduğunu kanıtlamaz; standart export zaten Swift
sembollerini strip eder. İmzalı binary'ler elle değiştirilmedi.
[Apple build ayarları](https://developer.apple.com/documentation/xcode/build-settings-reference),
[Swift library evolution](https://www.swift.org/blog/library-evolution/).

Cloudflare CDN, sunucudan gelen görsellerin transferini azaltır. Uygulamanın
içine paketlenen görsellerin baytlarını veya native SDK'ları kaldırmaz.
Android release'te R8 ve resource shrinking zaten açık; kaynak görsel
temizliği Android'e de uygulanır, ancak bu turda Android paketi ölçülmedi.

## Doğrulama ve yayın adımı

- `flutter analyze`: sorun yok.
- Kategori ve tasarım UI testleri: **14/14 başarılı**.
- Gerçek iOS arm64 release derlemeleri başarılı.
- Son bundle'daki **17/17** kullanılan görselin SHA-256 değeri kaynakla aynı;
  dışlanan üç dosya bundle'da yok.
- `pubspec.lock`, `Podfile.lock` ve native uygulama kaynak/proje dosyaları
  değişmedi. Tek native build yapılandırma değişikliği `Release.xcconfig`.
- Root projede `Generated.xcconfig` debug'dan kalan `false` içerirken bile
  Xcode effective Release `TREE_SHAKE_ICONS=true` olarak doğrulandı.
- `git diff --check` başarılı. Canlı backend veya mağaza sürümü değiştirilmedi.

Yayın komutları [mobil README](../bitir_yemek_mobile/README.md) içinde.
`--analyze-size` ile `--split-debug-info` yerel Flutter sürümünde birlikte
kullanılamadığından önceki örnek komutlar düzeltildi. Yeni build yayımlanınca
aynı cihaz varyantının mağaza raporu üzerinden 107 MB ile karşılaştırılmalı.
