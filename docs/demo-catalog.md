# Test kataloğu

`scripts/demo-catalog.js`, İstanbul / Bayrampaşa çevresinde 5 kategoride 7 kurgusal işletme ve 14 paket oluşturur. Tüm isimler `TEST ·` ile başlar; açıklamalar gerçek satış ve teslimat yapılmadığını belirtir. Gerçek işletme, iletişim bilgisi, ödeme hesabı veya müşteri değerlendirmesi kullanılmaz.

## Çalıştırma

API ile aynı veritabanı ve Redis ortam değişkenleriyle:

```sh
# Önizleme: veritabanına yazmaz.
node scripts/demo-catalog.js

# Geliştirme ortamına ekle.
node scripts/demo-catalog.js --apply

# Canlı ortam: yalnızca test kayıtlarının yayımlanması açıkça istendiğinde.
node scripts/demo-catalog.js --apply --allow-production

# Yalnızca bu kataloğun işletme ve paketlerini pasifleştir; kayıtları silmez.
node scripts/demo-catalog.js --archive --apply --allow-production
```

İşletmelerin kimlikleri sabittir; paket kimlikleri işletme, varyant ve teslim tarihinden üretilir. Aynı gün tekrar çalıştırmak mevcut stokları/fiyatları değiştirmez veya kayıtları çoğaltmaz. Tarihler İstanbul saatine göre bugün ve yarındır; 22.00 sonrasında yarın ve ertesi gün kullanılır. Paketler otomatik tekrar etmez. Daha sonraki günlerde yeniden çalıştırmak yeni tarihli örnekler oluşturur. Arşivlenmiş işletmeler kendiliğinden yeniden etkinleştirilmez. Aktif sipariş varsa arşivleme işlemi durur.

## Görseller ve Docker

Görseller uygulamadaki mevcut varlıklardan hazırlanır. Mobil kaynaklar 25 Eylül 2026'da kayıpsız WebP'ye taşındı. `scripts/demo-catalog.js` görsel dosyalarını okumaz veya kopyalamaz; `image` alanları API'nin kalıcı `uploads/demo-catalog-v1/` dizinindeki mevcut **PNG dosya adlarıdır**. Mevcut URL'ler için eşleme:

| `bitir_yemek_mobile/assets/images/` altındaki yerel kaynak | API dosya adı |
| --- | --- |
| `categories/firin-pastane.png` | `firin-pastane.png` |
| `categories/kafe.webp` | `kafe.png` |
| `categories/restoran.webp` | `restoran.png` |
| `categories/manav.webp` | `manav.png` |
| `categories/market.webp` | `market.png` |
| `categories/pastane.webp` | `pastane.png` |
| `onboarding/foodbox-meal.webp` | `foodbox-meal.png` |

Yeni bir ortam hazırlanacaksa repo kökünde Python 3 ve Pillow ile aynı pikselleri içeren PNG'leri ayrı bir geçici dizine çıkarabilirsiniz. Aşağıdaki komut veritabanına veya `uploads/` dizinine yazmaz; hedef dizin zaten varsa durur. WebP dosyasını yalnız `.png` diye yeniden adlandırmayın.

```sh
python3 - <<'PY'
from pathlib import Path
from PIL import Image
import shutil

source = Path('bitir_yemek_mobile/assets/images')
destination = Path('/tmp/bitirgitsin-demo-catalog-images')
destination.mkdir(exist_ok=False)
shutil.copy2(source / 'categories/firin-pastane.png', destination)
files = [f'categories/{name}.webp' for name in ['kafe', 'restoran', 'manav', 'market', 'pastane']]
files.append('onboarding/foodbox-meal.webp')
for name in files:
    with Image.open(source / name) as image:
        image.save(destination / Path(name).with_suffix('.png').name, format='PNG')
print(destination)
PY
```

Canlı ortamda zaten bulunan PNG'ler bu kaynak biçimi değişikliğinden etkilenmez. Geçici çıktıların sunucuya aktarılması ayrı bir işlemdir.

URL tabanı: `https://api.bitirgitsin.com/uploads/demo-catalog-v1`.

Bu yönetim betiği normal Docker imajına veya otomatik migration/seed akışına dahil değildir. Gerektiğinde `scripts/demo-catalog.js` dosyasını çalışan konteynerde `/app/scripts/demo-catalog.js` konumuna kopyalayıp yukarıdaki komutları `docker exec` ile çalıştırın. API kodunun yeniden dağıtılması veya yeniden başlatılması gerekmez. Veritabanı işlemleri tek transaction içinde uygulanır, ardından yalnızca işletme/paket liste önbelleklerinin sürümü artırılır.

## 22 Eylül 2026 uygulaması

Kullanıcının açık isteğiyle canlı ortama 7 işletme / 14 paket eklendi. Önceden bulunan 2 işletme ve 3 paket korunur. Test paketlerinde 60–210 TL fiyat, 1–12 adet stok ve farklı teslim aralıkları kullanılır. Ödeme ayarları değiştirilmez, alt üye işyeri oluşturulmaz.

## 25 Eylül 2026 yenilemesi

Kullanıcının yalnızca test verisi ekleme isteğiyle mevcut 7 aktif/onaylı test işletmesine 14 yeni paket eklendi: 7 paket 25 Eylül, 7 paket 26 Eylül teslim tarihli. Önceki 22–23 Eylül paketlerinin süresi dolmuştu. İşletmeler çoğaltılmadı; mevcut paketlerin stok ve fiyatları sıfırlanmadı.

Canlı API'nin `lat=41.046&lng=28.912&radius=3&limit=100` sorgusunda 14 yeni `TEST ·` paketinin göründüğü doğrulandı. Yedi farklı paket/işletme görselinin tümü CDN üzerinden HTTP 200 ve `image/png` yanıtı verdi. Uygulamada test için İstanbul / Bayrampaşa / Numunebağ çevresi seçilebilir. Paketler tarihli olduğundan ilerleyen günlerde yeniden oluşturulmaları gerekir. Bu işlem kapsamında build veya TestFlight işlemi yapılmadı.
