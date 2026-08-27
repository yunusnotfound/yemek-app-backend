import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';

/// Bildirim şeridinin tonu. Renk, ikon, varsayılan başlık, süre ve dokunsal
/// geri bildirim bu seçime bağlıdır.
enum AppNoticeTone { success, error, warning, info }

/// Uygulamanın tek geçici bildirim yüzeyi — Material SnackBar'ın yerini alır.
///
/// Neden SnackBar değil: SnackBar ekranın altına oturan, koyu gri, köşeli bir
/// Android kabuğudur; markanın sıcak krem/mercan dilinden tamamen kopuktur.
/// Ayrıca `ScaffoldMessenger`'a bağlı olduğu için sayfa `pop` edildiğinde ya
/// kaybolur ya da yanlış Scaffold'da belirir (ödeme ve işletme kayıt akışında
/// tam olarak bu oluyordu).
///
/// Bunun yerine: kök Overlay'e yerleşen, üstten süzülerek inen bir şerit.
/// Açılış sahnesinin (`AuroraScene`) diliyle aynı ögeleri taşır — sıcak ışık
/// lekesi, madalyondan dışa açılan ince halkalar, altta incecik bir süre
/// çizgisi. Kök Overlay'de durduğu için sayfa geçişlerinden etkilenmez.
///
/// Kullanım:
/// ```dart
/// AppNotice.success(context, 'Kart kaydedildi');
/// AppNotice.error(context, state.message);
/// ```
///
/// Aynı anda tek şerit görünür; yenisi gelirse eskisi kısa bir takasla çekilir.
class AppNotice {
  AppNotice._();

  /// Ekrandaki şeridin durumu. Overlay girişi kaldırılırken eski `dispose`,
  /// yeni giriş takıldıktan SONRA çalışabildiği için kimlik kontrolü şart.
  static _NoticeLayerState? _layer;

  static OverlayEntry? _entry;

  /// İşlem başarıyla tamamlandı.
  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.success,
    title: title,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// İşlem başarısız — kullanıcının görmesi gereken hata.
  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.error,
    title: title,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Engelleyici olmayan uyarı — eksik seçim, dikkat edilmesi gereken durum.
  static void warning(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.warning,
    title: title,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Nötr bilgi.
  static void info(
    BuildContext context,
    String message, {
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message,
    tone: AppNoticeTone.info,
    title: title,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// Şeridi gösterir. Ekranda başka bir şerit varsa onun yerini alır.
  static void show(
    BuildContext context,
    String message, {
    AppNoticeTone tone = AppNoticeTone.info,
    String? title,
    Duration? duration,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final spec = _NoticeSpec(
      message: message,
      tone: tone,
      title: title,
      // Hata metinleri genelde daha uzun ve daha önemli: biraz daha uzun kalır.
      duration:
          duration ??
          (tone == AppNoticeTone.error
              ? const Duration(milliseconds: 4600)
              : const Duration(milliseconds: 3400)),
      actionLabel: actionLabel,
      onAction: onAction,
    );

    final layer = _layer;
    if (layer != null && layer.mounted) {
      layer.present(spec);
      return;
    }

    _detach();
    final entry = OverlayEntry(
      builder: (_) => _NoticeLayer(spec: spec, onClosed: _detach),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Görünen şeridi erkenden kapatır (ör. kullanıcı akışı ilerlettiğinde).
  static void dismiss() => _layer?.hide();

  static void _detach() {
    // Önce referans bırakılır: girişi yalnızca bu yol söktüğü için çift
    // `remove()` mümkün olmaz. (`OverlayEntry.mounted` burada kullanılamaz;
    // henüz build edilmemiş ama takılı bir giriş için false döner.)
    final entry = _entry;
    _entry = null;
    entry?.remove();
  }
}

/// Tek bir bildirimin içeriği.
class _NoticeSpec {
  const _NoticeSpec({
    required this.message,
    required this.tone,
    required this.duration,
    this.title,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppNoticeTone tone;
  final Duration duration;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
}

/// Tona göre görsel kimlik.
///
/// Renkler `AppColors` durum renklerinin sıcak zemine göre ayarlanmış
/// karşılıklarıdır: saf Material yeşili/mavisi krem zeminde soğuk bir yama gibi
/// duruyordu, bu yüzden hepsi bir tık kırmızıya/toprağa çekildi.
class _ToneStyle {
  const _ToneStyle({
    required this.accent,
    required this.soft,
    required this.icon,
    required this.title,
  });

  final Color accent;
  final Color soft;
  final IconData icon;
  final String title;

  static const Map<AppNoticeTone, _ToneStyle> _map = {
    AppNoticeTone.success: _ToneStyle(
      accent: Color(0xFF2E9E6B),
      soft: Color(0xFF8ED9B4),
      icon: Icons.check_rounded,
      title: 'Tamamdır',
    ),
    AppNoticeTone.error: _ToneStyle(
      accent: Color(0xFFD64541),
      soft: Color(0xFFFF9E8E),
      icon: Icons.priority_high_rounded,
      title: 'Bir aksilik oldu',
    ),
    AppNoticeTone.warning: _ToneStyle(
      accent: Color(0xFFE09B22),
      soft: Color(0xFFFFD79A),
      icon: Icons.error_outline_rounded,
      title: 'Dikkat',
    ),
    AppNoticeTone.info: _ToneStyle(
      accent: AppColors.primary,
      soft: AppColors.primaryLight,
      icon: Icons.auto_awesome_rounded,
      title: 'Bilgi',
    ),
  };

  static _ToneStyle of(AppNoticeTone tone) => _map[tone]!;
}

/// Şerit belirirken verilen dokunsal geri bildirim; şiddeti önemle orantılı.
void _toneHaptic(AppNoticeTone tone) {
  switch (tone) {
    case AppNoticeTone.error:
      HapticFeedback.heavyImpact();
    case AppNoticeTone.warning:
      HapticFeedback.mediumImpact();
    case AppNoticeTone.success:
      HapticFeedback.lightImpact();
    case AppNoticeTone.info:
      HapticFeedback.selectionClick();
  }
}

class _NoticeLayer extends StatefulWidget {
  const _NoticeLayer({required this.spec, required this.onClosed});

  final _NoticeSpec spec;
  final VoidCallback onClosed;

  @override
  State<_NoticeLayer> createState() => _NoticeLayerState();
}

class _NoticeLayerState extends State<_NoticeLayer>
    with TickerProviderStateMixin {
  /// 0 = gizli, 1 = tam görünür.
  late final AnimationController _enter;

  /// Şeridin ömrü; alttaki süre çizgisini de bu sürer.
  late final AnimationController _life;

  /// Parmak bırakıldığında şeridi yerine oturtan yay.
  late final AnimationController _settle;
  Animation<double> _settleAnim = const AlwaysStoppedAnimation<double>(0);

  late _NoticeSpec _spec;

  /// Dikey sürükleme kaydırması (yukarı = negatif).
  double _dragY = 0;

  bool _closing = false;

  /// Kapanış animasyonu sürerken yeni bildirim gelirse eski kapanış iptal olur.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _spec = widget.spec;

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _life = AnimationController(vsync: this, duration: _spec.duration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) hide();
      });
    _settle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
      if (mounted) setState(() => _dragY = _settleAnim.value);
    });

    AppNotice._layer = this;
    _start();
  }

  @override
  void dispose() {
    // Yeni bir şerit çoktan devraldıysa referansı ondan koparma.
    if (identical(AppNotice._layer, this)) AppNotice._layer = null;
    _enter.dispose();
    _life.dispose();
    _settle.dispose();
    super.dispose();
  }

  void _start() {
    _toneHaptic(_spec.tone);
    _life
      ..duration = _spec.duration
      ..value = 0
      ..forward();
    _enter.forward(from: 0);
  }

  /// Ekrandaki şeridi yenisiyle değiştirir.
  Future<void> present(_NoticeSpec spec) async {
    final generation = ++_generation;
    _closing = false;
    _settle.stop();

    if (_enter.value > 0) {
      // Görünürken yenisi geldi: eskisi kısaca çekilsin ki iki metin üst üste
      // binmesin — anında değişim "atlama" gibi okunuyor.
      await _enter.animateTo(
        0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInCubic,
      );
      if (!mounted || generation != _generation) return;
    }

    setState(() {
      _spec = spec;
      _dragY = 0;
    });
    _start();
  }

  /// Şeridi kapatır ve Overlay girişini söker.
  Future<void> hide() async {
    if (_closing) return;
    _closing = true;
    final generation = _generation;

    _life.stop();
    _settle.stop();
    await _enter.animateTo(
      0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInCubic,
    );
    // Kapanış sürerken yeni bildirim geldiyse katman ayakta kalmalı.
    if (!mounted || generation != _generation) return;

    // Giriş sökülüyor: `dispose` bir sonraki kareye kaldığı için referansı
    // hemen bırak, yoksa aradaki `show()` çağrısı ölmekte olan katmana gider.
    if (identical(AppNotice._layer, this)) AppNotice._layer = null;
    widget.onClosed();
  }

  void _handleTap() {
    final action = _spec.onAction;
    if (action != null) {
      HapticFeedback.selectionClick();
      action();
    }
    hide();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _settle.stop();
    _life.stop();
    setState(() {
      final dy = details.delta.dy;
      // Aşağı çekiş yaylanır: şerit üstten geldiği için oraya gitmez.
      _dragY = (_dragY + (dy > 0 ? dy * 0.22 : dy)).clamp(-220.0, 26.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_dragY < -26 || velocity < -650) {
      hide();
      return;
    }
    _settleAnim = Tween<double>(begin: _dragY, end: 0).animate(
      CurvedAnimation(parent: _settle, curve: Curves.elasticOut),
    );
    _settle.forward(from: 0);
    if (!_closing) _life.forward();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final tone = _ToneStyle.of(_spec.tone);
    final title = _spec.title ?? tone.title;

    return Positioned(
      top: media.padding.top + 10,
      left: 14,
      right: 14,
      child: AnimatedBuilder(
        animation: Listenable.merge([_enter, _life]),
        builder: (context, child) {
          final t = _enter.value.clamp(0.0, 1.0);
          final glide = Curves.easeOutCubic.transform(t);
          // Üstten süzülüş + son anda hafif bir "oturma" ölçeği.
          final offsetY = (1 - glide) * -52 + _dragY;
          final scale =
              0.94 + 0.06 * Curves.easeOutBack.transform(t).clamp(0.0, 1.0);

          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, offsetY),
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.topCenter,
                child: child,
              ),
            ),
          );
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Semantics(
              container: true,
              liveRegion: true,
              label: '$title. ${_spec.message}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _handleTap,
                onVerticalDragUpdate: _onDragUpdate,
                onVerticalDragEnd: _onDragEnd,
                child: _NoticeCard(
                  spec: _spec,
                  tone: tone,
                  title: title,
                  enter: _enter,
                  life: _life,
                  onClose: hide,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Şeridin kendisi: sıcak kart + madalyon + metin + süre çizgisi.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.spec,
    required this.tone,
    required this.title,
    required this.enter,
    required this.life,
    required this.onClose,
  });

  final _NoticeSpec spec;
  final _ToneStyle tone;
  final String title;
  final Animation<double> enter;
  final Animation<double> life;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        // Açılış sahnesinin fildişi → kum geçişi.
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.creamTop, AppColors.creamBottom],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: tone.accent.withValues(alpha: 0.16)),
        boxShadow: [
          // Soğuk siyah gölge krem zeminde kirli görünüyor; gölge de sıcak.
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: tone.soft.withValues(alpha: 0.34),
            blurRadius: 40,
            spreadRadius: -6,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Işık lekesi + madalyondan açılan halkalar + bir kerelik parıltı.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: AnimatedBuilder(
                    animation: enter,
                    builder: (context, _) => CustomPaint(
                      painter: _NoticeAuraPainter(
                        tone: tone,
                        progress: enter.value,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Medallion(tone: tone, enter: enter),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: AppTypography.bodySmall.copyWith(
                                color: tone.accent,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              spec.message,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.ink,
                                height: 1.28,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _CloseButton(onTap: onClose),
                    ],
                  ),
                  if (spec.actionLabel != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _ActionChip(
                        label: spec.actionLabel!,
                        tone: tone,
                        onTap: () {
                          spec.onAction?.call();
                          onClose();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _LifeLine(tone: tone, life: life),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ton renginde, girişte yaylanarak büyüyen ikon madalyonu.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.tone, required this.enter});

  final _ToneStyle tone;
  final Animation<double> enter;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: enter,
      builder: (context, child) {
        final t = enter.value.clamp(0.0, 1.0);
        final pop = Curves.easeOutBack.transform(t);
        return Transform.scale(
          scale: 0.55 + 0.45 * pop,
          child: Transform.rotate(angle: (1 - t) * -0.5, child: child),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tone.soft, tone.accent],
          ),
          boxShadow: [
            BoxShadow(
              color: tone.accent.withValues(alpha: 0.38),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(tone.icon, size: 22, color: Colors.white),
      ),
    );
  }
}

/// Kalan süreyi gösteren incecik çizgi — açılış sahnesinin ilerleme çubuğunun
/// aynısı. Zamanlayıcıyı görünür kılar; şerit "birden" kaybolmuş gibi olmaz.
class _LifeLine extends StatelessWidget {
  const _LifeLine({required this.tone, required this.life});

  final _ToneStyle tone;
  final Animation<double> life;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tone.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: life,
            builder: (context, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (1 - life.value).clamp(0.0, 1.0),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [tone.accent, tone.soft]),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Bildirimi kapat',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: AppColors.inkSoft.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final _ToneStyle tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tone.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: tone.accent.withValues(alpha: 0.28)),
        ),
        child: Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: tone.accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Kartın içindeki ışık katmanı.
///
/// Üç öge: (1) madalyonun ardından yayılan sıcak leke, (2) madalyondan dışa
/// açılan iki ince halka — açılış sahnesindeki dalgaların küçük hali, (3) giriş
/// sırasında kartın üstünden bir kez geçen parıltı.
class _NoticeAuraPainter extends CustomPainter {
  const _NoticeAuraPainter({required this.tone, required this.progress});

  final _ToneStyle tone;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    // Madalyonun merkezi: sol iç boşluk (14) + yarıçap (22).
    final anchor = Offset(36, size.height / 2);

    final blobRadius = size.height * 1.05;
    canvas.drawCircle(
      anchor,
      blobRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                tone.soft.withValues(alpha: 0.30 * progress),
                tone.soft.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: anchor, radius: blobRadius),
            ),
    );

    // Sağ kenarda kartı derinleştiren soluk kum lekesi.
    final tail = Offset(size.width * 0.94, size.height * 0.1);
    final tailRadius = size.height * 0.9;
    canvas.drawCircle(
      tail,
      tailRadius,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                AppColors.sand.withValues(alpha: 0.26 * progress),
                AppColors.sand.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: tail, radius: tailRadius)),
    );

    // Madalyondan açılan halkalar.
    for (var i = 0; i < 2; i++) {
      final p = (progress - i * 0.18).clamp(0.0, 1.0);
      if (p <= 0) continue;
      final alpha = (1 - p) * 0.34;
      if (alpha <= 0.004) continue;
      canvas.drawCircle(
        anchor,
        26 + 44 * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..color = tone.accent.withValues(alpha: alpha),
      );
    }

    // Girişte kartın üstünden bir kez geçen ışık.
    final sweep = ((progress - 0.12) / 0.62).clamp(0.0, 1.0);
    if (sweep > 0 && sweep < 1) {
      final x = size.width * (-0.25 + 1.5 * sweep);
      final rect = Rect.fromLTWH(x - 56, 0, 112, size.height);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.30 * (1 - sweep)),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoticeAuraPainter old) =>
      old.progress != progress || old.tone != tone;
}
