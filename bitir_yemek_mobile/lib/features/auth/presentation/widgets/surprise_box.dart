import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme.dart';

/// Onboarding'de kullanıcının dokunarak açtığı sürpriz paket.
///
/// Amaç: "sürpriz paket" fikrini ANLATMAK yerine bir kez YAŞATMAK. Kullanıcı
/// kutuya dokunuyor, kapak havalanıyor, içinden rastgele bir ürün ve indirim
/// damgası çıkıyor. Tekrar dokunursa başka bir ürün geliyor — "ne çıkacağını
/// bilmemek" hissi, uygulamanın çekirdek duygusu, daha kayıt olmadan tadılıyor.
///
/// İçerikler TEMSİLİdir (gerçek bir işletme verisi değil); tanıtım amaçlı örnek
/// paketleri gösterir.
class SurpriseBox extends StatefulWidget {
  const SurpriseBox({super.key});

  @override
  State<SurpriseBox> createState() => _SurpriseBoxState();
}

class _SurpriseBoxState extends State<SurpriseBox>
    with TickerProviderStateMixin {
  /// Kutudan çıkabilecek temsili paketler.
  static const List<_SurpriseItem> _items = [
    _SurpriseItem(
      icon: Icons.bakery_dining_rounded,
      color: Color(0xFFD98E3E),
      label: 'Fırın Sepeti',
      discount: 70,
    ),
    _SurpriseItem(
      icon: Icons.local_cafe_rounded,
      color: Color(0xFF8D6E63),
      label: 'Kahve & Kurabiye',
      discount: 60,
    ),
    _SurpriseItem(
      icon: Icons.lunch_dining_rounded,
      color: Color(0xFFE0663D),
      label: 'Öğle Menüsü',
      discount: 50,
    ),
    _SurpriseItem(
      icon: Icons.ramen_dining_rounded,
      color: Color(0xFFC1443B),
      label: 'Sıcak Çorba',
      discount: 65,
    ),
    _SurpriseItem(
      icon: Icons.icecream_rounded,
      color: Color(0xFF00897B),
      label: 'Tatlı Kutusu',
      discount: 55,
    ),
  ];

  /// Kapak + içerik açılış animasyonu.
  late final AnimationController _openController;

  /// Kapalıyken hafif nefes alma — kutunun dokunulabilir olduğunu belli eder.
  late final AnimationController _idleController;

  final math.Random _random = math.Random();

  bool _isOpen = false;
  int _itemIndex = 0;

  _SurpriseItem get _item => _items[_itemIndex];

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _openController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact();

    if (!_isOpen) {
      // İlk dokunuş: rastgele bir ürünle aç.
      setState(() {
        _itemIndex = _random.nextInt(_items.length);
        _isOpen = true;
      });
      _idleController.stop();
      await _openController.forward();
      return;
    }

    // Zaten açık: kutuyu kapat, BAŞKA bir ürün seç, tekrar aç.
    // Aynı ürünün üst üste gelmesi "rastgele" hissini bozduğu için eleniyor.
    await _openController.reverse();
    if (!mounted) return;
    setState(() {
      _itemIndex = (_itemIndex + 1 + _random.nextInt(_items.length - 1)) %
          _items.length;
    });
    await _openController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _isOpen
          ? 'Sürpriz paket açıldı: ${_item.label}. Başka bir paket için dokun.'
          : 'Sürpriz paketi açmak için dokun',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 260,
          height: 240,
          child: AnimatedBuilder(
            animation: Listenable.merge([_openController, _idleController]),
            builder: (context, _) {
              final t = Curves.easeOutCubic.transform(_openController.value);
              // Kapalıyken 3 piksellik salınım; açılınca durur.
              final bob = _isOpen
                  ? 0.0
                  : math.sin(_idleController.value * math.pi) * 3;

              return Stack(
                alignment: Alignment.center,
                children: [
                  _buildGlow(t),
                  _buildRevealedItem(t),
                  _buildBoxBody(bob),
                  _buildLid(t, bob),
                  _buildStamp(t),
                  if (!_isOpen) _buildTapHint(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Açılırken ürünün arkasında beliren yumuşak ışık halesi.
  Widget _buildGlow(double t) {
    if (t == 0) return const SizedBox.shrink();
    return Positioned(
      top: 18,
      child: Opacity(
        opacity: t * 0.30,
        child: Container(
          width: 150 * t,
          height: 150 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [_item.color, _item.color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }

  /// Kutudan yukarı doğru çıkan ürün rozeti.
  Widget _buildRevealedItem(double t) {
    if (t == 0) return const SizedBox.shrink();

    // Yukarı fırlama + elastik ölçek: "fırlayıp yerine oturma" hissi.
    final pop = Curves.elasticOut.transform(t.clamp(0.0, 1.0));

    return Positioned(
      top: 10,
      child: Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 60),
          child: Transform.scale(
            scale: 0.6 + pop * 0.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _item.color.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(_item.icon, size: 46, color: _item.color),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _item.label,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Kutunun ön yüzü — ürün bunun ARKASINDAN çıkıyormuş gibi görünsün diye
  /// Stack'te üründen SONRA çiziliyor.
  Widget _buildBoxBody(double bob) {
    return Positioned(
      bottom: 24,
      child: Transform.translate(
        offset: Offset(0, bob),
        child: Container(
          width: 168,
          height: 104,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD9A066), Color(0xFFBE7F49)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.md),
              top: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            // Karton kutu üzerindeki marka şeridi.
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.eco_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Açılışta yukarı fırlayıp yana devrilen kapak.
  Widget _buildLid(double t, double bob) {
    return Positioned(
      bottom: 118 + t * 74 - bob,
      child: Transform.rotate(
        angle: t * -0.42,
        child: Transform.translate(
          offset: Offset(t * 34, 0),
          child: Container(
            width: 184,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8B583), Color(0xFFD9A066)],
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Sağ üste vurulan indirim damgası — hafif eğik, "mühür" gibi oturur.
  Widget _buildStamp(double t) {
    if (t < 0.35) return const SizedBox.shrink();

    // Damga geç başlar ve büyükten küçüğe inerek "vurulmuş" hissi verir.
    final p = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
    final scale = 1.9 - Curves.easeOutBack.transform(p) * 0.9;

    return Positioned(
      top: 6,
      right: 4,
      child: Opacity(
        opacity: p,
        child: Transform.rotate(
          angle: -0.22,
          child: Transform.scale(
            scale: scale.clamp(0.5, 2.0),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                '-%${_item.discount}',
                style: AppTypography.button.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Kapalıyken alttaki "dokun" ipucu — etkileşimli olduğu anlaşılsın diye.
  Widget _buildTapHint() {
    return Positioned(
      bottom: 0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app_rounded,
            size: 16,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 6),
          Text(
            'Açmak için dokun',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurpriseItem {
  final IconData icon;
  final Color color;
  final String label;
  final int discount;

  const _SurpriseItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.discount,
  });
}
