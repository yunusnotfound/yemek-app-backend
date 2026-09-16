# Gerçek işletme kataloğu

Müşteri uygulamasındaki işletmeler ve paketler API veritabanından gelir.
Boş veritabanı için örnek restoran veya paket üreten bir geri dönüş yoktur.
`npm run db:seed` yalnız kategori tanımlarını ekler; demo kullanıcı, işletme,
paket ve kupon ekleyen eski seed dosyaları kaldırılmıştır.

## Panel ve uygulamanın aynı veriyi kullanması

- Web panelinde sunucu ayarı: `BACKEND_API_URL`.
- Flutter derlemesinde ayar: `--dart-define=API_BASE_URL=...` veya mevcut
  `--dart-define-from-file=...` dosyasındaki `API_BASE_URL`.
- İki adres aynı backend/veritabanına ulaşmalıdır. Mobil debug/release varsayılanı
  `https://api.bitirgitsin.com/api` adresidir. Güncel simülatör profili
  `.vscode/mobile.live.json` da bu adresi kullanır ve yerel API başlatmaz.
- Yayındaki web paneli Docker ağında aynı API'ye
  `http://bitir-yemek-app:3000/api` üzerinden ulaşır. Web panelini bu bilgisayarda
  çalıştırırken aynı veri için `BACKEND_API_URL=https://api.bitirgitsin.com/api`
  açıkça ayarlanmalıdır; web geliştirme varsayılanı localhost'tur.
- Yayındaki panelin verileri yerel simülasyon veritabanına otomatik kopyalanmaz.
  Yayın ortamında her iki istemci aynı yayın API'sine yönlendirilmelidir.

İşletme panelinden eklenen kayıt yönetici onayından sonra görünür. Liste ve
harita yalnız silinmemiş, aktif, onaylı ve askıya alınmamış işletmeleri döndürür.
Konum ve yarıçap filtreleri geçerlidir. Paket listeleri ve harita paket sayıları
ayrıca aktiflik, askıya alınma, kalan stok ve teslim tarihi koşullarını uygular.
Onaylı bir işletmenin henüz paketi olmayabilir; bu işletme haritada sıfır paketle
görünebilir.

## Güncellemeler

Paneldeki işletme/paket değişiklikleri backend liste ve harita önbelleklerini
geçersiz kılar. Müşteri uygulaması Keşfet/Ara sekmesine dönüşte ve uygulama yeniden
ön plana geldiğinde verileri yeniler. Açık katalog sekmesi 15 saniyelik aralıklarla
yenilenir; uygulama arka plandayken bu yenileme durur. Uygulamanın ve güncel
simülatör profilinin varsayılan aralığı 15 saniyedir. `CATALOG_REFRESH_SECONDS`
ile artırılabilir; minimum süre 15 saniyedir. Canlı sunucuda son kontrolde bulunan
100 istek/15 dakika sınırı uzun süreli harita kullanımını kısıtlayabilir; bu sıklığı
desteklemek için hazırlanan yeni backend katalog sınırının yayımlanması gerekir.
Bu periyodik API yenilemesidir,
sunucudan anlık bildirim gönderimi değildir. Ağ isteği süresi ek gecikme oluşturabilir.

## 16 Eylül 2026 yerel veri temizliği

Yalnız `127.0.0.1:5432/bitir_gitsin_simulator` veritabanında eski seed tanımlarıyla
işletme adı, sahip hesabı, adres, telefon ve koordinatlar karşılaştırıldı.
İlgili işletmelere ait sipariş, değerlendirme veya ödeme hesabı bilgisi olmadığı
doğrulandıktan sonra tek işlemde şu kayıtlar kaldırıldı:

- 4 demo işletme ve 6 demo paket;
- bu işletmelere ait 2 favori ilişkisi;
- eski seed dosyasındaki 4 örnek kupon.

Kullanıcı hesapları korunmuştur. `ILK100` kampanyasının 500 TL alt limiti ve 100 TL
indirimi korunmuş, yalnız demo işletmeleri kapsadığı için kampanya pasife alınmıştır.
Yeniden etkinleştirmeden önce katılan gerçek işletmeler seçilmeli ve işletme onayı
doğrulanmalıdır. Genel katılıma otomatik açılmamıştır.

Temizlik öncesi kayıtların yerel, git dışındaki yedeği
`.vscode/demo-catalog-backup-2026-09-16.json` dosyasındadır. Yayın veritabanında
temizlik veya dağıtım yapılmamıştır.

Ana `.env` dosyasındaki alternatif yerel bağlantı (`localhost:5001/bitir_yemek`)
kontrol sırasında kapalıydı; Docker servisi de çalışmıyordu. Bu erişilemeyen
veritabanının içeriği doğrulanmamış ve değiştirilmemiştir. Çalışan simülatör bu
bağlantıyı kullanmaz.

## Doğrulama

- Backend: 17 test dosyasında 161 test başarılı. Panelden oluşturma/onaylama,
  dolu önbellekten sonra güncelleme, pasifleştirme, askıya alma, geçmiş teslim
  tarihi ve katalog okuma sınırları dahil. Test verileri ayrı geçici veritabanı
  ve Redis'te oluşturulup bu ortamlar test sonunda kaldırıldı.
- Flutter: 86 test başarılı; statik analiz temiz. Görünür ekran/lifecycle,
  15 saniyelik yenileme, isteklerin çakışmaması ve silinen kayıtların kalkması
  doğrulandı.
- Çalışan yerel API: işletme/paket listeleri 200 ve sıfır kayıt; silinen demo
  işletmenin detay bağlantısı 404. Veritabanı ve Redis sağlık kontrolü başarılı.
- Güncel uygulama simülatöre yüklendi; haritada demo işaretçileri yok ve paket
  sayısı sıfır. Yeni işletmeler eklenene kadar boş katalog beklenen sonuçtur.

## Canlı API'ye geçiş

Sonraki kullanıcı açıklamasıyla simülatör canlı API'ye geçirildi. Önceki yerel test
oturumu normal çıkış akışıyla kapatıldı; kullanıcı canlı ortamda yeniden giriş yapar.
Yerel API süreci durduruldu. Canlı sağlık kontrolü PostgreSQL ve Redis için
`connected` döndürüyor. Public API kontrolünde 1 işletme ve 0 aktif paket vardı;
yerel demo işletme adları canlı listede bulunmadı. Canlı kayıtlar silinmedi veya
değiştirilmedi; bu işlem backend dağıtımı değildir.

Yeni bağlantı/yenileme ayarlarıyla 89 Flutter testi ve statik analiz başarılı.
