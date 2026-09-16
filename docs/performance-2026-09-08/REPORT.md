# Bitir Gitsin performans incelemesi — 8 Eylül 2026

Bu belge düzeltmelerden önceki tarihsel ölçümdür. [Güncel düzeltme ve telefon sonuçları](../performance-fixes-2026-09-08/REPORT.md) ayrı rapordadır.

Normal listeleme hızlı; ancak yoğun sipariş trafiğinde kritik bir bağlantı havuzu tıkanması var. Mevcut haliyle uygulamaya “yük altında sorunsuz ve verimli” demek mümkün değil. Öncelik sipariş oluşturma, kupon sorguları ve Redis kesintisindeki bekleme davranışı olmalı.

**Test ortamı ve kapsam**

Apple M2 Max, 12 çekirdek, 32 GiB RAM; Node v25.8.0; PostgreSQL 16.13; gerçek Redis. PostgreSQL ve Redis yalnızca bu inceleme için ayrı yerel portlarda başlatıldı. Canlı servis, gerçek müşteri, e-posta veya ödeme kullanılmadı. Uygulamanın ürün kodunda değişiklik yapılmadı.

Ölçüm verisi: 2.000 kullanıcı, 2.000 işletme, 20.000 aktif/ileri tarihli paket, 50.000 geçmiş sipariş ve 100 kampanya. Tüm gerçek migration'lar ve üretim indeksleri uygulandı. İşletmeler İstanbul çevresinde sentetik bir ızgaraya dağıtıldı; ana paket sorgusunun 50 km yarıçapında 20.000 sonuç var. Sonraki doğruluk deneyleri birkaç ek kayıt oluşturdu.

API `NODE_ENV=production` ile, gerçek kimlik doğrulama ve hız limitleri açıkken çalıştı. Yük üreteci ve API ayrı Node süreçleri; HTTP keep-alive kullanıldı. Farklı sentetik kullanıcılar hız sınırı hatalarının başarı gibi sayılmasını önledi. İlk kısa koşumun ardından temel senaryolar yaklaşık 6 saniyelik sürekli yükle tekrarlandı. Bu bir kapasite sertifikasyonu veya uzun süreli dayanıklılık testi değildir.

Docker/VPS, TLS, ters proxy, gerçek internet gecikmesi, cron işleri, Sentry ve dış sağlayıcılar bu ölçümlere dahil değil. Depodaki Docker imajı Node 24 kullanıyor; yerel Node 25 sonuçları üretim kapasitesi olarak yorumlanmamalı. Mobil fiziksel cihazda profil modu, FPS, pil ve açılış kronometresi ölçülmedi; mobil bulgular testler ve kod incelemesine dayanıyor.

**İşlevsel doğrulama**

| Kontrol | Sonuç |
| --- | --- |
| Backend Jest entegrasyon testleri | 9 dosya, 98/98 başarılı; 16,833 s |
| Web testleri | 7/7 başarılı |
| Next.js üretim derlemesi | Başarılı; 37 statik sayfa üretildi |
| Flutter güncel test koşumu | 15/15 başarılı |
| Flutter statik analiz | Sorun bulunmadı |

Flutter'ın ilk koşumunda `campaign_ui_test.dart` içindeki `find.byTooltip` sonucunun `IconButton` olarak dönüştürülmesi hata verdi. İnceleme sırasında test dosyası başka bir çalışma tarafından güncellendi; güncel dosyayla tüm mobil testler tekrar çalıştırıldı ve geçti. İlk ve son koşum logları ayrı saklandı. Normal testlerin geçmesi aşağıdaki 50 eşzamanlı sipariş sorununu dışlamıyor; mevcut stok yarışı testi iki istek kullanıyor.

**API süreleri**

p95, isteklerin %95'inin belirtilen sürede tamamlandığı anlamına gelir. Eşzamanlılık aktif HTTP isteği sayısıdır; toplam kullanıcı kapasitesi değildir. Tablo `followup-results.json` içindeki daha uzun koşumlardan alınmıştır.

| Senaryo | Eşzamanlı istek | Ölçülen istek | Ortanca | p95 | İstek/s | Sonuç |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Paket listesi, önbellek isabeti | 50 | 56.829 | 5,1 ms | 6,3 ms | 9.465 | Tümü 200 |
| Paket listesi, Redis önbellek ıskası | 50 | 1.988 | 150,3 ms | 187,8 ms | 324 | Tümü 200 |
| Kuponlarım, 100 kampanya | 50 | 400 | 720,9 ms | 1.092,3 ms | 62,8 | Tümü 200 |
| Harita, 500 işletme | 50 | 4.046 | 66,8 ms | 82,2 ms | 668 | Tümü 200 |
| Dolu sipariş geçmişi, 20 kayıt | 10 | 3.264 | 17,9 ms | 24,8 ms | 543 | Tümü 200 |

Paket önbellek ıskaları çok küçük yarıçap değişimleriyle farklı anahtarlar oluşturarak sağlandı; PostgreSQL'in veri önbelleği temizlenmedi. Harita koşumunda başlangıçta cache süresi dolmuştu: ilk 50 istek aynı veriyi yeniden hesapladı, kalan istekler cache kullandı. Dolayısıyla harita satırı tamamen sıcak cache sonucu değildir; p99 441,5 ms, en yavaş istek 699,0 ms. İlk kısa koşumdaki boş sipariş geçmişi sonucu değerlendirmede kullanılmadı; tabloda dolu geçmiş tekrarının sonucu var.

Paket isteği cache isabetinde **0 SQL**, ıskasında **2 SQL** çalıştırıyor. Tekil EXPLAIN ANALYZE ölçümünde toplam sayma sorgusu 5,85 ms, ilk 10 paketi sıralayıp getiren sorgu 19,8 ms sürdü. Bunlar normal listeleme için olumlu sonuçlar.

**1. Kritik: yoğun siparişte 30 saniyelik bağlantı havuzu tıkanması**

Aynı işletmedeki 10 stoklu ücretsiz bir pakete farklı doğrulanmış kullanıcılarla eşzamanlı rezervasyon gönderildi. Ücretsiz paket, dış ödeme sağlayıcısını devreye sokmadan gerçek transaction/stock/notification yolunu test ediyor.

| Eşzamanlı istek | Sonuç | Toplam süre | Oluşan sipariş | Kalan stok |
| ---: | --- | ---: | ---: | ---: |
| 10 | 10 × 201 | 43 ms | 10 | 0 |
| 20 | 10 × 201, 10 × 400 “Yetersiz stok” | 71 ms | 10 | 0 |
| 50 | 20 × 500, 30 × 401 | **30,04 s** | **0** | **10** |

50 istekte bağlantı havuzunun 20 bağlantısı transaction'lar tarafından tutuldu. Bir transaction ilerlerken diğer 19'u aynı işletmenin kilidini bekledi. İlerleyen istek teslim kodu üretiminde transaction dışı `Order.findOne` çalıştırıp havuzdan ek bağlantı istedi. Bağlantı kalmadığı için kilidi bırakacak istek de bekledi. Log doğrudan `SequelizeConnectionAcquireTimeoutError → generatePickupCode → orderController.create` zincirini gösteriyor. 1,2 saniyede alınan PostgreSQL durum kaydı 19 kilit bekleyicisini ve bir açık transaction'ı doğruluyor.

İlgili kod: [sipariş içinden kod üretimi](../../src/controllers/orderController.js#L146), [transaction almayan sorgu](../../src/utils/helpers.js#L15), [20 bağlantılık havuz](../../src/config/database.js#L13).

Ayrıca kimlik doğrulama middleware'i veritabanı hatalarını da 401 “Geçersiz token” olarak döndürüyor. Testteki token'lar geçerliydi; bu 30 yanıt gerçek oturum geçersizliği değildir. [Hata eşlemesi](../../src/middlewares/auth.js#L26).

Önerilen düzeltme: `generatePickupCode` sorgusunu mevcut transaction'a dahil etmek, altyapı hatalarını uygun 5xx olarak döndürmek ve aynı/farklı işletmeler için 50+ eşzamanlı rezervasyon regresyonu eklemek. Kilit ve stok doğruluğu korunmalı; yalnız havuzu büyütmek sorunun nedenini çözmez.

**2. Yüksek öncelik: kupon ekranında sorgu sayısı kampanya sayısıyla büyüyor**

Kişisel kullanım sınırı ve bütçe sınırı olan 10 kampanyada istek başına **33 SQL**, 100 kampanyada **303 SQL** ölçüldü. Kuponlar sırayla kontrol ediliyor; her kupon için kullanıcı sayımı, bütçe toplamı ve tamamlanan sipariş sayımı tekrarlanıyor. 100 kampanya/50 eşzamanlı kullanıcıda p95 1,09 saniye. Yönetici listelemesinde istenen `limit=100` gerçekte 50'ye kırpılıyor ve 50 satır için 103 SQL çalışıyor.

İlgili kod: [mobil kupon döngüsü](../../src/controllers/couponController.js#L31), [tekrarlanan kullanım sorguları](../../src/services/couponService.js#L16).

Önerilen düzeltme: ilk sipariş uygunluğunu kullanıcı başına bir kez hesaplamak; kampanya ve kullanıcı kullanımını `GROUP BY` ile topluca almak; yalnız uygunluk kontrolünde gerekmeyen tamamlanmış sipariş sayımını çalıştırmamak. Sipariş oluştururken bütçe rezervasyonunun transaction içindeki doğruluğu ayrıca korunmalı.

**3. Yüksek öncelik: Redis kesintisi her liste isteğini yaklaşık 3,7 saniye geciktiriyor**

Redis yerine bağlantıyı reddeden boş bir yerel port kullanıldığında üç paket isteği 3.704 / 3.655 / 3.656 ms sürdü; üçü de 200 ve 10 paket döndürdü. Veri kaybolmuyor, fakat cache devre dışı kaldığında hızlı geri dönüş sağlanmıyor. Sürüm okuma, cache okuma ve yazma sırasında yeniden bağlantı denemeleri bekleniyor. [Cache erişimi](../../src/services/cacheService.js#L47).

Önerilen düzeltme: liste cache'i için kısa süre sınırı ve bağlantı arızasından sonra bir süre yeniden denemeyi durduran mekanizma. Oturum/token deposunun güvenlik gereklilikleri ayrı tutulmalı. Test bağlantı reddini kapsar; ağ paketlerinin sessizce düşmesi ayrıca ölçülmedi.

**4. Mobil açılış ve harita ilk gösterimi gereksiz bekleyebilir**

Açılış sahnesi kodda **4.200 ms**; yönlendirme sahnenin tamamlanmasını zorunlu bekliyor. Oturum ve konum hazır olsa bile kullanıcı ana ekrana daha erken ulaşamıyor. Bu bir cihaz kronometresi sonucu değil, kodun koyduğu alt sınırdır. [Animasyon süresi](../../bitir_yemek_mobile/lib/features/splash/presentation/widgets/aurora_scene.dart#L34), [bekleme](../../bitir_yemek_mobile/lib/features/splash/presentation/pages/splash_page.dart#L46).

Haritada tüm logo yüklemeleri `Future.wait` ile tamamlandıktan sonra işaretçiler topluca çiziliyor; tek yavaş logo 6 saniyelik timeout'a kadar diğer işletme işaretçilerini de bekletebilir. [Toplu bekleme](../../bitir_yemek_mobile/lib/features/map/presentation/pages/map_page.dart#L248), [logo timeout'u](../../bitir_yemek_mobile/lib/features/map/presentation/pages/map_page.dart#L509). Bu etki kod incelemesinden çıkarımdır; cihazda süre ölçülmedi.

Önerilen düzeltme: dönen kullanıcıda kısa/atlanabilir splash; hazır konumla erken gösterim; varsayılan harita işaretçilerini hemen çizip logoları geldikçe güncellemek. Sekmelerin ihtiyaç halinde yüklenmesi, paylaşılan BLoC'lar ve kart görsellerinin gösterim boyutunda çözülmesi mevcut olumlu uygulamalar.

**5. Konum cache'i doğruluk kaybına yol açıyor**

İki farklı koordinat iki ondalıkta aynı cache anahtarına yuvarlanıyor. 0,5 km yarıçapıyla A noktasından sorgu yapıldıktan sonra B noktasının cache cevabında yakındaki test işletmesi yoktu. Cache geçersiz kılınıp B tekrar sorgulanınca işletme göründü. Üç istek de 200 döndü. Bu, yalnız mesafe etiketinin yaklaşık olması değil, sonuç üyeliğinin değişmesidir. [Koordinat anahtarı](../../src/controllers/businessController.js#L37).

Önerilen düzeltme: cache'de hücrenin daha geniş aday kümesini tutup gerçek koordinatla son filtre/sıralama yapmak veya sorgu hassasiyetini koruyan anahtar kullanmak. Aynı desen paket ve harita servislerinde de bulunuyor; çalıştırılan doğruluk deneyi işletme listesine aittir.

**6. Şifreli giriş trafiği diğer istekleri de yavaşlatıyor**

Tek eşzamanlı şifreli giriş yaklaşık 68 ms ortancayla tamamlanırken, 10 eşzamanlı girişte p95 725 ms'ye çıktı; aktarım yaklaşık 15 giriş/s civarında kaldı. Beş giriş ve beş paket isteğinin birlikte üretildiği ayrı deneyde cache'den paket getirme p95 **335 ms**, event-loop gecikmesi p95 **263 ms** oldu. [Şifre kontrolü](../../src/models/User.js#L95).

Önerilen düzeltme: şifre doğrulama CPU işini ana istek döngüsünden ayırmak; mevcut hash güvenlik parametrelerini korumak. Bu ölçüm şifreli girişe aittir, mobil OTP/e-posta sağlayıcısının süresini ölçmez.

**Web ve kaynak kullanımı**

Next.js standalone üretim sunucusunda 10 eşzamanlı istekte ana sayfa HTTP p95 **8,5 ms**, giriş sayfası **18,6 ms**; hata yok. Bunlar sunucu/transfer süreleri; tarayıcı çizimi, LCP, INP veya gerçek mobil bağlantı ölçümü değildir.

İşletme konum sayfasındaki Mapbox JS parçası 1.823.467 bayt ham / 501.497 bayt gzip. Build manifestine göre bu parça `/panel/isletme` sayfasına aittir; genel ana sayfa yükü olarak sayılmadı. [Doğrudan import](../../web/src/components/panel/LocationPicker.tsx#L5). Harita gerektiğinde dinamik yükleme ilk panel yükünü azaltabilir.

API sürecinin RSS belleği uzun koşumlarda yaklaşık 380–743 MiB aralığına çıktı; 500 işletmeli harita cevabı yaklaşık 259 KiB. Harita koşumu sonunda JS heap yaklaşık 65 MiB idi. RSS artışı tek başına bellek sızıntısı kanıtı değildir; buffer/allocator davranışı ve uzun süreli ölçüm gerekir. Redis bu sentetik veri/cache kümesinde yaklaşık 30,6 MiB tepe kullanımına ulaştı. Süreç CPU ölçümleri yalnız API sürecine aittir; PostgreSQL, Redis ve yük üretecinin toplam CPU'sunu göstermez.

Üretim genel hız sınırı ayrıca doğrulandı: aynı anahtarın 105 isteğinden 100'ü 200, son 5'i 429; pencere 15 dakika. Bu kasıtlı limit deneyinin yanıtları performans tablosuna karıştırılmadı.

**Tekrarlama ve kanıtlar**

Backend deneylerini yeni ve geçici yerel servislerle tekrar çalıştırmak için:

```bash
bash docs/performance-2026-09-08/run-backend.sh
```

Betik Homebrew PostgreSQL 16 ve PATH'te Redis/Node bekler; farklı kurulumda `PERF_PG_BIN` verilebilir. Çıktı dosyalarını yeniler; kendi geçici servislerini çıkışta kapatır. İlk incelemedeki kurulum ve komutlar ayrı adımlarla çalıştırıldı; bu sarmalayıcı tekrar çalıştırma kolaylığı için sonradan eklendi, bash sözdizimi kontrolünden geçirildi.

Başlıca kanıtlar: [uzun koşumlar ve sipariş tıkanması](followup-results.json), [hata stack'leri](followup.log), [ilk matris ve cache doğruluğu](benchmark-results.json), [Redis kesintisi](redis-outage-results.json), [SQL planları](packages-query-plans.json), [web süreleri](web-http-results.json), [güncel mobil testleri](flutter-tests-current.log).

İncelenen checkout HEAD: `af8e29c26d3e11c3ad89f42bf0e2e94ad618e523`; çalışma dizininde önceden var olan değişiklikler dahil edildi. Kritik dosyaların hash ve son değişiklik zamanları [kaynak parmak izlerinde](source-fingerprints.json) kayıtlıdır. Düzeltmeler uygulandıktan sonra özellikle 50+ eşzamanlı sipariş, cache arızası ve kupon sorgu sayısı yeniden doğrulanmalıdır.
