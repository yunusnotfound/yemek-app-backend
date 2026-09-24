# TV yönetim dashboardı

`/admin/tv`, yönetici hesabıyla açılan tam ekran teknik operasyon ekranıdır.
Teknik özet, veri/kuyruklar, yazılım/tanılama ve satış/iş özeti olmak üzere dört
ekran 25 saniyede bir otomatik döner; düzen 1366 × 768 TV için ayarlanmıştır.
Kumandayla duraklatma, ekran değiştirme ve tam ekran kullanılabilir. Ölçümler
20 saniyede bir yenilenir; istekler üst üste binmez. Teknik ölçümler gerçek VPS
üzerinden alınır. Eksik kaynaklar sıfır/sağlıklı sayılmaz, eski veriler işaretlenir.

İşletme/satış özeti dördüncü ekrandadır; **İş metrikleri** bağlantısıyla
(`/admin/tv?view=business`) ayrı da açılabilir.
Yönetici menüsündeki **TV Dashboard** bağlantısından da erişilir. Ödeme özeti
ve son siparişler mevcut API'den 30 saniyede bir alınır. İstekler üst üste
binmez; bağlantı hatasında son başarılı veriler ve güncellik bilgisi korunur.
Müşteri adı, e-posta, telefon ve teslim kodu TV ekranında gösterilmez.

## Aynı ağda çalıştırma

Bilgisayarın yerel IP adresini öğrenin (`ipconfig getifaddr en0`, macOS Wi-Fi).
Aşağıdaki `192.168.1.236` adresini kendi bilgisayarınızın adresiyle değiştirin:

```sh
cd web
npm ci
BACKEND_API_URL=https://api.bitirgitsin.com/api \
  WEB_ORIGIN= DEV_ALLOWED_ORIGINS=192.168.1.236 npm run dev:tv
```

Teknik kaynak ölçümleri için sunucu tarafındaki `web/.env.local` dosyasında
`OPS_SSH_HOST`, `OPS_SSH_USER`, `OPS_SSH_KEY` (mutlak özel anahtar yolu) ve
isteğe bağlı `OPS_SSH_PORT` tanımlanmalıdır. Anahtar repo dışında tutulur.
Bağlantı mevcut `known_hosts` kaydını doğrular; `ssh`, uzak sunucuda Python 3
ve Docker okuma erişimi gerekir. Toplayıcı sunucuya dosya kurmaz; sabit Python
betiğini SSH stdin üzerinden çalıştırır. VPS/repo/konteyner hedefleri betikte
Bitir Gitsin kurulumu için sabittir. İstek parametrelerinden komut üretilmez.

`GET /api/admin/operations` her istekte canlı backend üzerinden yönetici rolünü
doğrular; ardından 15 saniyelik paylaşılan ölçüm önbelleğini kullanır. Yanıtlar
`private, no-store` olur. SSH bağlantısı tarayıcıya açılmaz. Kalıcı web yayını
için aynı sunucu tarafı ölçüm erişimi ayrıca yapılandırılmalıdır; mevcut web
Docker imajı SSH istemcisi/anahtar içermez.

TV'nin tarayıcısında `http://192.168.1.236:3001/admin/tv` adresini açın.
Yönetici hesabıyla giriş yapın ve **Tam ekran** düğmesine basın. Tarayıcı bu
özelliği sunmuyorsa kendi tam ekran seçeneğini kullanın. Adresi favorilere
ekleyebilirsiniz. Android TV'de tarayıcı yüklü değilse TV'nin uygulama
mağazasından kumandayla kullanılabilen bir tarayıcı gerekir.

Bilgisayar açık, sunucu çalışır ve TV ile aynı yerel ağda kalmalıdır. Misafir
ağı/istemci yalıtımı ya da macOS güvenlik duvarı bağlantıyı engelleyebilir.
IP adresi değişirse TV'deki adresi ve `DEV_ALLOWED_ORIGINS` ayarını güncelleyin.
MAC adresi tarayıcıya yazılan adres değildir; cihazı ağda tanımaya yarar.

Bu komut mevcut canlı backend'i kullanır; yerel veritabanı başlatmaz. Başka bir
backend istiyorsanız `BACKEND_API_URL` değerini değiştirin. Geliştirme modu
yerel HTTP oturumu içindir. Kalıcı kullanımda web uygulamasını normal HTTPS
alan adında yayınlayıp `/admin/tv` adresini kullanın: production oturum
çerezleri `Secure` olduğundan HTTP üzerinden `npm start` ile giriş çalışmaz.

## Metriklerin anlamı

- CPU/RAM/swap/disk ve host ağ sayaçları diğer uygulamaların da bulunduğu
  paylaşılan VPS'ye aittir. Konteyner tablosu yalnız Bitir app/web/db/redis'tir.
  Konteyner CPU'sunda %100 bir çekirdektir; host CPU tüm çekirdeklere oranlıdır.
  Konteyner RAM'i Docker stats ölçümüdür; açık limit yoksa ayrı belirtilir.
- HTTP kontrolleri VPS'den yapılan tekil sentetik HTTPS istekleridir. Kullanıcı
  gecikmesi ya da kesintisizlik yüzdesi değildir. TLS API sertifikasına aittir.
- API trafiği süreç belleğinde son 15 dakika / en fazla 10.000 tamamlanan
  istektir; restart ile sıfırlanır. P50/P95 bu örneklerden, hata oranı 5xx/tüm
  örneklerden hesaplanır. Düşük trafikte veri yoksa gecikme `—` gösterilir.
  Kapasite dolarsa pencere kısalır ve düşen örnek sayısı gösterilir.
  Sağlık/TV yönetim okumaları hariçtir. İşaretli profil kontrolü yalnız
  doğrulanmış yöneticinin başarılı isteğinde hariç tutulur. İptal 499 sayılır.
  API sayaçları mobil/web/SSR çağrılarını birlikte içerir; tekil kullanıcı
  sayısı değildir. Web ana sayfa kontrolünün tetiklediği SSR API okumaları da
  bu trafiğe dahildir.
  Event loop P95 süreçte ölçüm başlangıcından beridir; istek penceresinden ayrıdır.
- PostgreSQL sayaçları istatistik sıfırlanmasından beri birikir; tablo satır
  sayıları yaklaşık değerlerdir. Ölçüm bağlantısı aktif sorgulardan hariçtir.
  DB kontrol süresi Docker/psql başlatmayı, Redis süresi bağlantı+INFO'yu içerir.
- Redis isabet/eviction/bağlantı ve ağ sayaçları kümülatiftir. Entegrasyon
  işaretleri yapılandırma varlığını gösterir; sağlayıcıda başarılı işlem kanıtı
  değildir. Sandbox ödeme modu açıkça uyarılır.
- Log özeti son 15 dakikada en fazla 2.000 satırdaki yapılandırılmış Winston
  error/warn kayıtlarını sayar; ham mesaj, stack trace veya kişisel veri vermez.
- Yedek bilgisi yerel `.sql.gz` dosyasının yaş/boyut bilgisidir; geri yükleme
  veya sunucu dışı kopya doğrulaması değildir. Kaynak kod SHA'sı sunucudaki
  checkout'tur; çalışan imajın sürümünü kanıtlamaz. İmaj ID'si ayrıca gösterilir.
- Ödeme/iade bekleyenleri veritabanındaki durum sayılarıdır; cron işinin son
  başarılı çalışması değildir. Mobil çökme/ANR geçmişi, uzun dönem SLA ve
  sağlayıcı teslim raporları bu ölçümün kapsamında henüz bulunmaz.

## İş özetindeki metrikler

- Bugünkü sipariş ve tahsilat: mevcut API'nin bugün oluşturulmuş ve ödeme
  durumu `paid` olan siparişleri. Gün sınırı backend sunucusunun saat dilimine
  bağlıdır; TV saati Türkiye saatini gösterir.
- GMV ve komisyon: mevcut API'nin `paid` sipariş toplamları; muhasebe kârı veya
  iadeler düşülmüş net gelir değildir. İadeler ayrıca gösterilir.
- Bekletilen/onaylanan işletme hakedişleri: ödeme mutabakatındaki tutar ve
  sipariş sayılarıdır; banka hesabına ulaşmış ödeme anlamına gelmez.
- Son siparişler: oluşturulma zamanına göre en yeni kayıtlar; ödeme ve sipariş
  durumları ayrıdır. Bu liste tüm platformun günlük dağılımı değildir.
- Aktif işletme ve toplam paket sayıları mevcut API tanımlarıdır; toplam paket
  sayısı o an satın alınabilir stok anlamına gelmez.

TV görünümü yalnız görüntüleme amaçlıdır, fakat kullanılan oturum normal
yönetici oturumudur. Ayrı cihaz eşleştirme veya TV'ye özel kısıtlı rol yoktur.
