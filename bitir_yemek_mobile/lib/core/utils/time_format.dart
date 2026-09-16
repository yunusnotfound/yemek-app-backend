/// Backend, alım penceresi saatlerini PostgreSQL TIME kolonundan
/// `HH:MM:SS` biçiminde döndürür (örn. `22:42:00`). Kullanıcıya saniye
/// göstermenin bir anlamı yok; ekranlarda `HH:MM` gösterilir.
///
/// Bu yardımcı, aynı kırpmanın ekranlara tek tek kopyalanmasını önlemek için
/// var: daha önce iki widget'ta özel `_hhmm` kopyaları vardı, dört ekran ise
/// ham değeri basıyordu — yani aynı ekranın iki yeri farklı biçim gösterebiliyordu.
String hhmm(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  // `HH:MM` ve `HH:MM:SS` girdilerinin ikisi de doğru sonuç verir; beklenmeyen
  // bir biçim gelirse değer olduğu gibi bırakılır (bilgi kaybetmemek için).
  return raw.length >= 5 ? raw.substring(0, 5) : raw;
}

/// `HH:MM - HH:MM` biçiminde alım penceresi etiketi.
String pickupWindow(String? start, String? end) => '${hhmm(start)} - ${hhmm(end)}';
