# Cloudflare production hazırlığı — 25 Eylül 2026

Bu rapor [ilk CDN kurulumunun](cdn-2026-09-25.md) devamıdır. İşlemler
hesap sahibinin Cloudflare hesabındaki `bitirgitsin.com` zone'u için yapıldı.
Cloudflare **Free** ve **Images Free** korundu; ücretli abonelik veya ürün
etkinleştirilmedi. İyzico ayarları kullanıcının talebiyle değiştirilmedi.

## Canlıda tamamlananlar

- API, apex ve www origin erişimi yalnız resmi Cloudflare kaynak IP'lerine
  sınırlandı. Gerçek socket adresi kontrol ediliyor; sahte CF/XFF başlıkları
  kısıtı geçemiyor. Aynı VPS'deki diğer siteler ve ACME yanıtları korundu.
  [Origin yapılandırması, yedek ve geri dönüş](cloudflare-production-2026-09-25-origin.md).
- Auth uçlarına IP başına **20 istek / 10 saniye**, **10 saniye Block**
  uygulandı. Cloudflare'daki Free rate-limit kotası **1/1** kullanılıyor.
- Hassas dosya ve kullanılmayan WordPress yollarına dar bir WAF Block kuralı
  eklendi. Custom-rule kotası **1/5** kullanılıyor.
- Security Settings ekranındaki yönetilen Cloudflare ruleset ve HTTP DDoS
  koruması açık doğrulandı. Bot Fight Mode kapalı tutuldu; mobil API'ye
  tarayıcı challenge'ı eklenmedi.
- Universal SSL ve HTTP DDoS e-posta alarmları oluşturuldu. Mevcut Image
  Transformation Alerts alarmı ve alıcısı doğrulandı. Certificate
  Transparency Monitoring açıldı; panelde **Alerts active — 1 recipients**
  görüldü. Bu alarmlar hesap sahibinin kayıtlı e-posta adresine gönderilir.
- Cloudflare DNSSEC zone imzalama açıldı; kullanıcının açık onayıyla
  gönderilen İsimtescil talebinin ardından registrar DS kaydını yayımladı.
  **14:31:07 UTC** itibarıyla DNSSEC zinciri ve resolver AD doğrulaması başarılı.

## Auth rate-limit kuralı

Ad: `Auth endpoints - burst protection`

ID: `2e73366dbfd1461180af1c12d6912f8d`

```text
lower(http.request.uri.path) in {"/api/auth/login" "/api/auth/login/" "/api/auth/register" "/api/auth/register/" "/api/auth/otp/request" "/api/auth/otp/request/" "/api/auth/otp/verify" "/api/auth/otp/verify/" "/api/auth/forgot-password" "/api/auth/forgot-password/" "/api/auth/reset-password" "/api/auth/reset-password/" "/api/auth/resend-verification" "/api/auth/resend-verification/"}
```

Free planın path tabanlı kuralı bütün metotları, dolayısıyla varsa CORS
OPTIONS isteklerini de sayar. Native mobil istemci preflight göndermez.
Refresh, Google/Apple girişleri, logout, email doğrulama ve bütün ödeme
callback/webhook yolları eşleşmez. Origin'in mevcut daha uzun süreli auth,
OTP ve kimlik bazlı limitleri ayrıca çalışmaya devam eder.

Kural Active durumuyla kaydedildi. Sınır aşımında Cloudflare'ın gerçek
yanıtı `429`, `text/plain; charset=UTF-8`, `Retry-After: 10` oldu. JSON veya
HTML olduğu varsayılmamalıdır. Free panelde özel JSON yanıt alanı sunulmadı.

## WAF custom rule

Ad: `Block sensitive files and unused CMS probes`

ID: `4839810e0f3546c1a641765c150c8751`

```text
(http.host in {"bitirgitsin.com" "www.bitirgitsin.com" "api.bitirgitsin.com"} and (lower(http.request.uri.path) in {"/.env" "/.git" "/wp-login.php" "/xmlrpc.php" "/wp-config.php" "/wp-admin"} or starts_with(lower(http.request.uri.path), "/.env.") or starts_with(lower(http.request.uri.path), "/.git/") or starts_with(lower(http.request.uri.path), "/wp-admin/")))
```

Action: Block, Status: Active. Uygulamanın `/admin`, `/api/admin`, `/uploads`
ve `/.well-known/` yollarına genel engel eklenmedi. Bu dar kural uygulama
güvenlik kontrollerinin veya yönetilen WAF'ın yerini almaz.

## DNSSEC ve DNS geçişi

[İsimtescil destek talebi #2316681](https://isimtescil.net/panel/support/detail/2316681)
panelde **Cevaplandı** olarak doğrulandı. Destek, işlemin sağlandığını ve
yansımanın birkaç saat sürebileceğini belirtti. Gönderilen talep, nameserver geçişinin
önbellek süresi tamamlandıktan sonra aşağıdaki DS kaydının üst bölgeye
eklenmesini istiyor:

```text
bitirgitsin.com. 3600 IN DS 2371 13 2 1FFDEDDE911AFA2868F33C2D96C430C4EA64102DEC1DEE8A526E0ACBCE8B4606
```

Key Tag `2371`, Algorithm `13`, Digest Type `2` (SHA-256). Bunlar public DNS
değerleridir; özel anahtar değildir. DS kaydı Cloudflare DNS Records'a
eklenmemelidir; registrar tarafından `.com` üst bölgesine yayımlanmalıdır.
**14:31:07 UTC / 17:31:07 Türkiye saati** kontrolünde parent DS beklenen
değerle eşleşti; Cloudflare KSK DNSKEY'den hesaplanan SHA-256 digest de aynı.
DNSKEY/A RRSIG imzaları mevcut. Üç resolver'ın UDP/TCP ve Cloudflare DoH
sorgularının **14/14'ü NOERROR + AD=true** döndürdü. DNSSEC zinciri aktiftir.
Önceki pending/DS bekleme durumu bu kontrolle kapanmıştır. Geri dönüşte önce
registrar DS kaldırılıp TTL bitene kadar Cloudflare imzası açık tutulmalıdır.

Geçiş sırasında bazı resolver önbellekleri eski İsimtescil NS/parking veya
API NXDOMAIN yanıtı verdi. Root, resmi `one.one.one.one/purge-cache/` aracıyla
apex NS ve apex/API/www A kayıtlarının 1.1.1.1 önbelleğinin yenilenmesini
istedi. Zone DNS kayıtları değiştirilmedi.

**14:00:31 UTC / 17:00:31 Türkiye saati** son kontrolünde üç resolver'ın
UDP/TCP ve Cloudflare TLS doğrulamalı DoH sorgularında **28/28 doğru sonuç**
alındı: NS AMANDA/PHIL, apex/API/www A Cloudflare IP'leri, durum NOERROR.
Bu örneklem bütün internet önbelleklerinin aynı anda yenilendiğini garanti
etmez. [DNS geçişi kanıtı](cloudflare-production-2026-09-25-dns.md).

## Bildirimler ve hesap sahibine kalan adımlar

Canlı bildirimler:

| Bildirim | Durum |
| --- | --- |
| Image Transformation Alerts | Mevcut Default notification etkin, alıcı doğrulandı |
| Bitirgitsin - Universal SSL | Oluşturuldu ve etkin |
| Bitirgitsin - HTTP DDoS | Oluşturuldu ve etkin |
| Certificate Transparency Monitoring | Açık, 1 alıcı aktif |

Bildirim abonelikleri panelde doğrulandı; Test düğmesiyle ayrıca mesaj
gönderilmedi. Images Free ayda 5.000 benzersiz dönüşüm içerir; kotanın
üstündeki yeni dönüşümlerde mobil URL'nin `onerror=redirect` seçeneği
orijinale dönüş sağlar. Bu durumda hız avantajı azalabilir. HTTP DDoS
alarmının Free kapsamı 100 istek/sn üzerindeki azaltılan saldırılardır.

Cloudflare Authentication ekranında **Two-Factor Authentication Inactive**
görüldü. Kullanıcı Google ile giriş yaptığından ayrı Cloudflare parolası
henüz oluşturulmamış olabilir. Resmî sosyal giriş yönergesine göre aynı
e-posta için Forgot Password üzerinden ayrı Cloudflare parolası oluşturup
2FA kurulumunda bu parolayı kullanması istendi. Parola, doğrulayıcı kurulumu
ve kurtarma kodları hesap sahibi tarafından tamamlanmalıdır.
Kullanıcı bu adımı daha sonra tamamlayacağını açıkça belirtti; 2FA kurulumu
bu oturumda bekletilmiştir. Şifre veya doğrulayıcı bilgileri alınmadı.

Kullanıcı HetrixTools'a giriş yaptı. Mevcut `Bitir Yemek API` monitörünün
`https://api.bitirgitsin.com/api/health` adresini GET ile dakikada bir
kontrol ettiği, yalnız HTTP 200 kabul ettiği, sertifika/hostname doğrulaması
ve mevcut `Telegram` contact list'inin seçili olduğu doğrulandı. Başarılı
yanıtın içeriğini de doğrulamak için `"status":"ok"` keyword'ü eklendi;
panel **Your website monitor has been edited** onayı verdi. Yeniden açılan
formda keyword ve Telegram seçimi ayrıca doğrulandı.

`Bitirgitsin CDN Images` adında ikinci monitör oluşturuldu. İzlenen URL:

```text
https://api.bitirgitsin.com/cdn-cgi/image/width=640,fit=scale-down,format=webp,quality=85,onerror=redirect/uploads/demo-catalog-v1/kafe.png
```

HEAD yöntemi dosya gövdesini her dakika yeniden indirmeden erişilebilirliği
kontrol eder. Oluşturmadan önce gerçek HEAD isteği `200`, `HIT`, `cf-resized`
ile doğrulandı. `Accept: image/webp` gönderilmeyen bu kontrol JPEG alabilir;
mobil istemci dönüşüm URL'si için WebP Accept başlığı gönderir.

Monitör ayarları: yalnız 200 kabul, dakikada bir kontrol, 10 saniye timeout,
3 deneme, konum çoğunluğu (50%+1), SSL sertifika ve hostname doğrulaması açık,
hedef/diagnostics public raporlarda gizli. Konumlar New York, Amsterdam,
London ve Frankfurt. Mevcut Telegram contact list'i seçildi; Contact Lists
tablosunda Telegram kanalı işaretli doğrulandı. Ayrı test mesajı gönderilmedi.
Panelde iki monitör **Active ve Up** olarak doğrulandı. Yeni görsel
monitörünün ilk dış kontrolü başarılı; son kontrol yaşı 38 saniye, API'nin
son kontrol yaşı 43 saniyeydi. Görsel monitörü ID'si
`38ed094ed025e8a83c136049b6831d44`, mevcut API monitörü ID'si
`239ecb2d05f1f095e5aee4442c7c843c`. İlk görsel kontrolünde görülen %100 oranı
uzun dönem kullanılabilirlik ölçümü değildir. Ücretsiz planın 15 monitör /
4 konum sınırı içinde kalındı.

## Doğrulama ve mobil uyumluluk

- Origin kısıtlaması için 11 izole Caddy/ACME/socket-IP kontrolü başarılı.
- API/apex/www Cloudflare üzerinden 200; aynı hostname+TLS doğrulamasıyla
  direkt origin 403. Diğer VPS siteleri 200.
- Yeni 960 px görsel dönüşümü origin kısıtından sonra **MISS → HIT**:
  WebP, 139.736 byte, iki yanıtta aynı SHA. API health 200; kimliksiz korumalı
  işletme rotası 401 JSON; API cache durumu DYNAMIC.
- Kontrollü auth testi: 30 GET / 3,82 saniye içinde Cloudflare 429 görüldü;
  süre sonrası tekrar origin 404. Gerçek login/OTP/ödeme POST gönderilmedi.
- `/.env`, `/.git/config`, `/wp-login.php` edge 403; health ve görseller 200.
  [Edge test kanıtları](cloudflare-production-2026-09-25-edge.json).
- Mobil auth hata işleyicisi plain-text/HTML edge yanıtlarında Map cast
  yapmayacak şekilde düzeltildi. 429, geçerli sayısal Retry-After varsa
  Türkçe süreli bekleme mesajı veriyor; credential/validation mesajları
  korunuyor. **21 hedefli test geçti; Flutter analyze temiz.** Kaynak kodu
  hazırdır, mağaza yayını yapılmadı.
- `git diff --check` başarılı.

## Kaynaklar

- [Free rate-limit kullanılabilirliği](https://developers.cloudflare.com/waf/rate-limiting-rules/)
- [WAF custom rules](https://developers.cloudflare.com/waf/custom-rules/)
- [Cloudflare DNSSEC](https://developers.cloudflare.com/dns/dnssec/)
- [Ücretsiz bildirim kapsamları](https://developers.cloudflare.com/notifications/notification-available/)
- [Certificate Transparency Monitoring](https://developers.cloudflare.com/ssl/edge-certificates/additional-options/certificate-transparency-monitoring/)
- [Images Free sınırları](https://developers.cloudflare.com/images/pricing/)
- [Google ile açılan Cloudflare hesabına parola ekleme](https://developers.cloudflare.com/fundamentals/user-profiles/login/#social-login)
- [HetrixTools Free planı](https://hetrixtools.com/pricing/uptime-monitor/)
