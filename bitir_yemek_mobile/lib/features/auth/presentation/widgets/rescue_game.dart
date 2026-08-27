import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme.dart';

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

class _RescueGameState extends State<RescueGame>
    with TickerProviderStateMixin {
  static const int _hedef = 3;

  static const List<_Food> _foods = [
    _Food(Icons.bakery_dining_rounded, Color(0xFFD98E3E)),
    _Food(Icons.local_pizza_rounded, Color(0xFFE0663D)),
    _Food(Icons.ramen_dining_rounded, Color(0xFFC1443B)),
    _Food(Icons.icecream_rounded, Color(0xFF00897B)),
    _Food(Icons.lunch_dining_rounded, Color(0xFF8D6E63)),
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
      _foodIndex = (_foodIndex + 1 + _random.nextInt(_foods.length - 1)) %
          _foods.length;
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
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: _buildFoodChip(),
        ),
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
        child: Icon(_food.icon, size: 42, color: _food.color),
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
              width: 116,
              height: 116,
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
                          color: AppColors.success
                              .withValues(alpha: (1 - b) * 0.7),
                          width: 3,
                        ),
                      ),
                    ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width: _isOverBag ? 100 : 88,
                    height: _isOverBag ? 100 : 88,
                    decoration: BoxDecoration(
                      color: _isOverBag
                          ? AppColors.success.withValues(alpha: 0.16)
                          : AppColors.primary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isOverBag
                            ? AppColors.success
                            : AppColors.primary.withValues(alpha: 0.35),
                        width: _isOverBag ? 3 : 2,
                      ),
                    ),
                    child: Icon(
                      Icons.shopping_bag_rounded,
                      size: _isOverBag ? 44 : 38,
                      color: _isOverBag ? AppColors.success : AppColors.primary,
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
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.textHint.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.textHint.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 32,
              color: AppColors.textHint,
            ),
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
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.eco_rounded,
          size: 46,
          color: AppColors.success,
        ),
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
  final IconData icon;
  final Color color;
  const _Food(this.icon, this.color);
}
