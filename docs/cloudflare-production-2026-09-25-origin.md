# Bitirgitsin origin erişim kısıtlaması — 25 Eylül 2026

## Canlı sonuç

**13:47 UTC / 16:47 Türkiye saati** itibarıyla Bitirgitsin'in API, apex ve www
hostname'lerinde uygulamaya yalnız Cloudflare kaynak IP'lerinden erişiliyor.
Cloudflare üzerinden HTTPS istekleri `200`; aynı hostname ve geçerli TLS SNI
ile doğrudan `72.60.34.192` adresine gönderilen istekler `403 Forbidden` ve
`Cache-Control: no-store` döndürüyor.

Değişiklik ücretsizdir. Yalnız paylaşılan Caddy yapılandırması güncellendi;
AOP, VPS firewall'ı, backend/web container'ları veya diğer uygulamalar
değiştirilmedi.

## Uygulanan yapılandırma

Canlı dosya `/srv/proxy/Caddyfile`, container `proxy-caddy-1`, Caddy sürümü
**v2.11.4**. Dosya container içinde `/etc/caddy/Caddyfile` konumuna bind mount
ile bağlıdır.

`cloudflare_origin_only` isimli tekrar kullanılabilir Caddy snippet'i eklendi.
Kaynak adres eşleşmesi gerçek socket adresini kullanan **`remote_ip`** ile
yapılır. `CF-Connecting-IP` veya `X-Forwarded-For` başlığı bu kontrolü geçiremez.

```caddyfile
(cloudflare_origin_only) {
    @not_cloudflare not remote_ip <Cloudflare'ın 22 resmi CIDR'i>
    header @not_cloudflare Cache-Control "no-store"
    respond @not_cloudflare "Forbidden" 403
}
```

Tam 15 IPv4 + 7 IPv6 listesi [repo Caddyfile'ında](../proxy/Caddyfile) bulunur.
Dağıtımdan önce liste `https://www.cloudflare.com/ips-v4` ve `ips-v6`
yanıtlarıyla birebir karşılaştırıldı. Snippet yalnız şu iki site bloğuna
import edildi:

- `api.bitirgitsin.com`
- `bitirgitsin.com, www.bitirgitsin.com`

Mevcut `trusted_proxies`, `trusted_proxies_strict`,
`client_ip_headers CF-Connecting-IP X-Forwarded-For` ve upstream'e
`header_up X-Forwarded-For {client_ip}` aktarımı korundu. Böylece Cloudflare
bağlantısına izin verilirken uygulama gerçek ziyaretçi IP'sini görmeye devam
eder.

Loopback, Docker özel ağları veya public bir sağlık yolu için istisna
eklenmedi. Mevcut container kontrolü `127.0.0.1:3000` üzerinden doğrudan
uygulamaya gidiyor; Caddy'yi kullanmıyor ve değişiklikten etkilenmedi.

## ACME ve HTTP davranışı

Caddy'nin otomatik sertifika yönetimi, port 80 dinleyicisi ve HTTPS
yönlendirmeleri korundu. Caddy v2.11.4, aktif HTTP-01 challenge'ı uygulama
rotalarından önce işler. İzin verilen genel bir `/.well-known/*` yolu veya
uygulamaya açılan başka bir istisna oluşturulmadı.

Aynı Caddy image'ı dış ağa kapalı, geçici bir container'da çalıştırıldı.
Fixture'ın kendi geçici storage'ına sentetik bir aktif ACME challenge kaydı
yerleştirildi. **Allowlist'in uygulandığı aynı dinleyicide**:

- Normal yol `403` döndürdü.
- Kayıtlı challenge token'ı yalnız beklenen key authorization gövdesiyle
  `200` döndürdü.
- Kayıtsız challenge token'ı `403` döndürdü.

Ayrıca otomatik port 80 yönlendirmesi `308` olarak doğrulandı; aktif challenge
bu yönlendirmeden önce `200` ile yanıtlandı. Test container'ları ve geçici
dosyaları kaldırıldı. Canlı sertifika storage'ına dokunulmadı ve gereksiz
gerçek sertifika yenileme/CA isteği başlatılmadı. Bu doğrulama routing ve
challenge yanıtı davranışını kanıtlar; gelecekteki CA hizmet erişimini garanti
eden gerçek bir sertifika yenileme denemesi değildir.

## Doğrulama

Önce aday dosya çalışan Caddy sürümünde `adapt --validate` ile doğrulandı.
İzole fixture'larda socket-IP kontrolü, sahte başlıklar, gerçek client IP
aktarımı, diğer site davranışı, aktif/kayıtsız ACME token'ları ve HTTP
yönlendirmeleri için toplam **11 kontrol** geçti.

Canlı dosyanın değişmediği SHA-256 ile tekrar kontrol edildikten sonra yedek
alındı. Bind mount'un inode'u korunarak içerik güncellendi. Ardından canlı
`caddy validate` ve kesintisiz `caddy reload` başarılı oldu.

| Canlı kontrol | Sonuç |
| --- | --- |
| API, apex ve www — Cloudflare edge HTTPS | Her biri `200`, `CF-Cache-Status: DYNAMIC` |
| Aynı üç hostname — doğrudan origin HTTPS | Her biri `403`, `no-store` |
| Doğrudan origin, sahte CF/XFF başlıkları | `403`, `no-store` |
| Public görsel — Cloudflare edge | `200`, `HIT` |
| Aynı görsel — doğrudan origin | `403`, `no-store` |
| Origin HTTP uygulama isteği | Tek `308` yönlendirme sonrası HTTPS `403` |
| Origin HTTP, kayıtsız ACME token'ı | Tek `308` yönlendirme sonrası HTTPS `403` |
| Cloudflare üzerinden HTTP | Tek `301` yönlendirme sonrası HTTPS `200` |
| `ieltsco.com` ve `www.hirdavatgezgini.com` doğrudan origin HTTPS | Her biri `200` |
| Diğer site HTTP yönlendirmesi | `308` → `200` |

HTTPS kontrollerinde sertifika doğrulaması kapatılmadı; `curl --resolve` ile
hostname/SNI korunarak hedef IP seçildi. Örnek edge Ray ID'leri
`a40a7b93bde3b667-IST` (API), `a40a7b96fdbb92cc-IST` (apex),
`a40a7b9adfbcb63b-IST` (www), `a40a7ba15f8db65e-IST` (görsel).

Hedef snippet ve iki import geri çıkarılarak yapılan ters karşılaştırma,
diğer site blokları ve global ayarların önceki dosyayla byte-for-byte aynı
kaldığını doğruladı. `git diff --check` başarılı.

### Origin kısıtından sonra yeni görsel dönüşümü

Son bağımsız kontrol tam **5 GET** ile yapıldı; query eklenmedi, POST
gönderilmedi. Mobil yardımcıyla aynı sabit `960` boyutu ve
`fit=scale-down,format=webp,quality=85,onerror=redirect` seçenekleriyle
`/uploads/demo-catalog-v1/kafe.png` istendi (`Accept: image/webp`).

İlk dönüşüm **`200 MISS`**, tekrar **`200 HIT` / `Age: 0`** döndürdü. İki
yanıtta da `cf-resized`, `Content-Type: image/webp` ve **139.736 byte** vardı;
SHA-256 aynıydı: `147eccfb4abb13bc509748fa5903c60b6c5d6915d9a6de8cd8a4caf6721332f8`.
Ray ID'leri `a40a84e48dddb65e-IST` ve `a40a84e88c76b63f-IST`.
Bu sonuç origin kısıtının yeni Cloudflare görsel dönüşümünü engellemediğini
doğruladı; önceden hazırlanmış dönüşüme HIT alınmasıyla sınırlı kalmadı.

Kalan üç GET'te `/api/health` **200 JSON**, `/api/auth/refresh` **404 JSON**,
kimlik bilgisi olmadan `/api/business-dashboard/my-businesses` **401 JSON**
döndürdü. Üçü de `DYNAMIC`, `Age` başlığı yok. Tüm bağlantılar Cloudflare
edge IP'sine `--resolve` ile, hostname/SNI ve TLS doğrulaması korunarak yapıldı.

## Yedek ve geri dönüş

- Canlı yedek:
  `/srv/proxy/Caddyfile.before-origin-lock-20260925T134700Z`
- Önceki SHA-256:
  `6e7594a2294aa54aa58c7d99e27189a90a31c02c82e102b0838a8b083fc5803c`
- Dağıtılan SHA-256:
  `79d35683e38af637de5de67f40d4a4e853d4ead2c4394b2fcc4ffaef651ad909`

Geri dönüş gerekirse, sonraki Caddy değişikliklerini önce karşılaştırarak:

```sh
cp -p /srv/proxy/Caddyfile.before-origin-lock-20260925T134700Z /srv/proxy/Caddyfile
docker exec proxy-caddy-1 caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
docker exec proxy-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

Dosya bind mount olduğu için `mv` ile inode değiştirilmemelidir. Geri dönüş
origin'e doğrudan uygulama erişimini yeniden açar.

## Sınırlar ve bakım

Bu kontrol Cloudflare ağını doğrular; belirli bir Cloudflare hesabını
doğrulayan özel mTLS/AOP yapılandırması değildir. Paylaşılan VPS IP'si diğer
sitelerden veya eski DNS kayıtlarından bulunabilir; uygulama katmanındaki
bu kısıt VPS'ye yönelen doğrudan ağ saldırısını engellemez.

Cloudflare resmi IP listesi değişirse hem `trusted_proxies` hem
`cloudflare_origin_only` listeleri birlikte güncellenmeli ve doğrulanmalıdır.
DNS'i DNS-only yaparak CDN'i devre dışı bırakmak tek başına erişimi geri
getirmez; bu origin kuralı ayrıca kaldırılmalı veya geri alınmalıdır.

## Kaynaklar

- [Cloudflare resmi IP listesi](https://www.cloudflare.com/ips/)
- [Caddy remote_ip matcher](https://caddyserver.com/docs/caddyfile/matchers#remote-ip)
- [Caddy otomatik HTTPS ve ACME](https://caddyserver.com/docs/automatic-https)
- [Caddy v2.11.4 HTTP sunucusunda challenge önceliği](https://github.com/caddyserver/caddy/blob/v2.11.4/modules/caddyhttp/server.go#L384)
- [CertMagic v0.25.3 HTTP challenge işleyicisi](https://github.com/caddyserver/certmagic/blob/v0.25.3/httphandlers.go#L178)
