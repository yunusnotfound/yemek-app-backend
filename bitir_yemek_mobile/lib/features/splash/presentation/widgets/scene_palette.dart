import 'package:flutter/material.dart';

/// Açılış sahnesinin renk paleti.
///
/// Tek bir palet vardır: saate göre değişen sabah/öğle/akşam/gece varyantları
/// kaldırıldı. Gerekçe — açılış ekranı markanın ilk izlenimidir ve her açılışta
/// aynı görünmesi kimliği güçlendirir; ayrıca dört ayrı palet, hepsini birden
/// yüksek kalitede tutmayı zorlaştırıyordu.
///
/// Ton seçimi: sıcak fildişinden yumuşak kum rengine inen çok düşük doygunluklu
/// bir zemin. Tek doygun öge marka logosudur; böylece göz doğrudan ona gider.
/// Zemin ayrıca uygulamanın krem arka planına (AppColors.background) yakın
/// olduğu için açılıştan uygulamaya geçiş sıçramasız olur.
class ScenePalette {
  /// Zemin gradyanı (üst → alt).
  final Color skyTop;
  final Color skyBottom;

  /// Merkezden yayılan sıcak hale.
  final Color halo;

  /// Zeminde süzülen üç ışık lekesinin renkleri (açıktan koyuya).
  final Color tintWarm;
  final Color tintMid;
  final Color tintDeep;

  /// Vurgu rengi — halkalar ve ilerleme çizgisi.
  final Color accent;

  /// Metin renkleri.
  final Color ink;
  final Color inkSoft;

  /// Durum çubuğu ikonlarının bu zemin üstünde okunur kaldığı parlaklık.
  final Brightness statusIcons;

  /// Sahnede beliren slogan.
  final String tagline;

  const ScenePalette._({
    required this.skyTop,
    required this.skyBottom,
    required this.halo,
    required this.tintWarm,
    required this.tintMid,
    required this.tintDeep,
    required this.accent,
    required this.ink,
    required this.inkSoft,
    required this.statusIcons,
    required this.tagline,
  });

  /// Uygulamanın tek açılış paleti.
  static const ScenePalette brand = ScenePalette._(
    // Sıcak fildişi → yumuşak kum. Doygunluk bilerek düşük: zemin geri çekilir,
    // logo öne çıkar.
    skyTop: Color(0xFFFFFCF8),
    skyBottom: Color(0xFFF2E2D3),
    halo: Color(0xFFFFD8BC),
    tintWarm: Color(0xFFFFEEE0),
    tintMid: Color(0xFFFBD9C2),
    tintDeep: Color(0xFFEFC1A2),
    accent: Color(0xFFFF7043),
    // Saf siyah yerine derin sıcak kahve: krem zeminde daha yumuşak oturur.
    ink: Color(0xFF2E2019),
    inkSoft: Color(0xFF8A7263),
    statusIcons: Brightness.dark,
    tagline: 'Gün bitiyor, yemek bitmesin.',
  );
}
