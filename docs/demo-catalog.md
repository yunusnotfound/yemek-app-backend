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

Görseller uygulamadaki mevcut varlıklardır. Aşağıdaki dosyalar API'nin kalıcı `uploads/demo-catalog-v1/` dizininde bulunmalıdır:

- `bitir_yemek_mobile/assets/images/categories/`: `firin-pastane.png`, `kafe.png`, `restoran.png`, `manav.png`, `market.png`, `pastane.png`
- `bitir_yemek_mobile/assets/images/onboarding/`: `foodbox-meal.png`

URL tabanı: `https://api.bitirgitsin.com/uploads/demo-catalog-v1`.

Bu yönetim betiği normal Docker imajına veya otomatik migration/seed akışına dahil değildir. Gerektiğinde `scripts/demo-catalog.js` dosyasını çalışan konteynerde `/app/scripts/demo-catalog.js` konumuna kopyalayıp yukarıdaki komutları `docker exec` ile çalıştırın. API kodunun yeniden dağıtılması veya yeniden başlatılması gerekmez. Veritabanı işlemleri tek transaction içinde uygulanır, ardından yalnızca işletme/paket liste önbelleklerinin sürümü artırılır.

## 22 Eylül 2026 uygulaması

Kullanıcının açık isteğiyle canlı ortama 7 işletme / 14 paket eklendi. Önceden bulunan 2 işletme ve 3 paket korunur. Test paketlerinde 60–210 TL fiyat, 1–12 adet stok ve farklı teslim aralıkları kullanılır. Ödeme ayarları değiştirilmez, alt üye işyeri oluşturulmaz.
