# Fiziksel telefonda performans testi

Bu test gerçek Keşfet, paket listesi ve kupon widget'larını profil modunda çalıştırır. 80 paket, 100 kupon ve telefonun `127.0.0.1` adresinde 150 ms gecikmeli görseller kullanır. Canlı hesap, ödeme veya üretim API'si kullanılmaz. Kare oluşturma/çizim süreleri ve bellek ölçülür; gerçek internet, native Mapbox, GPS ve uygulama sürecinin soğuk açılışı bu ölçümün kapsamında değildir.

Gerekli araçlar: Flutter, Python 3.9+, rsync ve platform araç zinciri. iOS için Xcode'da cihazı imzalayabilen bir takım; Android için SDK ve USB hata ayıklama gerekir. Projenin mevcut alt sınırları iOS 15.6 ve Android 7.0 / API 24'tür. iPhone 11 veya Android sonuçları o fiziksel cihazda alınmalıdır; daha yeni iPhone sonuçları bunların yerine geçmez.

`bitir_yemek_mobile` dizininden:

```bash
flutter devices

PERF_OUTPUT_DIR="$PWD/../output/phone-performance" \
  bash tool/profile_phone.sh ios EXACT_DEVICE_ID iphone11-usb-01

PERF_OUTPUT_DIR="$PWD/../output/phone-performance" \
  bash tool/profile_phone.sh android EXACT_DEVICE_ID android-usb-01
```

`EXACT_DEVICE_ID` yerine `flutter devices` çıktısındaki tam kimliği yaz. Script platformun eşleştiğini ve cihazın emülatör olmadığını kontrol eder. Telefonun kilidini açık tut; ilk bağlantıda bilgisayara güven ve gerekli geliştirme izinlerini ver. iOS'ta test uygulamasının yerel ağ iznine izin ver. Kablosuz iPhone 16 Pro denemesinde VM service keşfi takıldı; ölçüm için USB bağlantısı kullanmak daha güvenilir.

Script güncel çalışma dizinini `mktemp` ile ayrı bir staging dizinine kopyalar. `build`, `.dart_tool`, `Pods`, `.symlinks`, `.gradle`, `.git` ve eski Flutter üretim dosyaları kopyalanmaz. Asıl uygulamanın paket kimliği, imzası, izinleri ve kaynakları değiştirilmez. Telefona kurulacak ayrı test uygulaması:

- iOS: `com.bitiryemek.performance`, görünen ad **Bitir Performans**. Yalnız staging'de boş entitlement, yerel ağ izni ve Dart VM service duyurusu kullanılır.
- Android: mevcut `applicationId` sonuna `.performance` eklenir. Yalnız staging'in profile kaynağında `127.0.0.1` için HTTP istisnası vardır; diğer adresler için cleartext kapalı kalır.

Varsayılan iOS takımı bu Mac'te mevcut değilse yalnız staging'e uygulanacak takım kimliği verilebilir:

```bash
PERF_IOS_TEAM=YOURTEAMID \
  bash tool/profile_phone.sh ios EXACT_DEVICE_ID iphone11-usb-02
```

`YOURTEAMID` Xcode hesabındaki 10 karakterlik takım kimliğidir; kişisel bir takım script içinde sabitlenmemiştir.

Sonuçlar varsayılan olarak `../output/phone-performance` altında tutulur. `<run>-preparation.json` kaynak parmak izini ve staging yolunu; `<run>-drive.log` koşum çıktısını; `<run>.json` tamamlanan testin ölçümlerini içerir. Tamamlanmayan testin logunu başarılı ölçüm sayma. Süreleri ve 16,67 ms / 8,33 ms kare bütçesini cihazın ekran yenileme hızına göre değerlendir. Aynı cihazda birkaç ayrı koşum adıyla tekrar et.

Başarıda staging temizlenir. Hata durumunda inceleme için korunur; başarılı koşumda da saklamak için `PERF_KEEP_STAGE=1` ver. Scripti telefona bağlanmadan incelemek için:

```bash
bash tool/profile_phone.sh ios PREPARE_ONLY_ID inspect-ios --prepare-only
```

Bu seçenek yalnız geçici kopyayı hazırlar; Flutter çağırmaz, telefona erişmez. Yerel fixture doğrulaması da telefon kullanmaz:

```bash
bash -n tool/profile_phone.sh
python3 tool/test_profile_phone.py
```

## Mevcut iOS profil uygulamasıyla yeniden deneme

Bu ortamda bir Xcode koşumu `TARGET_BUILD_DIR` eksikliği bildirirken staging'deki `build/ios/Profile-iphoneos/Runner.app` imzalı olarak oluştu. Aynı kaynakların profil testini içeren geçerli `.app` elindeyse yeniden derlemeyi atlayabilirsin:

```bash
bash tool/profile_phone.sh ios EXACT_DEVICE_ID iphone-usb-retry \
  --use-application-binary /absolute/retained-stage/build/ios/Profile-iphoneos/Runner.app
```

Script `.app` içindeki bundle kimliğinin `com.bitiryemek.performance` olduğunu doğrular. Uygulama güncel `phone_performance_test.dart` ile **profil modunda** derlenmiş olmalıdır. Bu seçenek imza veya yerel ağ/VM service keşfi sorunlarını kendiliğinden çözmez. Kaynak ya da test değiştiyse yeni profil uygulaması derle.

## VM service keşfi takılırsa iOS konsolundan ölçüm

İmzalı profil test uygulaması telefonda çalışıyor, fakat `flutter drive` kablosuz VM service bağlantısını kuramıyorsa aynı testi doğrudan başlatıp konsol sonucunu alabilirsin. Bu yol iPhone 16 Pro üzerinde doğrulandı. Aşağıdaki yolları saklanan staging ve yeni koşum loguna göre düzenle; kullanılan uygulama ayrı **Bitir Performans** uygulamasıdır.

```bash
profile_stage=/absolute/retained-stage
profile_device=EXACT_DEVICE_ID
profile_log="$PWD/../output/phone-performance/iphone-console-01.log"
mkdir -p "$(dirname "$profile_log")"

# Üretim uygulamasını yanlışlıkla kurmayı önlemek için bundle ID'yi doğrula.
python3 - "$profile_stage/build/ios/Profile-iphoneos/Runner.app/Info.plist" <<'PY'
import plistlib, sys
with open(sys.argv[1], 'rb') as stream:
    info = plistlib.load(stream)
if info.get('CFBundleIdentifier') != 'com.bitiryemek.performance':
    raise SystemExit('Bu dosya ayrı performans uygulaması değil.')
PY
```

Kimlik kontrolü başarılı olduktan sonra:

```bash
xcrun devicectl device install app --device "$profile_device" \
  "$profile_stage/build/ios/Profile-iphoneos/Runner.app" && \
xcrun devicectl device process launch --device "$profile_device" \
  --terminate-existing --console \
  --environment-variables '{"OS_ACTIVITY_DT_MODE":"enable"}' \
  com.bitiryemek.performance --enable-dart-profiling \
  2>&1 | tee "$profile_log"
```

`OS_ACTIVITY_DT_MODE=enable` bu ortamda Flutter konsol satırlarının görünmesi için gereklidir. `--enable-dart-profiling` bir debug derlemesini profil derlemesine dönüştürmez; `.app` önceden `--profile` ile hazırlanmış olmalıdır. Konsolda sonuç satırları ve `All tests passed!` tamamlanana kadar bekle. Konsol bağlı kalırsa ardından Ctrl+C ile bağlantıyı kapat; farklı koşumları aynı loga ekleme.

Sonucu doğrulayıp birleştir:

```bash
python3 tool/collect_phone_results.py "$profile_log" \
  --output "$PWD/../output/phone-performance/iphone-console-01.json"
```

Her `PHONE_PERFORMANCE_RESULT` satırı JSON'un bir bölümünü içerir. Yardımcı bunları birleştirir; `complete=true`, `environment.profileMode=true` ve `All tests passed!` bulunmasını zorunlu tutar. Test hatası, kesilmiş JSON veya karışmış koşum varsa başarısız çıkar ve sonuç dosyası oluşturmaz. Önceden var olan sonuç dosyasını da değiştirmez. Başarısız bir koşumun kısmi sürelerini başarılı performans ölçümü olarak kullanma.
