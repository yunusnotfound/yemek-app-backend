import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../config/theme.dart';
import 'scene_palette.dart';

/// Açılış sahnesi.
///
/// Katmanlar (arkadan öne): süzülen ışık lekeleri → merkezden yayılan halkalar
/// → marka logosu rozeti → harf harf yükselen isim → slogan → alttaki ilerleme
/// çizgisi.
///
/// Tasarım yaklaşımı bilinçli olarak İLLÜSTRATİF DEĞİL: nesne resmetmek yerine
/// ışık, derinlik ve tipografiyle çalışır. Zemin tamamen çizimle üretilir; tek
/// varlık, merkezdeki gerçek uygulama logosudur (`assets/icon/app_icon.png`).
/// Ağ isteği gerektirmez.
///
/// Sahne kendi zamanlamasını yönetir; bitince [onComplete] çağrılır.
/// Yönlendirme kararı çağıran sayfaya aittir — bu widget yalnızca gösterir.
class AuroraScene extends StatefulWidget {
  const AuroraScene({
    super.key,
    required this.palette,
    required this.onComplete,
  });

  final ScenePalette palette;

  /// Açılış animasyonu tamamlandığında bir kez çağrılır.
  final VoidCallback onComplete;

  /// Sahnenin toplam süresi.
  static const Duration duration = Duration(milliseconds: 4200);

  @override
  State<AuroraScene> createState() => _AuroraSceneState();
}

class _AuroraSceneState extends State<AuroraScene>
    with TickerProviderStateMixin {
  static const String _wordmark = 'BitirGitsin';

  /// Sahnenin ana zaman çizelgesi (0 → 1).
  late final AnimationController _timeline;

  /// Zemindeki ışık lekelerinin sürekli süzülmesi — zaman çizelgesinden
  /// bağımsız döner ki sahne bittikten sonra da donmuş görünmesin.
  late final AnimationController _drift;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _timeline = AnimationController(
      vsync: this,
      duration: AuroraScene.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && !_completed) {
          _completed = true;
          widget.onComplete();
        }
      });

    _timeline.forward();
  }

  @override
  void dispose() {
    _timeline.dispose();
    _drift.dispose();
    super.dispose();
  }

  /// [t]'yi [start]–[end] aralığına göre 0-1'e normalize eder; aralık dışında
  /// 0 veya 1'e sabitlenir. Zaman çizelgesindeki her katman bunu kullanır.
  double _stage(double t, double start, double end, {Curve curve = Curves.easeOut}) {
    if (t <= start) return 0;
    if (t >= end) return 1;
    return curve.transform((t - start) / (end - start));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;

    return AnimatedBuilder(
      animation: Listenable.merge([_timeline, _drift]),
      builder: (context, _) {
        final t = _timeline.value;

        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.skyTop, p.skyBottom],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Zemin: süzülen ışık lekeleri + merkez hale.
              CustomPaint(
                painter: _AuroraPainter(
                  palette: p,
                  drift: _drift.value,
                  intro: _stage(t, 0, 0.32, curve: Curves.easeOutCubic),
                ),
              ),

              // Merkezden yayılan ince halkalar.
              CustomPaint(
                painter: _RipplePainter(
                  color: p.accent,
                  progress: _stage(t, 0.06, 0.72, curve: Curves.easeOutCubic),
                ),
              ),

              _buildCenterpiece(t, p),
              _buildProgressBar(t, p),
            ],
          ),
        );
      },
    );
  }

  /// Logo rozeti + isim + slogan.
  Widget _buildCenterpiece(double t, ScenePalette p) {
    final discIn = _stage(t, 0.08, 0.44, curve: Curves.easeOutBack);
    final sheen = _stage(t, 0.30, 0.62);
    final taglineIn = _stage(t, 0.62, 0.86);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.scale(
            scale: 0.7 + discIn * 0.3,
            child: Opacity(
              opacity: discIn.clamp(0.0, 1.0),
              child: _buildDisc(p, sheen),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          _buildWordmark(t, p),

          const SizedBox(height: AppSpacing.sm),

          Opacity(
            opacity: taglineIn,
            child: Transform.translate(
              offset: Offset(0, (1 - taglineIn) * 10),
              child: Text(
                p.tagline,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(
                  color: p.inkSoft,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Marka logosu.
  ///
  /// Logo elle ÇİZİLMEZ; uygulamanın gerçek ikon varlığı kullanılır
  /// (`assets/icon/app_icon.png` — launcher ikonuyla aynı dosya). Böylece
  /// açılış ekranındaki işaret, ana ekrandaki uygulama simgesiyle birebir aynı
  /// olur ve logo tek bir yerde bakım görür.
  ///
  /// Varlık kare ve turuncu zeminli olduğundan daire olarak kırpılır: ortaya
  /// beyaz yapraklı turuncu bir rozet çıkar.
  Widget _buildDisc(ScenePalette p, double reveal) {
    const size = 132.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: p.accent.withValues(alpha: 0.26),
            blurRadius: 40,
            spreadRadius: 2,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: p.halo.withValues(alpha: 0.55),
            blurRadius: 64,
            spreadRadius: 8,
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/icon/app_icon.png',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
            // Rozetin üstünden geçen ince ışık: düz bir PNG'ye hacim katar.
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.22 * reveal),
                      Colors.white.withValues(alpha: 0),
                      Colors.black.withValues(alpha: 0.10 * reveal),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Harfleri sırayla yükselerek beliren isim.
  Widget _buildWordmark(double t, ScenePalette p) {
    final chars = _wordmark.split('');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(chars.length, (i) {
        // Her harf bir öncekinden biraz sonra başlar: dalga etkisi.
        final start = 0.46 + i * 0.018;
        final a = _stage(t, start, start + 0.16, curve: Curves.easeOutCubic);

        return Opacity(
          opacity: a,
          child: Transform.translate(
            offset: Offset(0, (1 - a) * 18),
            child: Text(
              chars[i],
              style: AppTypography.h1.copyWith(
                color: p.ink,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Alttaki ince ilerleme çizgisi — sahnenin ne kadar sürdüğünü belli eder.
  Widget _buildProgressBar(double t, ScenePalette p) {
    final show = _stage(t, 0.10, 0.30);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 56),
        child: Opacity(
          opacity: show * (1 - _stage(t, 0.94, 1.0)),
          child: SizedBox(
            width: 96,
            height: 3,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: p.inkSoft.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: t.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.accent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Zeminde yavaşça süzülen üç ışık lekesi + merkez hale.
///
/// Lekeler farklı hızlarda ve yarıçaplarda döner; hiçbir an tam olarak
/// tekrarlamadıkları için zemin "canlı" kalır.
class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.palette,
    required this.drift,
    required this.intro,
  });

  final ScenePalette palette;
  final double drift;
  final double intro;

  @override
  void paint(Canvas canvas, Size size) {
    if (intro <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.42);
    final unit = size.shortestSide;

    void blob(Color color, double angle, double radius, double scale, double alpha) {
      final a = angle + drift * 2 * math.pi;
      final o = center + Offset(math.cos(a) * radius, math.sin(a) * radius * 0.6);
      final r = unit * scale * intro;

      canvas.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * intro),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }

    // Farklı açı ve hızlarda üç leke.
    blob(palette.tintWarm, 0.0, unit * 0.26, 0.62, 0.55);
    blob(palette.tintMid, 2.4, unit * 0.32, 0.54, 0.42);
    blob(palette.tintDeep, 4.3, unit * 0.22, 0.46, 0.30);

    // Merkezdeki sıcak hale — gece paletinde belirgin, gündüz sönük.
    final haloR = unit * 0.44 * intro;
    canvas.drawCircle(
      center,
      haloR,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.halo.withValues(alpha: 0.26 * intro),
            palette.halo.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: haloR)),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) =>
      old.drift != drift || old.intro != intro || old.palette != palette;
}

/// Merkezden dışa açılan üç ince halka — kademeli başlar, dışarı doğru söner.
class _RipplePainter extends CustomPainter {
  _RipplePainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height * 0.42);
    final maxR = size.shortestSide * 0.62;

    for (var i = 0; i < 3; i++) {
      // Her halka bir öncekinden 0.16 sonra yola çıkar.
      final p = (progress - i * 0.16).clamp(0.0, 1.0);
      if (p <= 0) continue;

      final r = maxR * p;
      // Dışa gittikçe sönümlenir.
      final alpha = (1 - p) * 0.26;
      if (alpha <= 0.001) continue;

      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter old) =>
      old.progress != progress || old.color != color;
}
