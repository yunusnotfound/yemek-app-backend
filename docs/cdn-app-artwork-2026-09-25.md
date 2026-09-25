# Uygulama görsellerinin CDN'ye taşınması — 25 Eylül 2026

Kullanıcı büyük görsellerin CDN'den gelmesini, uygulamada küçük yerel
önizlemelerinin kalmasını seçti. Sekiz kategori ve altı tanıtım/dekor görseli
bu modele geçirildi. Logo, Google işareti, küçük yemek kutusu ve fontlar
yerelde kaldı. Ücretli Cloudflare ürünü veya yeni servis açılmadı.

**Ölçülen sonuç:** Aynı yöntemle üretilen yerel iOS release `.app`
**88.42 MB → 65.01 MB** oldu: **23.41 MB / %26,48** küçülme.
Bu değer App Store/TestFlight indirme boyutu değildir.

## Paket boyutu ve görünüm

| İçerik | Önce | Sonra |
| --- | ---: | ---: |
| 14 büyük görselin uygulama içindeki payı | 23.462.414 bayt | 49.092 bayt |
| Kendi paketlenen varlıklarımızın toplamı | 23.707.673 bayt | 294.351 bayt |
| Varlık kazancı | | **23.413.322 bayt / 23,41 MB** |

Yerel önizlemeler 128×128, WebP quality 70, alpha quality 100 olarak
üretildi. Bunlar düşük çözünürlüklüdür; ağ yokken aynı kompozisyon daha az
ayrıntıyla görünür. Orijinal 1254×1254 WebP dosyalarının hiçbir baytı
değiştirilmedi. Beş şeffaf görselin önizleme alpha kanalı, yeniden
boyutlandırılmış kaynakla tam eşleşiyor. Yan yana görsel kontrol yapıldı.

Üretim aracı:
`bitir_yemek_mobile/tool/generate_artwork_previews.py`.
Pillow 12.2.0 / libwebp 1.6.0 ile tekrar çalıştırıldığında önizlemeler ve
manifest bayt düzeyinde aynı üretildi. Büyük kaynaklar diskte korunuyor,
ancak pubspec runtime asset listesinde bulunmuyor.
[Dosya, ölçü ve hash manifesti](app-artwork-cdn-2026-09-25-assets.json).

## Canlı CDN yayını

Kaynak adresi:

```text
https://api.bitirgitsin.com/uploads/app-artwork-v1/
```

Sekiz dosya `categories/`, altı dosya `onboarding/` altında. Yayın
15:12:03 UTC'de mevcut Docker uploads volume'u içinde staging dizininden
atomik yeniden adlandırma ile tamamlandı. 14/14 kaynak dosyanın yerel ve
sunucu SHA-256 değerleri, boyutları, sahipliği ve izinleri doğrulandı.
Dosyalar 644, dizinler 755, sahiplik 1001:1001. Container restart veya
backend yapılandırma değişikliği yapılmadı.
[Yayın kanıtı](cdn-app-artwork-2026-09-25-deployment.json).

Mevcut Cloudflare `/uploads/` cache kuralı ve Images kaynak izni bu yolu
kapsıyor. Kaynak yanıtları `public, max-age=86400`. V1 dizini sürüm
sözleşmesiyle sabit tutulacak: yayımlanan dosyalar üzerine yazılmayacak;
değişiklik için v2 gibi yeni dizin ve yeni uygulama URL'leri kullanılacak.

Mobil uygulama 320/640/960/1280 genişliklerinden ekran ihtiyacına uygun olanı
ister. Artwork dönüşümlerine `background=transparent` açıkça eklendi;
`format=webp`, kalite 85 ve `Accept: image/webp,...` kullanılır. Diğer
işletme görsellerinin URL davranışı korunur. Mevcut `onerror=redirect`,
dönüşümün desteklenen hata durumlarında orijinale dönmesine izin verir.
[Cloudflare dönüşüm seçenekleri](https://developers.cloudflare.com/images/optimization/features/).

15:13:25 UTC edge doğrulaması:

- Kaynak **14/14 HTTP 200**; Content-Length, orijinal dosya boyutuyla eşit.
- 640 piksel varyantların **14/14'ü image/webp, 640×640**.
- Tekrar isteklerin **14/14'ü HIT**; ilk/ikinci yanıtların SHA-256'sı aynı.
- Beş şeffaf kesit görselinde alpha aralığı **0–255** korunuyor.
- 14 adet 640 piksel varyantın toplamı **1.265.650 bayt**. Bunlar gerektiği
  zaman istenir; uygulama açılışında topluca indirme yapılmaz.

[HTTP/cache/alpha kanıtı](cdn-app-artwork-2026-09-25-edge.json).

## Uygulama davranışı

`resolveAppArtwork` yalnız bilinen 14 canonical asset yolunu CDN ve yerel
önizleme çiftine çevirir. Diğer küçük yerel asset'ler normal yüklenir.
`AppArtworkImage`, yerel önizlemeyi hem yükleme hem hata/timeout görünümü
olarak kullanır. CDN görseli hazır olduğunda yerini alır; ağ yanıtı
gelmeden de ekran ve düğmeler kullanılabilir.

Kategori kutuları, tanıtım fotoğrafları/oyunu, giriş görseli, konum sahnesi
ve boş liste çantası aynı çözümü kullanır. Ortak `cachedImageProvider`
üzerinden sıkıştırılmış yanıt cihaz disk önbelleğine kaydedilir; widget ve
canvas çizimleri aynı önbelleği kullanır.

Sürpriz kutunun canvas çiziminde önce küçük karton/yemek görseli yüklenir,
sonra kaliteli sürümü gelir. Resim handle'ları klonlanıp sahipliklerine göre
dispose edilir. Eski yemek seçiminin geç gelen yanıtı yeni seçimi değiştiremez;
geç önizleme de kaliteli resmi geri düşüremez. Ağ hatası önizlemeyi korur.
Animasyon ve çizim geometrisi değiştirilmedi.

Bu mobil değişikliklerin kullanıcılara ulaşması için yeni uygulama sürümü
derlenip dağıtılmalı. CDN dosyaları canlıdır; App Store/TestFlight'a yeni
sürüm yüklenmedi. Mağaza indirme boyutu yerel `.app` ölçümünden farklıdır.

## Mobil doğrulamalar

- `flutter analyze`: sorun yok.
- Artwork, CDN URL, mevcut cache widget'ı ve kategori testleri: **19/19**.
  Bu kapsam, bundle'da 14 büyük dosyanın bulunmadığını ve 14 yerel önizlemenin
  bulunduğunu; offline, timeout sonrası yükselme, geç eski yanıt, geç
  önizleme, dispose ve sıcak cache'den yeniden açılma davranışlarını sınar.
- Mevcut tasarım ve performans testleri: **23/23**.
- Gerçek önizleme dosyalarıyla kategori ekran görüntüsü kontrolü: **4/4**;
  normal ve 2,4 kat yazı ölçeğinde fotoğraflar ve seçilebilir kategoriler
  görünür. Bu dört kategori testi ilk gruptakilerin görüntü üretimli tekrarıdır.
- Bağımsız kod incelemesinde bloklayıcı bulgu yok; `ui.Image` sahipliği,
  abonelik temizliği, küçük yerel PNG davranışı ve asset eşleşmeleri incelendi.
- `git diff --check` temiz; bağımlılık kilit dosyaları değişmedi.

## Son iOS release ölçümü

Flutter 3.41.6 / Dart 3.11.4 ile, mevcut uygulama ortam tanımları korunarak
izole kopyada `--release --no-codesign --split-debug-info` derlendi.
`com.bitiryemek.bitirgitsin`, sürüm `1.0.0+2`; bu build yalnız yerel
doğrulamadır ve mağazaya gönderilmedi.

| Ölçü | Bayt |
| --- | ---: |
| Önceki aynı yöntemle ölçülen `.app` | 88.421.159 |
| CDN + yerel önizlemeli `.app` | **65.010.649** |
| Toplam paket farkı | **23.410.510** |
| Kendi asset dosyalarımız | 294.351 |
| Bütün Flutter asset'leri, paket kaynakları dahil | 589.786 |
| Dart AOT binary | 8.259.600 |

Gerçek son bundle'da **14/14** büyük kaynak görselin bulunmadığı ve **14/14**
önizlemenin manifestteki SHA-256 ile eşleştiği doğrulandı. Diskteki büyük
kaynakların hashleri değişmedi. Küçük PNG'ler ve fontlar da kaynaklarıyla
birebir eşleşiyor. Binary tek arm64 mimarisi; debug kernel bulunmuyor.

İmzasız `.app`, ona ait semboller, build logu ve görsel QA çıktıları
`bitir_yemek_mobile/build/artwork-cdn-2026-09-25/` içinde saklandı.
Geçici derleme kopyası temizlendi. Her yeni yayın için yeni build numarası,
imzalı IPA ve o build'in sembol arşivi kullanılmalı.
[Release ölçüm kanıtı](cdn-app-artwork-2026-09-25-release.json).
