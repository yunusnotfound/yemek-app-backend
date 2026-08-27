import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';

/// Diyalogun duygusu: geri alınamaz/yıkıcı bir işlem mi, yoksa marka tonunda
/// sıradan bir onay mı.
enum AppDialogTone { danger, brand }

/// Uygulamanın onay/bilgi diyalogu — Material `AlertDialog`'un yerini alır.
///
/// Neden `AlertDialog` değil: sola dayalı gri başlık, düz beyaz kutu ve sağ alt
/// köşeye sıkışmış iki metin düğmesi tam bir Android sistem uyarısı görüntüsü
/// veriyordu. Marka dili sıcak krem zemin, mercan vurgu ve yuvarlak formlar
/// üzerine kurulu; onay anı da uygulamanın geri kalanı gibi görünmeli.
///
/// Bu yüzey: krem gradyan panel, tepede tondan beslenen bir madalyon, ardında
/// açılış sahnesinden tanıdık ışık lekesi ve halkalar, altta yan yana iki tam
/// genişlikte düğme (vazgeç = hayalet, onay = dolu).
class AppDialog {
  AppDialog._();

  /// Onay ister; kullanıcı onayladıysa `true` döner.
  ///
  /// Bariyere dokunmak ya da geri tuşu `false` döndürür — yıkıcı işlemlerde
  /// kazara onay olmaz.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
    IconData icon = Icons.help_outline_rounded,
    AppDialogTone tone = AppDialogTone.danger,
  }) async {
    final result = await show<bool>(
      context,
      builder: (dialogContext) => _DialogPanel(
        icon: icon,
        tone: tone,
        title: title,
        message: message,
        actions: [
          _DialogButton(
            label: cancelLabel,
            filled: false,
            tone: tone,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          _DialogButton(
            label: confirmLabel,
            filled: true,
            tone: tone,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Panel kabuğunu istediğin içerikle açar (ör. "Hakkında" kartı).
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool dismissible = true,
  }) {
    HapticFeedback.mediumImpact();

    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      // Soğuk siyah perde krem zemini griye çeviriyor; perde de sıcak.
      barrierColor: AppColors.ink.withValues(alpha: 0.46),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (dialogContext, _, _) => builder(dialogContext),
      transitionBuilder: (context, animation, _, child) {
        final t = animation.value.clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.scale(
            // Hafif bir "yaylanarak oturma": panel ekrana konur, açılmaz.
            scale: 0.88 + 0.12 * Curves.easeOutBack.transform(t),
            child: child,
          ),
        );
      },
    );
  }
}

/// Tona göre renkler. Yıkıcı işlemde sıcak kiremit kırmızısı, aksi halde marka
/// mercanı kullanılır.
class _ToneColors {
  const _ToneColors(this.accent, this.soft);

  final Color accent;
  final Color soft;

  static _ToneColors of(AppDialogTone tone) => switch (tone) {
    AppDialogTone.danger => const _ToneColors(
      Color(0xFFD64541),
      Color(0xFFFF9E8E),
    ),
    AppDialogTone.brand => const _ToneColors(
      AppColors.primary,
      AppColors.primaryLight,
    ),
  };
}

/// Diyalog kabuğu: krem panel + ışık katmanı + madalyon + metin + düğmeler.
class _DialogPanel extends StatelessWidget {
  const _DialogPanel({
    required this.icon,
    required this.tone,
    required this.title,
    required this.message,
    required this.actions,
  });

  final IconData icon;
  final AppDialogTone tone;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colors = _ToneColors.of(tone);

    return AppDialogShell(
      accent: colors.accent,
      soft: colors.soft,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DialogMedallion(icon: icon, accent: colors.accent, soft: colors.soft),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.h3.copyWith(color: AppColors.ink),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSoft,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Ortalanmış krem panel. İçeriği serbest bırakır ki "Hakkında" gibi özel
/// kartlar da aynı kabuğu kullanabilsin.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.child,
    this.accent = AppColors.primary,
    this.soft = AppColors.primaryLight,
  });

  final Widget child;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.transparent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.creamTop, AppColors.creamBottom],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: accent.withValues(alpha: 0.14)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.26),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                  BoxShadow(
                    color: soft.withValues(alpha: 0.30),
                    blurRadius: 60,
                    spreadRadius: -12,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _DialogAuraPainter(
                              accent: accent,
                              soft: soft,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panelin tepesindeki yuvarlak ikon rozeti.
class _DialogMedallion extends StatelessWidget {
  const _DialogMedallion({
    required this.icon,
    required this.accent,
    required this.soft,
  });

  final IconData icon;
  final Color accent;
  final Color soft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [soft, accent],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: 32, color: Colors.white),
    );
  }
}

/// Diyalog düğmesi: dolu (onay) ya da hayalet (vazgeç).
class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.filled,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final AppDialogTone tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = _ToneColors.of(tone);

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: filled
                ? LinearGradient(colors: [colors.soft, colors.accent])
                : null,
            color: filled ? null : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(AppRadius.full),
            border: filled
                ? null
                : Border.all(color: AppColors.inkSoft.withValues(alpha: 0.28)),
            boxShadow: filled
                ? [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: AppTypography.button.copyWith(
              color: filled ? Colors.white : AppColors.ink,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}

/// Panelin arkasındaki ışık: madalyonun ardında sıcak leke, ondan dışa açılan
/// iki ince halka ve alt köşede kum tonu bir derinlik lekesi.
class _DialogAuraPainter extends CustomPainter {
  const _DialogAuraPainter({required this.accent, required this.soft});

  final Color accent;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    // Madalyonun merkezi: üst iç boşluk (24) + yarıçap (33).
    final anchor = Offset(size.width / 2, 57);

    final glow = size.width * 0.62;
    canvas.drawCircle(
      anchor,
      glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            soft.withValues(alpha: 0.34),
            soft.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: anchor, radius: glow)),
    );

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        anchor,
        40.0 + i * 26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.16 / i),
      );
    }

    final corner = Offset(size.width * 0.08, size.height);
    final cornerR = size.width * 0.5;
    canvas.drawCircle(
      corner,
      cornerR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.sand.withValues(alpha: 0.26),
            AppColors.sand.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: corner, radius: cornerR)),
    );
  }

  @override
  bool shouldRepaint(covariant _DialogAuraPainter old) =>
      old.accent != accent || old.soft != soft;
}
