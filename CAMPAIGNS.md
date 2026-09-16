# İlk sipariş kampanyası ve arayüz güncellemesi

Mevcut Express/Sequelize, Next.js ve Flutter/BLoC yapıları korunur. İndirim maliyeti, kullanıcının seçimiyle katılan işletmeler ve platform arasında mevcut ödeme oranlarıyla paylaşılır. İndirim sonrası toplam, mevcut iyzico ödeme eşleştirme ve iade kontrollerinden geçer.

## Hazır ilk sipariş şablonu

Yönetim paneli → Kuponlar → İlk sipariş taslağı:

- Kod: `ILK100`; başlık: İlk paketine özel.
- **Uygulamadaki indirimli paket fiyatları toplamı 500 TL ve üzerindeyse 100 TL indirim.** Normal/liste fiyatı eşik hesabına katılmaz.
- İlk sipariş, hesap başına bir kullanım, 100 toplam kullanım ve 10.000 TL nominal indirim bütçesi.
- Önerilen bitiş: taslağın açıldığı tarihten 14 gün sonra; panelden değiştirilebilir.
- Şablon **pasif** hazırlanır. Katılan işletmeler seçilir, indirim paylaşımı teyit edilir, sonra aktif yapılır. Bu çalışma canlı kampanya veya işletme katılımı oluşturmaz.

Örnek: satış fiyatı 250 TL olan paketten iki adet → 500 TL ara toplam → 100 TL kupon → 400 TL ödeme. Tek sipariş aynı paket türünden bir veya daha fazla adet içerir; çoklu işletme sepeti eklenmemiştir. Mobil adet seçimi stokla ve 100 adet üst sınırıyla sınırlıdır.

## Kullanım ve bütçe kuralları

Sipariş oluşturulurken kullanıcı ve kupon kayıtları kilitlenir. Bekleyen ödeme hem kişisel kullanım hakkını hem nominal indirim bütçesini ayırır. Başarısız ödeme/ödeme öncesi iptal hakkı bir kez geri verir. Başarılı ödeme sonrası iptal veya iade, kupon hakkını yeniden açmaz. İlk sipariş uygunluğu kontrolünde silinmiş sipariş kayıtları ve ödeme geçmişi de dikkate alınır.

Yalnız bir kupon uygulanır. Sabit ve yüzdesel indirimler gerçek toplamı aşamaz; yüzde indirimi için ayrıca tutar üst sınırı tanımlanabilir. Ödeme öncesi paket fiyatı veya kupon tutarı değişirse mobilin onayladığı toplamla karşılaştırılır ve farklı tutarda ödeme başlatılmaz.

Eski kuponlar otomatik yayımlanmaz ve mevcut kapsamları korunur. Yeni keşfedilebilir kampanyalar katılımcı işletme seçimi ve paylaşım teyidi gerektirir. Kullanılmış kuponların fiyat/katılım koşulları değiştirilemez; ihtiyaç varsa yeni kampanya açılır. Kupon arşivleme, sipariş ilişkisini silmeden kullanımı durdurur.

Paneldeki ayrılan bütçe, ödeme bekleyen ve kullanılmış kuponların nominal toplamıdır; banka masrafı veya yalnız platformun maliyeti değildir. Tamamlanan sipariş sayısı ayrıca gösterilir. Hesap başına sınır, bir kişinin farklı hesaplarla kayıt olmasını mutlak olarak engelleyen bir kimlik doğrulama sistemi değildir.

## Mobil görünüm

- Krem–turuncu renkler, Korolev yazı tipi ve alt menü korunur.
- Sıcak, iki katmanlı gölgeler, ince yüzey kenarları ve tutarlı kart derinliği uygulanır.
- Keşfet'te yalnız uygun aktif kampanyalar görünür; boş kampanya mesajı ana kataloğu engellemez.
- Kuponlarım, koşulları ve uygun olmama nedenini gösterir. Seçili işletmelerin yeterli stoktaki paketleri kampanya sayfasında listelenir.
- Paket detayında gereken adet ve kupon sonrası tutar sunucudan doğrulanarak sunulur.
- Sipariş onayında stokla sınırlı adet seçimi, tek dokunuşla kupon seçme ve kuruş hassasiyetinde toplam gösterilir.
- Profilde kurtarılan paket ve kayıtlı tasarruf toplamı görünür. Yalnız teslim edilmiş, iade edilmemiş siparişler sayılır. Eski siparişlerde tarihsel liste fiyatı bulunmadığından bugünkü fiyatla geçmiş tasarruf uydurulmaz; kayıtlı kupon indirimi kullanılır.
- Parasal değerler, marka yazı tipinde tüm cihazlarda okunabilmesi için `TL` ile gösterilir.

## Dağıtım ve doğrulama

`20240101000029-coupon-campaigns.js` önce veritabanına uygulanmalı, ardından backend ve yeni istemciler dağıtılmalıdır. Geçiş yalnız ek alanlar ve bir indeks oluşturur; canlı veritabanına burada uygulanmadı. Yeni kampanyaları, mobil güncellemenin yaygınlaşmasından sonra etkinleştirin: eski istemciler işletme kapsamı/adetli kupon teklifini desteklemeyebilir.

Yeni geçiş ayrı test veritabanında tüm migration zinciriyle uygulandı, geri alınıp tekrar uygulandı. Backend testleri banka/e-posta çağrılarını taklit eder; gerçek banka işlemi yapılmaz. Flutter testleri kupon seçimini, sunucu teklifini, adet/stok sınırını, negatif tutar korumasını ve 1×/2× yazı boyutunda Keşfet/kupon ekranlarını doğrular. Görsel önizlemeler test verileriyle gerçek Flutter bileşenlerinden üretilir.

Kampanya geliştirme aşamasındaki doğrulama: 98 backend + 15 Flutter + 7 web testi başarılı (toplam 120). Flutter analizi temiz, web üretim derlemesi başarılı. O aşamadaki web lint: 0 hata, önceki koddan gelen 6 uyarı.

Performans düzeltmeleri sonrasında 138 backend + 41 Flutter + 7 web testi (toplam 186), gerçek iPhone 16 Pro profil testi ve iOS release derlemesi başarılı. Cihaz kapsamı ve ölçümler [8 Eylül 2026 performans raporunda](docs/performance-fixes-2026-09-08/REPORT.md).
