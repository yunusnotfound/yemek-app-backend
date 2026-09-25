# DNS geçişi — kısa bağımsız teşhis

**DNSSEC son durum — 14:31:07 UTC / 17:31:07 Türkiye saati:** Parent DS ve
Cloudflare DNSKEY eşleşmesi doğrulandı; üç recursive resolver'ın UDP/TCP
yanıtları ve Cloudflare DoH yanıtlarında **14/14 `AD=true`** alındı.
DNSSEC zinciri artık aktif ve doğrulanıyor; önceki `pending` notları tarihsel.

**Güncel sonuç — 14:00:31 UTC / 17:00:31 Türkiye saati:** Resmi resolver cache
yenileme isteklerinden sonraki tek batch'te **28 sorgunun tamamı doğru**
Cloudflare NS/A yanıtlarını verdi. Bu örneklerde parking IP'si, eski NS veya
NXDOMAIN kalmadı. Ayrıntılar son bölümde; aşağıdaki ilk bulgular tarihsel
geçiş gözlemleridir.

**İlk kayıt zamanı:** 25 Eylül 2026, 13:57:58 UTC / 16:57:58 Türkiye saati.
İlk kontroller aynı kısa zaman aralığında, salt okunur yapıldı. O aşamada
nameserver, Cloudflare, origin erişim kısıtı veya DNS cache ayarı değiştirilmedi.

## Gözlenen yanıtlar

| Kaynak / taşıma | Sorgu | Sonuç | Yanıttaki TTL |
| --- | --- | --- | --- |
| Yerel istemci → `1.1.1.1`, UDP | apex A | Eski provider parking IP'si `93.89.226.17` | 3550 sn |
| Yerel istemci → `1.1.1.1`, TCP | apex A | Cloudflare `104.21.22.6`, `172.67.201.174` | 300 sn |
| Yerel istemci → `https://1.1.1.1/dns-query`, DoH | apex A | Aynı doğru Cloudflare IP'leri | 300 sn |
| Yetkili `amanda.ns.cloudflare.com` | apex A | Aynı doğru Cloudflare IP'leri, authoritative yanıt | 300 sn |
| Yerel istemci → `1.1.1.1`, UDP/TCP/DoH | apex NS | Eski `tr/eu/us.dnsenable.com` kayıtları | 3600 sn |
| Yerel istemci → `1.0.0.1`, UDP | apex A | Doğru Cloudflare IP'leri | 258 sn |
| VPS → `1.1.1.1`, UDP | apex A | Doğru Cloudflare IP'leri | 300 sn |
| Son yerel örnek → `1.1.1.1`, UDP | API A | `NXDOMAIN`; eski dnsenable SOA'sı, serial `2026092506` | Negatif cache: 300 sn |

DoH bağlantısı `curl` ile HTTPS üzerinden, TLS sertifika doğrulaması açık
olarak yapıldı; `-k` kullanılmadı. Sorgu yanıtı ve eski NS kayıtları aynı
güvenli kanaldan görüldü. API'nin önceki örneklerde doğru Cloudflare IP'si
döndürmüş olması son NXDOMAIN gözlemini geçersiz kılmaz: farklı kayıtların,
cache düğümlerinin veya giriş yollarının geçiş durumu aynı olmayabilir.

## Değerlendirme

Yeni Cloudflare yetkili zone'u doğru cevaplıyor. Ana kurulum sırasında
registry/parent delegasyonu AMANDA/PHIL olarak doğrulandı. Buna karşın bazı
recursive yanıtlar hâlâ eski NS kayıtlarını ve nameserver değişiminden sonra
eski provider'da kalan parking/boş zone'u kullanıyor. Bulgular, aynı gün
yapılan nameserver geçişinin resolver cache'lerine tutarsız yansımasıyla
uyumludur.

İlk UDP/TCP A farkı ağda UDP DNS interception ihtimalini de düşündürür;
**interception kanıtlanmış değildir**. NS kayıtlarının TLS doğrulamalı DoH'da
da eski çıkması, durumu yalnız UDP müdahalesiyle açıklamayı engeller.

3550/3600 saniyelik kayıtlar gözlem anında yaklaşık bir saatlik, negatif API
yanıtı beş dakikalık cache ömrü gösteriyor. Bunlar tüm dünya için kesin bir
bitiş zamanı değildir; delegation ve kayıt cache'leri ayrı yenilenebilir.
Bu süreçte bazı istemciler web sitesini parking IP'sine yönlendirebilir veya
API için NXDOMAIN görebilir. Dolayısıyla global DNS erişiminin tamamen
oturduğu henüz söylenmemelidir. Cloudflare edge'e doğrudan hostname/SNI ile
yapılan başarılı kontroller bu resolver farkını ortadan kaldırmaz.

## İlk karar — 13:57:58 UTC, purge öncesi

Resmi [1.1.1.1 DNS Purge Cache aracı](https://one.one.one.one/purge-cache/)
alan adı ve kayıt türü seçerek resolver cache yenilemeye izin veriyor;
[Cloudflare FAQ](https://developers.cloudflare.com/1.1.1.1/faq/#what-is-purge-cache)
bu aracı doğruluyor. Bu araç CDN içerik cache temizliğinden ayrıdır.
**13:57:58 UTC'deki ilk kayıt sırasında purge uygulanmamıştı.** O aşamada ana
çalışmadaki karar doğrultusunda DNS ayarları ve origin kısıtı korunarak geçiş
cache'lerinin yenilenmesi bekleniyordu. Sonraki hedefli resolver cache işlemi
aşağıda ayrıca kayıtlıdır.

Ana çalışmanın bu andaki DNSSEC durumu: Cloudflare imzalaması hazırlanmış,
parent DS kaydı henüz yok ve Cloudflare `pending`; İsimtescil destek kaydı
**2316681** gönderilmiş durumda. Bu alt incelemede DS yeniden sorgulanmadı
ve yayınlanmadı. Gözlenen parking/NXDOMAIN durumu eski zone cache'leriyle
ilişkilidir; yapılan sorgularda DNSSEC doğrulama hatası olan `SERVFAIL`
görülmedi. DS yayınlama süreci cache geçişinden ayrı izlenmelidir.

## Resolver cache yenilemesi sonrası — 14:00:31 UTC

İlk incelemeden sonra ana çalışma kapsamında resmi
`https://one.one.one.one/purge-cache/` arayüzünden şu kayıtlar için yenileme
istekleri gönderildi:

- `bitirgitsin.com` NS
- `bitirgitsin.com` A
- `api.bitirgitsin.com` A
- `www.bitirgitsin.com` A

NS ve apex A için arayüzde `Sending` → `queued` geçişi görüldü; API/www
isteklerinde de queued mesajı kaldı ve hata görülmedi. Bu işlem yalnız
recursive resolver cache'ini hedefler; authoritative zone kayıtları,
nameserver delegasyonu veya origin güvenlik ayarları değiştirilmedi.
Bağımsız kontrolü yapan alt çalışma purge uygulamadı.

**14:00:31 UTC'de** üç resolver için UDP/TCP ve Cloudflare için TLS
doğrulamalı DoH sorguları tek paralel batch halinde tekrarlandı. Her taşıma
için apex NS ile apex/API/www A sorgulandı: **28/28 `NOERROR` ve beklenen
Cloudflare değerleri**.

| Resolver / taşıma | Apex NS TTL | Apex A TTL | API A TTL | www A TTL | Dört sorgu |
| --- | ---: | ---: | ---: | ---: | --- |
| `1.1.1.1` UDP | 86400 | 300 | 300 | 300 | Doğru |
| `1.1.1.1` TCP | 86400 | 300 | 300 | 300 | Doğru |
| `1.1.1.1` DoH | 86400 | 300 | 300 | 300 | Doğru |
| `8.8.8.8` UDP | 21600 | 300 | 300 | 300 | Doğru |
| `8.8.8.8` TCP | 21600 | 300 | 300 | 300 | Doğru |
| `9.9.9.9` UDP | 41220 | 26 | 300 | 300 | Doğru |
| `9.9.9.9` TCP | 41220 | 300 | 300 | 300 | Doğru |

TTL değerleri saniyedir. Beklenen NS seti `amanda.ns.cloudflare.com` /
`phil.ns.cloudflare.com`, A seti `104.21.22.6` / `172.67.201.174` idi.
Bu batch'te eski dnsenable NS, parking IP'si, NXDOMAIN veya SERVFAIL görülmedi.
Önceki tutarsızlık test edilen resolver/giriş yollarında düzelmiş durumda;
bu örnekleme her ISP'nin ve son cihazın yerel cache'inin aynı anda yenilendiği
anlamına gelmez. DNSSEC parent DS durumu bu batch'in kapsamına alınmadı.

## DNSSEC yayını doğrulandı — 14:31:07 UTC

İsimtescil destek kaydı **2316681**, ana çalışma tarafından panelde
`Cevaplandı` olarak okundu. Destek yanıtı işlemin yapıldığını ve yansımasının
birkaç saat sürebileceğini belirtiyordu. Bunun ardından salt okunur public
DNS kontrolleri yapıldı; herhangi bir DNS ayarı veya cache purge işlemi
uygulanmadı.

**25 Eylül 2026, 14:31:07 UTC** kontrolünde `.com` parent yetkilisi
`a.gtld-servers.net`, `NOERROR` ve authoritative yanıtla şu DS kaydını verdi
(TTL **86400 saniye**):

```text
bitirgitsin.com. IN DS 2371 13 2 1FFDEDDE911AFA2868F33C2D96C430C4EA64102DEC1DEE8A526E0ACBCE8B4606
```

Key tag **2371**, algoritma **13**, digest türü **2** ve digest'in tamamı
beklenen Cloudflare DS değeriyle birebir eşleşiyor. `dig` çıktısının uzun
digest'i boşlukla bölmesi karşılaştırmadan önce birleştirildi.

`amanda.ns.cloudflare.com` üzerinde:

- DNSKEY RRset'i ve onu imzalayan RRSIG mevcut.
- KSK DNSKEY: flags **257**, protocol **3**, algorithm **13**, hesaplanan
  key tag **2371**.
- Alan adının canonical wire biçimi ile DNSKEY RDATA üzerinden SHA-256 DS
  digest'i bağımsız yeniden hesaplandı; parent DS digest'iyle birebir aynı.
- Apex A RRset'i `104.21.22.6` / `172.67.201.174` ve A için RRSIG mevcut.

Recursive doğrulama sonucu:

| Resolver / taşıma | Apex A | API A | Durum |
| --- | --- | --- | --- |
| `1.1.1.1` UDP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| `1.1.1.1` TCP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| `8.8.8.8` UDP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| `8.8.8.8` TCP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| `9.9.9.9` UDP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| `9.9.9.9` TCP | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |
| Cloudflare DoH | `AD=true` | `AD=true` | İkisi de `NOERROR`, doğru Cloudflare IP'leri |

UDP/TCP sorguları `+dnssec` ile yapıldı. DoH sorguları
`https://1.1.1.1/dns-query?...&do=true&cd=false` üzerinden, TLS sertifika
doğrulaması açık olarak yapıldı; DNSSEC doğrulaması devre dışı bırakılmadı.
Toplam **14/14 recursive yanıt authenticated data (`AD`)** bayrağı içeriyordu.
NXDOMAIN, SERVFAIL veya önceki UDP/TCP tutarsızlığı görülmedi.

**Sonuç:** Parent DS yayında, Cloudflare imza anahtarıyla eşleşiyor ve
kontrol edilen resolver'lar apex/API kayıtlarını DNSSEC ile doğruluyor.
Bu, yalnız paneldeki imzalama seçeneğinin açık olması değil, public DNS
güven zincirinin çalıştığının doğrulamasıdır. Önceki DS bekleme durumu bu
kontrol itibarıyla kapanmıştır.
