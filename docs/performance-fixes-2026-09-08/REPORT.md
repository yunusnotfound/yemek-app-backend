# Performans düzeltmeleri — 8 Eylül 2026

Uygulamanın mevcut Flutter/BLoC, Express, PostgreSQL ve Redis yapısı korundu. Üretim hesabı, ödeme sağlayıcısı veya canlı veritabanı kullanılmadı. Çalışma dizininde başka görevlerin değişiklikleri de bulunduğundan bütün git farkı bu performans çalışmasına ait değildir.

## Ölçülen sunucu sonucu

Önceki ve sonraki koşum aynı M2 Max makinede, production modunda, ayrı yerel PostgreSQL/Redis üzerinde; 2.000 kullanıcı, 2.000 işletme, 20.000 paket, 50.000 geçmiş sipariş ve 100 kuponla yapıldı. Kimlik doğrulama ve hız sınırları açıktı. Aşağıdaki ana tablo altışar saniyelik kapalı döngü yük testidir; internet, TLS ve telefon ağı süresini içermez. p95, isteklerin %95'inin altında tamamlandığı süredir.

| Senaryo | Eşzamanlılık | Önce p95 | Sonra p95 | Önce → sonra istek/s |
|---|---:|---:|---:|---:|
| Paket, önbellek isabeti | 50 | 6,34 ms | 7,34 ms | 9.465 → 8.713 |
| Paket, önbellek ıskası | 50 | 187,78 ms | 181,59 ms | 324 → 337 |
| 100 kupon | 50 | 1.092,34 ms | **117,58 ms** | 62,8 → **535,7** |
| Harita, 500 işletme | 50 | 82,23 ms | 81,58 ms | 668 → 723 |
| Sipariş geçmişi, 20 kayıt | 10 | 24,82 ms | 24,36 ms | 542,5 → 543,4 |

Kupon sorguları **303'ten 5'e** indi; p95 yaklaşık **%89 azaldı**. Önbellekli paketlerde bu koşumda p95 %15,7 arttı (yaklaşık 1 ms), aktarım %7,9 düştü. Paket ıskası, harita ve sipariş geçmişinde genel bir hızlanma iddiası yoktur; bunlar tek koşumdur, küçük farklar için istatistiksel kesinlik iddia edilmez.

- **Rezervasyon:** 10 stok için 50 eşzamanlı isteğin tamamı önceden yaklaşık 30 saniyede başarısız oluyordu. Sonra toplam **128 ms**: 10 sipariş oluştu, 40 istek doğru “Yetersiz stok” yanıtını aldı, kalan stok 0. Yanlış 401/500 yok. Teslim kodu sorgusu mevcut transaction bağlantısını kullanıyor; havuzun kendi kendini kilitlemesi giderildi.
- **Giriş sırasında gezinme:** 5 giriş ve 5 paket istemcisinin birlikte çalıştığı 6 saniyelik deneyde paket p95 **334,94 → 1,08 ms**, event-loop p95 **263,19 → 10,19 ms**. bcrypt maliyeti düşürülmedi; mevcut hash uyumu korunarak iş sınırlı worker havuzuna taşındı. Bu deneyde CPU yaklaşık 1 çekirdekten 4,9 çekirdeğe çıktı; kazanım paralellikten geliyor, daha düşük toplam enerji tüketimi kanıtı değildir.
- **Redis erişilemiyor:** üç paket isteği önceden 3.704 / 3.655 / 3.656 ms; sonra **62,5 / 24,3 / 23,3 ms**, hepsi 200. İsteğe bağlı liste önbelleği hızlıca devreden çıkıyor. Oturum ve giriş sınırları kendi sıkı Redis davranışını koruyor. Cevap vermeyen açık TCP bağlantısı için ek arıza testinde ilk komut yaklaşık 101 ms ile sınırlandı; iyileşme sonrasında biriken geçersiz kılmalar yeniden uygulandı.
- **Harita soğuk yükü:** aynı anda gelen aynı sorgular tek işlemde birleştiriliyor. Ana harita koşumunda kimlik doğrulama dışındaki sorgular **100 → 2**, p99 **441,54 → 86,85 ms** oldu. Sıcak önbelleğin ortalama hızında belirgin kazanç yok.
- **Konum doğruluğu:** birbirine yakın ama yarıçap sınırının farklı tarafındaki iki koordinat artık aynı yuvarlanmış önbellek sonucunu paylaşmıyor. Eski `false / false / true` sınır sonucu yeni koşumda **false / true / true**. Sipariş/iptal sonrası haritadaki stok sayısının yenilendiği de test edildi.

Sabit sayılı kısa deneyler ana tabloya dahil değildir: admin kupon listesi (50 satır, 60 istek, 10 eşzamanlı) SQL **103 → 4**, p95 **63,05 → 14,16 ms**; parola girişi (40 istek, 10 eşzamanlı) p95 **724,87 → 210,32 ms**. Tek istemcili 10 girişte ortanca yaklaşık 68 ms olarak kaldı. Kısa paket ıskası koşumu 183,85 → 205,36 ms ile kötüleşti; ana koşumdaki küçük fark genel kazanç olarak yorumlanmamalı.

Yeni `packages-warm` tekil probu, Redis bağlantısı henüz hazır olmadığından 2 SQL çalıştırdı; adına bakılarak önbellek isabeti sayılmadı. Sonraki isabet yük testlerinde 0 SQL doğrulandı. Ham JSON'daki `geoCacheBoundary.explanation` alanı eski sabit test açıklamasıdır; doğru sonuç yukarıdaki boolean alanlarından okunmalıdır.

## Mobilde değişen davranış

- Daha önce giriş yapmış kullanıcı 4,2 saniyelik tanıtım animasyonunu zorunlu olarak beklemiyor. İlk kullanıcı animasyonu korundu. Konum ve izin beklemelerine zaman sınırı eklendi; uygun ve en fazla 2 dakikalık son konum açılışta kullanılabiliyor. Kullanıcının açıkça istediği konum yenilemesi taze ölçüm yapmaya devam ediyor.
- Harita işaretçileri logolar bitmeden 24'lü gruplar halinde gösteriliyor. Logolar en fazla 4 paralel iş ile sonradan ekleniyor; eski nesillerin sonuçları yeni haritayı ezemiyor. Logo çözme boyutu 192 piksele sınırlandı; raster kaynakları serbest bırakılıyor, işaretçi önbelleği 200 girişle sınırlı. Bu bir Flutter iş kuyruğu sınırıdır; zaman aşımına uğrayan bir ağ indirmesinin kesin olarak iptal edildiği iddia edilmez.
- Genel mobil bellek önbelleği 100 girişlik LRU ile sınırlı. Kupon listesi bütün kartları baştan oluşturmak yerine görünen kartları ihtiyaç oldukça oluşturuyor.
- Web işletme formundaki Mapbox bileşeni dinamik yükleniyor. BLoC yapısı, ekran yolları ve API yanıt biçimleri değişmedi.

## Doğrulama ve cihaz kapsamı

- Backend: **138/138 test**, 15 dosya; stok yarışları, kupon bütçeleri, kimlik doğrulama ve Redis toparlanma yarışları dahil.
- Flutter: **41/41 birim/widget testi**, kaynaklar ve telefon entegrasyon testi analizinde sorun yok.
- Web: **7/7 test**, production derlemesi başarılı.
- Normal `lib/main.dart` giriş noktasıyla **iOS release derlemesi başarılı**: 67,1 MB, arm64, iOS 15.6 alt sınırı. Ayrı geçici kopyada `--no-codesign` ile doğrulandı; üretim bundle kimliği ve native proje dosyaları korundu. Bu imzasız paket telefona kurulmadı.
- Android yapılandırmasında gerçek bir bağımlılık uyuşmazlığı giderildi: `minSdk=21` yerine `flutter.minSdkVersion`; kurulu Flutter 3.41.5 ile **API 24 / Android 7.0**. Android SDK ve Android cihaz bulunmadığından APK/manifest birleştirme ve gerçek Android performansı bu testlerin kapsamında değil.
- iOS Runner hedefi **15.6**; bu sürüm veya üstünü çalıştıran iPhone 11 hedefi karşılıyor. Bağlı cihaz iPhone 16 Pro / iOS 18.3. **iPhone 11 üzerinde ölçüm yapılmadı.** Ekran ölçülerini iPhone 11 boyutuna getiren widget testi, A13 işlemci performansını taklit etmez.

Performans testi profile modunda gerçek `HomePage`, `AllPackagesView`, `CouponsPage` bileşenlerini; 80 paket, 100 kupon, her yanıt/görsel için 150 ms yerel gecikme ile çalıştırır. Bu ölçüm soğuk işletim sistemi açılışı, gerçek internet/API veya native Mapbox FPS ölçümü değildir. Her sahnede build/raster süreleri ve 60/120 Hz kare bütçesini aşan kare sayısı kaydedilir. [Flutter fiziksel cihaz/profile ölçüm rehberi](https://docs.flutter.dev/perf/ui-performance).

Fiziksel karşılaştırma yalnız bu çalışmanın mobil performans dosyalarını değiştirerek yapıldı; eşzamanlı diğer tasarım değişiklikleri iki telefon varyantına karıştırılmadı. Test senaryosu ve ölçülen ekranların diğer kaynakları aynıydı. İki varyantın dosya SHA'ları `iphone-before-source-fingerprints.json` ve `iphone-after-source-fingerprints.json` içinde. Genel bellek LRU düzeltmesi ilk telefon kopyası alınırken zaten mevcuttu; bu telefon A/B deneyi onun etkisini ölçmez. Tam güncel çalışma ağacı ayrıca 41 test ve normal iOS release derlemesiyle doğrulandı.

İlk denemelerde Flutter'ın kablosuz VM servisi keşfi sonuç vermedi. Profil AOT uygulaması `devicectl` ile doğrudan çalıştırılıp konsol çıktısı alındı (`OS_ACTIVITY_DT_MODE=enable`). Son geçerli senaryo gerçek 120 Hz yenilemeye izin veren `fullyLive` frame policy kullanır; önceki eksik/başarısız denemeler ölçüm sonucu sayılmadı. Ayrı `com.bitiryemek.performance` test kimliği kullanıldı. Sonuç toplayıcı `complete=true`, `profileMode=true` ve “All tests passed!” olmadan başarılı sonuç dosyası oluşturmuyor.

## Gerçek iPhone sonucu

İki koşum da fiziksel **iPhone 16 Pro / iOS 18.3 / 120 Hz** üzerinde profile modunda, yaklaşık 2 dakika 40 saniyede **başarıyla tamamlandı**. Her koşumda 66 gerçek yerel görsel isteği, 2 kupon isteği ve 3 paket yenilemesi gerçekleşti. Rakamlar tek bir önce/sonra eşleşmesidir; küçük farklar için istatistiksel hızlanma iddiası yoktur.

| Sahne | Build p95 önce → sonra | Raster p95 önce → sonra | Yeni ölçümde kare sayısı |
|---|---:|---:|---:|
| Ana sayfa ilk gösterim | 1.467 → 1.456 ms | 1.284 → 1.311 ms | 154 |
| Ana sayfa kaydırma | 0.981 → 0.966 ms | 1.074 → 1.067 ms | 1379 |
| Paket listesi ilk gösterim | 0.986 → 1.050 ms | 1.063 → 1.074 ms | 145 |
| Paket kaydırma, yeni görseller | 1.136 → 1.133 ms | 1.288 → 1.215 ms | 6290 |
| Paket kaydırma, önbellekte görseller | 0.616 → 0.485 ms | 0.867 → 0.837 ms | 6249 |
| Kuponlar ilk gösterim | 4.180 → 4.402 ms | 1.550 → 1.242 ms | 22 |
| Kupon kaydırma | 0.568 → 0.566 ms | 0.679 → 0.693 ms | 4587 |

Yeni sürümde dört kaydırma sahnesindeki **18,505 karede** build veya raster süresinin 8,33 ms / 16,67 ms sınırını aştığı örnek yok. Önceki sürüm de bu güçlü telefonda kaydırma bütçelerini karşılıyordu; burada büyük bir FPS artışı ölçülmedi. Ana kazanç sunucu beklemelerinin azaltılmasıdır. Bu sayım yalnız Flutter build/raster bütçesidir; bağımsız native ekran FPS ölçümü değildir.

İlk ana sayfa gösteriminde **iki sürümde de bir uzun build karesi** var: 25,51 → 26,66 ms. İlk paket gösteriminde build maksimumu 11,78 → 12,91 ms; bu bir karede 120 Hz bütçesini aşıyor. İlk gösterimin tamamen takılmasız olduğu iddia edilmez. Kupon sayfasındaki p95 build 4,18 → 4,40 ms; fiziksel koşum bu sayfanın belirgin hızlandığını kanıtlamadı. Kupon kaydırması sonundaki RSS 121,73 → 117,38 MiB; tek anlık RSS farkı bellek sızıntısı veya kesin bellek kazancı kanıtı sayılmadı.

“İlk gösterim” ölçüsü bileşenin yerleştirilmesinden animasyonların/görsellerin durulmasına kadardır; uygulamanın soğuk açılış süresi değildir. iPhone 11, Android, gerçek internet ve native harita etkileşimleri için fiziksel doğrulama hâlâ gerekir.

[Önceki telefon JSON](iphone16pro-before.json) · [Yeni telefon JSON](iphone16pro-after.json) · [Önce konsol](iphone-before-live-console.log) · [Sonra konsol](iphone-after-live-console.log)

## Kanıt dosyaları

- [Önceki rapor](../performance-2026-09-08/REPORT.md), [önceki ana ölçümler](../performance-2026-09-08/followup-results.json)
- [Yeni ana ölçümler](followup-results.json), [yeni kısa koşumlar](benchmark-results.json), [Redis kesintisi](redis-outage-results.json)
- [Backend test JSON](backend-tests.json), [Flutter testleri](flutter-unit-tests-final.log), [Flutter analiz](flutter-analyze-final.log), [web testleri](web-tests.log), [web derlemesi](web-build.log)
- [Mobil platform kanıtları](mobile-platform-compatibility.md)
- [Normal iOS release derlemesi](ios-release-build.log), [release paket bilgisi](ios-release-artifact.json)
- [Telefon testini tekrar çalıştırma](../../bitir_yemek_mobile/integration_test/README.md), [izole test scripti](../../bitir_yemek_mobile/tool/profile_phone.sh)
- Telefon senaryosu: `bitir_yemek_mobile/integration_test/phone_performance_test.dart`; sürücü: `bitir_yemek_mobile/test_driver/phone_performance.dart`.

Sunucu senaryoları bu klasördeki `benchmark.cjs`, `benchmark-server.cjs`, `followup.cjs`, `redis-outage.cjs` ile tekrar çalıştırılabilir. Yalnız ayrı, yeni, yerel PostgreSQL/Redis kullanın; scriptler özel benchmark veritabanını oluşturur, uygulamanın normal `.env` dosyasını yüklemez. `PERF_DB_PORT` ve `PERF_REDIS_PORT` değişkenleri gerekir. Üretim kapasitesi ve bellek sızıntısı bu kısa, sentetik yerel deneylerden çıkartılamaz.

Geçici PostgreSQL/Redis durdurulup kaldırıldı. Telefona yüklenen ayrı Bitir Performans test uygulaması ve geçici mobil derleme kopyaları test sonunda kaldırıldı; raporlar, kaynak SHA kayıtları ve ham ölçümler bu klasörde tutuldu.
