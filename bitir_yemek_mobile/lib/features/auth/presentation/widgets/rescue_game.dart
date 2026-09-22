import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme.dart';
import 'onboarding_photo.dart';

/// Onboarding'in son sayfasındaki küçük "kurtar" etkileşimi.
///
/// Ortadaki yemek çöpe gitmek üzere; kullanıcı onu çantaya sürükleyerek
/// kurtarıyor. Uygulamanın yaptığı işin birebir kendisi — anlatılmadan,
/// oynatılarak. Hiçbir veri/istek gerektirmez, tamamen yereldir.
///
/// Oynamak ZORUNLU değildir: "Başlayalım" butonu her zaman aktiftir, bu yalnız
/// isteyenin dokunacağı bir keyif katmanıdır.
class RescueGame extends StatefulWidget {
  /// Hedefe ulaşıldığında (tüm yemekler kurtarıldığında) bir kez çağrılır.
  final VoidCallback? onCompleted;

  const RescueGame({super.key, this.onCompleted});

  @override
  State<RescueGame> createState() => _RescueGameState();
}

class _RescueGameState extends State<RescueGame> with TickerProviderStateMixin {
  static const int _hedef = 3;

  static const List<_Food> _foods = [
    _Food(OnboardingAssets.bakery, Color(0xFFD98E3E)),
    _Food(OnboardingAssets.sandwich, Color(0xFFE0663D)),
    _Food(OnboardingAssets.meal, Color(0xFFC1443B)),
    _Food(OnboardingAssets.dessert, Color(0xFF00897B)),
    _Food(OnboardingAssets.coffee, Color(0xFF8D6E63)),
  ];

  /// Yemeğin havada süzülmesi — sürüklenebilir olduğunu belli eder.
  late final AnimationController _floatController;

  /// Kurtarma anındaki halka patlaması.
  late final AnimationController _burstController;

  final math.Random _random = math.Random();

  int _rescued = 0;
  int _foodIndex = 0;
  bool _isOverBag = false;
  bool _completedNotified = false;

  bool get _isDone => _rescued >= _hedef;
  _Food get _food => _foods[_foodIndex];

  @override
  void initState() {
    super.initState();
    _foodIndex = math.Random().nextInt(_foods.length);
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  void _onRescued() {
    HapticFeedback.mediumImpact();

    setState(() {
      _rescued++;
      _isOverBag = false;
      // Sonraki yemek farklı olsun; aynısının tekrarı oyunu tekdüze yapıyor.
      _foodIndex =
          (_foodIndex + 1 + _random.nextInt(_foods.length - 1)) % _foods.length;
    });

    _burstController.forward(from: 0);

    if (_isDone) {
      _floatController.stop();
      if (!_completedNotified) {
        _completedNotified = true;
        widget.onCompleted?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildProgress(),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: 280,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(right: 0, bottom: 0, child: _buildTrash()),
              Positioned(left: 0, bottom: 0, child: _buildBag()),
              if (!_isDone)
                Positioned(top: 4, child: _buildDraggableFood())
              else
                Positioned(top: 4, child: _buildDoneBadge()),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildHint(),
      ],
    );
  }

  /// Üstteki ilerleme noktaları — kaç yemek kurtarıldığını gösterir.
  Widget _buildProgress() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_hedef, (i) {
        final dolu = i < _rescued;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: dolu ? 26 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: dolu
                ? AppColors.success
                : AppColors.textHint.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
        );
      }),
    );
  }

  Widget _buildDraggableFood() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        final dy = math.sin(_floatController.value * math.pi) * 7;
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: Draggable<bool>(
        data: true,
        feedback: _buildFoodChip(scale: 1.15, elevated: true),
        childWhenDragging: Opacity(opacity: 0.25, child: _buildFoodChip()),
        onDragStarted: () => HapticFeedback.selectionClick(),
        onDraggableCanceled: (velocity, offset) {
          if (mounted) setState(() => _isOverBag = false);
        },
        child: _buildFoodChip(),
      ),
    );
  }

  Widget _buildFoodChip({double scale = 1, bool elevated = false}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _food.color.withValues(alpha: elevated ? 0.38 : 0.22),
              blurRadius: elevated ? 22 : 14,
              offset: Offset(0, elevated ? 10 : 5),
            ),
          ],
        ),
        child: OnboardingPhoto(asset: _food.asset, size: 86),
      ),
    );
  }

  /// Kurtarma hedefi. Yemek üstüne gelince büyüyüp renkleniyor.
  Widget _buildBag() {
    return DragTarget<bool>(
      onWillAcceptWithDetails: (_) {
        if (!_isOverBag) setState(() => _isOverBag = true);
        return true;
      },
      onLeave: (_) {
        if (_isOverBag) setState(() => _isOverBag = false);
      },
      onAcceptWithDetails: (_) => _onRescued(),
      builder: (context, candidate, rejected) {
        return AnimatedBuilder(
          animation: _burstController,
          builder: (context, _) {
            final b = _burstController.value;
            return SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Kurtarma anında dışa açılan halka.
                  if (b > 0 && b < 1)
                    Container(
                      width: 60 + b * 56,
                      height: 60 + b * 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.success.withValues(
                            alpha: (1 - b) * 0.7,
                          ),
                          width: 3,
                        ),
                      ),
                    ),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: _isOverBag ? 1.12 : 1,
                    child: const OnboardingPhoto(
                      asset: OnboardingAssets.bag,
                      size: 126,
                      cutout: true,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Çöp kovası — dekoratif. Yemeğin alternatif kaderini gösterir; sürükleme
  /// hedefi DEĞİLDİR, kullanıcıyı yanlış seçime davet etmenin anlamı yok.
  Widget _buildTrash() {
    return Opacity(
      opacity: _isDone ? 0.25 : 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const OnboardingPhoto(
            asset: OnboardingAssets.bin,
            size: 92,
            cutout: true,
          ),
          const SizedBox(height: 6),
          Text(
            'İsraf',
            style: AppTypography.caption.copyWith(color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  /// Hedefe ulaşınca yemeğin yerini alan kutlama rozeti.
  Widget _buildDoneBadge() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, t, child) =>
          Transform.scale(scale: 0.6 + t * 0.4, child: child),
      child: const OnboardingPhoto(
        asset: OnboardingAssets.openBox,
        size: 104,
        cutout: true,
      ),
    );
  }

  Widget _buildHint() {
    final done = _isDone;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Row(
        key: ValueKey(done),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.swipe_left_rounded,
            size: 16,
            color: done ? AppColors.success : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            done ? '$_hedef yemek kurtardın!' : 'Yemeği çantaya sürükle',
            style: AppTypography.bodySmall.copyWith(
              color: done ? AppColors.success : AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Food {
  final String asset;
  final Color color;
  const _Food(this.asset, this.color);
}
