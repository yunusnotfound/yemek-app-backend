# Güvenlik düzeltmeleri — 8 Eylül 2026

Express/Sequelize/PostgreSQL/Redis backend, Next.js web ve Flutter mobil mimarisi korundu. Düzeltmeler yerel çalışma ağacında hazırlandı. Canlı sisteme dağıtım, canlı veritabanı geçişi, gerçek banka işlemi veya gerçek kullanıcıya test e-postası yapılmadı. Önceden bulunan mobil değişiklikler ve diğer çalışmalar korunmuştur.

## Yapılanlar

| Alan | Yeni davranış |
| --- | --- |
| Ödeme eşleştirme | Kayıtlı checkout tokenı, sağlayıcı basket/kalem kimlikleri ve ödeme kimliği aynı siparişe ait olmalı. İstemcinin gönderdiği `conversationId` ödeme kanıtı sayılmaz. Tutar kuruş cinsinden tam eşleşir; para birimi TRY olmalıdır. |
| Mükerrer ödeme | `paymentId`, `paymentTransactionId`, `paymentToken` için veritabanı benzersizlik indeksleri eklendi. |
| 3DS | Başlatma yanıtındaki ödeme kimliği saklanır. Sahte başarısız callback siparişi iptal edemez. Sonuç her zaman iyzico API'sinden doğrulanır. |
| Webhook | Direct ve HPP için `X-IYZ-SIGNATURE-V3` doğrulaması zorunlu. Geçersiz imza reddedilir; geçici sunucu hatası sağlayıcının tekrar deneyebilmesi için 503 döndürür. |
| Fraud incelemesi | `fraudStatus=1` olmadan ödeme teslim edilebilir duruma geçmez. İncelenen tahsilatın rezervasyonu zaman aşımıyla kaybolmaz. |
| İade | Sipariş iptali ve iade talebi, banka çağrısından önce veritabanına yazılır. Teslim ve iade yarışamaz. Belirsiz banka yanıtı başarılı iade gibi gösterilmez ve otomatik ikinci iade başlatılmaz. |
| Gecikmiş ödeme | İptal edilmiş son 7 günlük check-out'lar periyodik sorgulanır. Kaybolan callback sonrası tahsilat bulunursa iade takibine alınır. |
| Hesap doğrulama | E-posta doğrulanmadan kayıt token üretmez; korumalı API'ler doğrulanmamış hesabı kabul etmez. OTP ile sahiplenilen doğrulanmamış kayıttaki eski şifre ve oturumlar iptal edilir. |
| OTP / şifre sıfırlama | OTP tüketimi ve 5 deneme sınırı eşzamanlı isteklere karşı kilitlenir. Şifre sıfırlama artık e-posta + kod ister; hesap başına 5 deneme sınırı ve eski oturumların iptali uygulanır. Kod isteme ve parola girişinde hesap bazlı Redis sınırları vardır. |
| Google / Apple | Audience kontrolü zorunlu. İmzalanmamış Apple e-postası/kimliği kullanılmaz. Google'ın e-posta üzerinde yetkili olmadığı hesaplarda otomatik e-posta eşleştirmesi yapılmaz; OTP gerekir. Silinen hesaplar girişle geri açılamaz. |
| Oturum | JWT'lere tür, benzersiz kimlik ve hesap oturum sürümü eklendi. Redis'te refresh token tek atomik işlemle tüketilir. Oturum deposu başarısızlığı doğrulamayı atlatamaz. |
| Mobil | Hassas HTTP gövde/header logları kaldırıldı. Eşzamanlı 401'ler tek yenileme paylaşır; ikinci 401 kilitlenmez. Çıkış sunucu tokenını iptal eder. Ödemeden vazgeçme gerçek iptal isteği gönderir. İade bekleyen iptal edilmiş sipariş ödeme başarısı göstermez. |
| Moderasyon / silme | İşletme sahibi yönetici askısını kaldıramaz. Aktif sipariş, ödeme veya iade varken hesap/işletme/paket silinemez. Yönetici silmesinde de aynı kontrol geçerlidir. Son yönetici eşzamanlı işlemlerle kaldırılamaz. |
| Sipariş / stok | Pasif işletme, askıya alınmış paket ve teslim süresi dolmuş paket sipariş alamaz. Kullanıcı başına en fazla 3 eşzamanlı ödeme rezervasyonu vardır. Stok güncellemesi kilitlenir; pickup kodu çakışması savepoint içinde yeniden denenir. |
| Web | Yazma istekleri için aynı origin kontrolü; yönlendirme adresi doğrulaması; akış okunurken gövde boyutu sınırı; eşzamanlı oturum yenileme koruması; süresi dolan yönetici oturumunun kurtarılması eklendi. Kullanılmayan uzak görsel optimizasyon servisi kapatıldı; mevcut `<img>` gösterimi korunur. |
| Sunucu | Express 5 query doğrulaması gerçekten uygulanır. Ödeme poll limiti genel limit tarafından ezilmez; callback uçları da sınırlıdır. Upload sayısı/boyutu ve disk boşluğu kontrol edilir. TLS sertifika doğrulaması zorunludur; log/Sentry verileri temizlenir. |
| Bağımlılıklar | Backend ve web kilit dosyaları güvenlik yamalarıyla güncellendi. Sequelize v6, Express v5 ve Next v16 korundu. Docker/CI/.nvmrc Node 24 kullanır. Migration CLI artık bildirilmiş bağımlılıktır. |

## Dağıtım sırası ve gerekli ayarlar

1. Veritabanı yedeğini alın. `20240101000028-security-hardening.js` geçişini dağıtımdan önce kontrol edin. Eski kayıtlarda aynı banka ödeme/işlem/token kimliği birden fazla siparişte varsa migration atomik olarak durur; kayıt silmez veya kendiliğinden birleştirmez. Böyle bir durum önce banka kayıtlarıyla karşılaştırılmalıdır.
2. Web sürümünü yayımlayın. Yeni web, eski backend'e de e-posta alanıyla şifre sıfırlama isteği gönderir ve kayıt sonrası doğrulama mesajını gösterir. Ardından migration'ı çalıştırıp yeni backend'i başlatın. Eski web ile yeni backend arasında kayıt/şifre sıfırlama uyumsuzluğu bırakmayın.
3. Üretim ortamında `npm run db:migrate -- --env production` çalıştırın. Bu işlem burada yalnız ayrılmış test veritabanlarında denendi; canlıda çalıştırılmadı.
4. iyzico hesabında webhook signature özelliğini etkinleştirin. İmza **IYZICO_SECRET_KEY** ile doğrulanır. Eski `IYZICO_WEBHOOK_SECRET` ve `IYZICO_WEBHOOK_ENFORCE=false` doğrulamayı kapatmaz. Mevcut callback, poll ve reaper yolları korunmuştur.
5. `JWT_SECRET` ve `JWT_REFRESH_SECRET` farklı, güçlü değerler olmalı. Redis erişilebilir olmalıdır. Canlı iyzico ortamında `IYZICO_TEST_DIRECT_CHARGE=true` kabul edilmez.
6. Özel sertifika otoritesi kullanan TLS bağlantılarında `DB_CA_CERT` / `REDIS_CA_CERT` içine güvenilen PEM sertifikasını verin. Doğrulamayı kapatan seçenek kullanmayın. `DATABASE_URL` içindeki TLS parametrelerinin bu denetimi ezmesi de engellendi.
7. Caddy'nin gerçek `Host` ve `X-Forwarded-Proto` bilgilerini ilettiğini doğrulayın. İsteğe bağlı `WEB_ORIGIN=https://alan-adiniz` CSRF kontrolünün origin'ini sabitler. `TRUST_PROXY` yalnız gerçek ingress/proxy adreslerini kapsamalıdır; backend portunu doğrudan internete açmayın.
8. Mobil sürümü dağıtın. Mevcut mobil OTP giriş şekli korunur; yeni sürüm oturum yenileme, çıkış ve ödeme iptali düzeltmelerini içerir.

Gerçek `.env` dosyaları veya anahtarlar değiştirilmedi; yeni ayarlar örnek dosyalarda açıklanmıştır. E-posta doğrulanmamış kullanıcıların girişten önce doğrulaması gerekir. Hesap silmeden önce bekleyen siparişler iptal edilmeli veya tamamlanmalıdır.

## İade takibi

`refundStatus`: `none → pending → processing → completed`. Banka yanıtı belirsizse veya ödeme kanıtı eksikse `review` kullanılır. İşlem başladıktan sonra süreç kapanırsa eski `processing` kayıtları da incelemeye alınır. Yalnız banka başarı yanıtından sonra `paymentStatus=refunded` yazılır.

Yönetim paneli **Siparişler → İade kontrolü** sekmesi `review` kayıtlarını listeler. Sipariş detayında işlem kimliği ve kontrol uyarısı görünür. Bu kayıtlar için banka panelindeki ödeme/iade sonucunu doğrulamadan ikinci iade yapılmamalıdır. Sağlayıcı sonucu doğrulandıktan sonra yetkili operasyon ekibi veritabanıyla mutabakat yapmalıdır; belirsiz sonucu otomatik “başarılı” sayan veya körlemesine tekrar eden bir yol eklenmedi. `pending` talepler mevcut 15 dakikalık görevde işlenir. Bu tasarım, mevcut tek backend ve tek web sunucusu dağıtımını korur; çoklu web instance'a geçerken yenileme birleştirmesi ortak depoya taşınmalıdır.

Geçiş, geçmişte iptal edilmiş fakat hâlâ ödenmiş görünen kayıtları `review` olarak işaretler. Yönetici denetim geçmişindeki son askıya alma kararları da yeni `isSuspended` alanına taşınır. Geçmişteki olası hatalı tahsilat veya hesap erişimini yalnız kod değişikliğiyle geri almak mümkün değildir; canlı geçmiş üzerinde mutabakat yapılmadı.

## Doğrulama

- Backend: **84/84 test başarılı**. Entegrasyon testleri Node 24, ayrılmış PostgreSQL 16 ve Redis üzerinde; iyzico, e-posta, Google ve Apple çağrıları ilgili testlerde taklit edildi.
- Web: **7/7 güvenlik testi başarılı**; TypeScript ve üretim derlemesi. Lint hata vermiyor; mevcut form memoization ve tam sayfa yönlendirme kullanımına ilişkin 6 uyarı var. Next.js ayrıca mevcut middleware dosya adının gelecekte proxy olarak değiştirilmesini öneriyor.
- Flutter: **6/6 test başarılı**, statik analiz temiz; oturum/ödeme güvenlik testleri ve açılış testi başarılı. Eski açılış testinin metin-logo varsayımı mevcut animasyonlu açılış ekranına uyarlandı; ürün ekranı değiştirilmedi.
- Gerçek Next.js üretim sunucusu ile izole API arasında 7 HTTP kontrolü başarılı: giriş, yönetici kapısı, CSRF, çıkış ve kapatılmış görsel servisi.
- Migration zinciri boş test veritabanına uygulandı; yeni migration geri alınıp tekrar uygulandı.
- Backend ve web `npm audit`: bilinen açık bulunmadı. Bu, tarama anındaki bağımlılık veritabanının sonucudur; tüm uygulama için mutlak güvenlik garantisi değildir.

Canlı banka/sandbox anahtarlarıyla uçtan uca 3DS, gerçek OAuth sağlayıcıları ve Docker imajı çalıştırılması bu yerel doğrulamaya dahil değildir. Canlıya çıkışta test hesabıyla ödeme, fraud incelemesi, callback ve iade akışları ayrıca doğrulanmalıdır.

## Referanslar

- [iyzico webhook V3 doğrulaması](https://docs.iyzico.com/ek-servisler/webhook)
- [Google sunucu tarafı kimlik doğrulama ve e-posta otoritesi](https://developers.google.com/identity/sign-in/web/backend-auth)
- [Apple imzalı kimlik tokenı alanları](https://developer.apple.com/documentation/signinwithapple/receiving-a-users-identity-token)
