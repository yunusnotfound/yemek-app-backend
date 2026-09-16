# Uygulama doğrulama raporları

- [Güncel performans düzeltmeleri ve fiziksel iPhone sonuçları](performance-fixes-2026-09-08/REPORT.md)
- [Düzeltmelerden önceki tarihsel inceleme](performance-2026-09-08/REPORT.md)

Raporların yanında ölçüm JSON'ları, ilgili doğrulama logları ve tekrar çalıştırma betikleri bulunur. Yayımlanan kopyalarda yerel kullanıcı/geçici çalışma yolları genelleştirildi ve geçici Dart VM bağlantı adresleri loglardan çıkarıldı; ölçüm değerleri değiştirilmedi. İlk rapordaki kod satırları inceleme zamanına aittir; güncel dosyalar düzeltmeleri içerir.

Betikler mevcut checkout'un kodunu test eder. Bugünkü kodla yeniden çalıştırmak, düzeltme öncesindeki tarihsel sonucu yeniden üretmez. Betikler aynı klasördeki sonuç dosyalarını yeniler; karşılaştırma kanıtlarını korumak için ayrı checkout kullanın. Üretim ortamına bağlamayın; yalnız ayrı yerel PostgreSQL/Redis servisleri kullanın.
