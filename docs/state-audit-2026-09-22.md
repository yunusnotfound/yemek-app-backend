# Mobil state denetimi — 22 Eylül 2026

## Bulunan ve düzeltilen sorunlar

- **Sekmeler arası durum kaybı:** Ara sekmesi bütün `IndexedStack` ağacını kaldırıyordu. Ana ekranda Kafe seçip haritaya gidip dönünce kategori Hepsi görünürken paketler Kafe olarak kalıyordu. Sekmeler ilk ziyarette oluşturulup korunuyor; görünmeyen sekmelerin Flutter animasyonları durduruluyor ve geçişte klavye odağı bırakılıyor. Düzeltme simülatörde tekrar doğrulandı.
- **Favori ve kayıtlı kart yarışları:** Birbirini geçen okuma/yazmalar son kullanıcı işlemini geri alabiliyordu. Her bloc içinde ilgili olaylar ortak sırada işleniyor. Geciken favoriye ekleme ardından kaldırma ve başarısız kart silme ardından başka kartı silme senaryoları test edildi.
- **Paket yenileme ve sayfalama:** Başarısız yenileme mevcut listeyi kaybettirebiliyor, sayfalama hatası yeniden denemeyi engelliyordu. Veri ve sayfa bilgisi korunuyor; kullanıcıya hata bildiriliyor. Yenileme göstergesi isteğin bitmesini bekliyor. Kategoriye ait hata ekranının tekrar denemesi aynı kategoriyi kullanıyor.
- **İşletme ekranlarında eski yanıtlar:** Önceki işletmenin veya sipariş filtresinin geciken yanıtı güncel seçimi değiştirebiliyordu. Dashboard, siparişler ve paketlerde eski sonuçlar eleniyor.
- **Kupon ve rezervasyon:** Kaldırılan kuponun geciken doğrulaması artık uygulanmıyor. Devam eden rezervasyon sırasında tekrar gönderim ve durumu sıfırlayarak ikinci istek başlatılması engelleniyor.
- **Ödeme ekranının kapanması:** Bloc kapandıktan sonra yeni ödeme durumu sorgusu başlatılmıyor; geciken yanıtlar uygulanmıyor.
- **Profil ve çıkış:** Çıkıştan önce başlayan profil isteğinin sonradan dönerek oturum ekranını geri getirmesi engelleniyor.
- **Bildirimler:** Okundu yanıtı eski liste indeksine değil bildirim kimliğine uygulanıyor. Silme geri alınırken aynı bildirim ikinci kez eklenmiyor.
- **Dar ekranda fiyat taşması:** Liste kartının fiyatları gerektiğinde alt satıra geçiyor. Sorun 390 piksel genişlikte sayfalama widget testiyle yakalandı.

## Simülatörde kontrol edilen kapsam

iPhone 17 Pro / iOS 26.5 üzerinde açık müşteri oturumuyla:

- Ana ekran, kategori seçimi, haritaya gidip dönüş ve kategori/veri tutarlılığı.
- Harita, işletme araması, sekme değişiminde aramanın korunması.
- Paket ve işletme detayları, rezervasyon formu, miktar değişimi ve kupon seçicisinden geri dönüş.
- Favoriye ekleme, Favoriler sekmesinde görünmesi ve kaldırma. Testte eklenen favori temizlendi.
- Siparişlerin aktif/tamamlanan/iptal filtreleri ve boş durumları.
- Profil, düzenleme formunun açılıp kapatılması, bildirimler, kayıtlı kartlar ve kart ekleme formu.
- Tüm paketler sayfasının açılması. UI otomasyonundaki kaydırma hareketi güvenilir sonuç vermedi; ikinci sayfaya kaydırma ve 14. pakete ulaşma widget testiyle doğrulandı.

Gerçek sipariş, tahsilat, kart kaydı veya hesap silme yapılmadı. İşletme hesabıyla manuel tur yapılmadı; işletme state yarışları sahte repository yanıtlarıyla otomatik test edildi. Giriş/onboarding/konum akışları bu turda mevcut test paketiyle doğrulandı; açık oturumdan çıkılmadı. Dolu sipariş ve bildirim listelerinin bütün işlemleri canlı hesapta denenmiş sayılmamalıdır.

## Tekrarlanabilir kontroller

`bitir_yemek_mobile` dizininde:

```sh
flutter analyze --no-pub
flutter test --no-pub --concurrency=1 --reporter expanded
```

`test/state_consistency_test.dart` içinde dokuz regresyon testi eklendi. İlk paralel tam test turunda eşzamanlı 401 yenileme testi üç saniyelik zaman aşımına takıldı; aynı güvenlik testleri seri hedefli çalıştırmada ve son tam koşuda geçti.

- Statik analiz: hata veya uyarı yok.
- Son seri tam test koşusu: **98/98 geçti** (2 dakika 12 saniye).
- `git diff --check`: temiz.
