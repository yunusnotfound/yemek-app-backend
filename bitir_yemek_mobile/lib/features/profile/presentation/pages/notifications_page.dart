import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../shared/widgets/app_notice.dart';
import '../../../../shared/widgets/shimmer_loader.dart';

/// Uygulama içi bildirim merkezi.
///
/// Görsel dil, açılış sahnesi (`AuroraScene`) ve bildirim şeridiyle (`AppNotice`)
/// aynı: sıcak krem zemin, tondan beslenen madalyonlar, ışık lekeleri ve ince
/// halkalar. Material'ın gri liste görünümü yerine kartlar "okunmamış" olduğu
/// sürece hafifçe parlar; okununca sakinleşip geri çekilir.
///
/// Veri akışı değişmedi: aynı uçlar, aynı istekler.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with TickerProviderStateMixin {
  final _dioClient = appDioClient;

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  /// Liste kartlarının sırayla belirmesi.
  late final AnimationController _stagger;

  /// Okunmamış işaretinin yavaş nefes alması — tek denetleyici tüm liste için.
  late final AnimationController _pulse;

  int get _unreadCount =>
      _notifications.where((n) => n['isRead'] != true).length;

  @override
  void initState() {
    super.initState();
    _stagger = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _loadNotifications();
  }

  @override
  void dispose() {
    _stagger.dispose();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _dioClient.dio.get('/notifications');
      final data = response.data as Map<String, dynamic>;
      final items = data['data'] as List<dynamic>? ?? [];

      final parsed = items.map((e) => e as Map<String, dynamic>).toList();
      // Tarihe göre yeniden eskiye: zaman başlıkları ("Bugün", "Dün") ancak
      // sıralı listede tek blok halinde görünür.
      parsed.sort((a, b) {
        final da = _parseDate(a['createdAt'] as String?);
        final db = _parseDate(b['createdAt'] as String?);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

      if (!mounted) return;
      setState(() {
        _notifications = parsed;
        _isLoading = false;
      });
      _stagger.forward(from: 0);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['message'] as String? ??
            'Bildirimler yuklenemedi';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Bir hata olustu';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    HapticFeedback.selectionClick();
    try {
      await _dioClient.dio.patch('/notifications/$id/read');
      if (!mounted) return;
      setState(() {
        _notifications[index]['isRead'] = true;
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    HapticFeedback.lightImpact();
    try {
      await _dioClient.dio.patch('/notifications/mark-all-read');
      if (!mounted) return;
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
      AppNotice.success(context, 'Tum bildirimler okundu olarak isaretlendi');
    } catch (_) {
      if (!mounted) return;
      AppNotice.error(context, 'Bildirimler isaretlenemedi');
    }
  }

  Future<void> _deleteNotification(String id, int index) async {
    // Dismissible kartı zaten kaldırdı; listeden de hemen çıkmalı, yoksa
    // "dismissed widget still in tree" hatası alınır. İstek başarısız olursa
    // kart geri konur.
    final removed = _notifications[index];
    setState(() => _notifications.removeAt(index));

    try {
      await _dioClient.dio.delete('/notifications/$id');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notifications.insert(index.clamp(0, _notifications.length), removed);
      });
      AppNotice.error(context, 'Bildirim silinemedi');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _NotificationsHeader(
            unreadCount: _unreadCount,
            isLoading: _isLoading,
            onBack: () => Navigator.of(context).pop(),
            onMarkAll: _unreadCount > 0 ? _markAllAsRead : null,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingList();
    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: _loadNotifications);
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: AppColors.primary,
      backgroundColor: AppColors.creamTop,
      child: _notifications.isEmpty ? const _EmptyState() : _buildList(),
    );
  }

  Widget _buildList() {
    final entries = _buildEntries();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final label = entry.label;

        if (label != null) {
          return _reveal(
            entry.order,
            Padding(
              padding: EdgeInsets.only(
                top: i == 0 ? 0 : AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: _GroupLabel(label: label),
            ),
          );
        }

        final notification = _notifications[entry.index];
        return _reveal(
          entry.order,
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _NotificationCard(
              notification: notification,
              pulse: _pulse,
              onTap: notification['isRead'] == true
                  ? null
                  : () => _markAsRead(
                      notification['id'] as String,
                      entry.index,
                    ),
              onDismissed: () => _deleteNotification(
                notification['id'] as String,
                entry.index,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Zaman başlıkları + kartların tek düz listesi. Her ögede kaynak listedeki
  /// gerçek indeks taşınır; okundu/sil işlemleri o indeksle çalışır.
  List<_ListEntry> _buildEntries() {
    final entries = <_ListEntry>[];
    String? currentGroup;
    var order = 0;

    for (var i = 0; i < _notifications.length; i++) {
      final group = _groupLabel(
        _parseDate(_notifications[i]['createdAt'] as String?),
      );
      if (group != currentGroup) {
        entries.add(_ListEntry.header(group, order++));
        currentGroup = group;
      }
      entries.add(_ListEntry.item(i, order++));
    }
    return entries;
  }

  /// Kartları sırayla aşağıdan yukarı süzerek açar.
  Widget _reveal(int order, Widget child) {
    return AnimatedBuilder(
      animation: _stagger,
      builder: (context, inner) {
        // 12. ögeden sonra gecikme artmaz; uzun listede alt kartlar beklemesin.
        final start = order.clamp(0, 12) * 0.05;
        final t = _stage(
          _stagger.value,
          start,
          start + 0.4,
          curve: Curves.easeOutCubic,
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 20),
            child: inner,
          ),
        );
      },
      child: child,
    );
  }
}

/// Zaman çizelgesinin [start]–[end] aralığını 0→1'e eşler.
double _stage(
  double t,
  double start,
  double end, {
  Curve curve = Curves.easeOut,
}) {
  if (end <= start) return t >= end ? 1 : 0;
  return curve.transform(((t - start) / (end - start)).clamp(0.0, 1.0));
}

DateTime? _parseDate(String? value) {
  if (value == null) return null;
  return DateTime.tryParse(value);
}

/// Listedeki tek satır: ya bir zaman başlığı ya da bir bildirim.
class _ListEntry {
  const _ListEntry.header(this.label, this.order) : index = -1;
  const _ListEntry.item(this.index, this.order) : label = null;

  final String? label;
  final int index;
  final int order;
}

String _groupLabel(DateTime? date) {
  if (date == null) return 'Daha once';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;

  if (diff <= 0) return 'Bugun';
  if (diff == 1) return 'Dun';
  if (diff < 7) return 'Bu hafta';
  return 'Daha once';
}

/// Bildirim türünün rengi, ikonu ve etiketi.
class _TypeStyle {
  const _TypeStyle({
    required this.accent,
    required this.soft,
    required this.icon,
    required this.label,
  });

  final Color accent;
  final Color soft;
  final IconData icon;
  final String label;

  static _TypeStyle of(String type) => switch (type) {
    'order_status' => const _TypeStyle(
      accent: Color(0xFF3E7EA6),
      soft: Color(0xFF9FC9DF),
      icon: Icons.receipt_long_rounded,
      label: 'Siparis',
    ),
    'new_package' => const _TypeStyle(
      accent: Color(0xFF2E9E6B),
      soft: Color(0xFF8ED9B4),
      icon: Icons.takeout_dining_rounded,
      label: 'Yeni paket',
    ),
    'promotion' => const _TypeStyle(
      accent: Color(0xFFE09B22),
      soft: Color(0xFFFFD79A),
      icon: Icons.local_offer_rounded,
      label: 'Kampanya',
    ),
    _ => const _TypeStyle(
      accent: AppColors.primary,
      soft: AppColors.primaryLight,
      icon: Icons.campaign_rounded,
      label: 'Duyuru',
    ),
  };
}

/// Sayfanın üst bandı — AppBar yerine, arkasında sıcak bir ışıkla.
class _NotificationsHeader extends StatelessWidget {
  const _NotificationsHeader({
    required this.unreadCount,
    required this.isLoading,
    required this.onBack,
    this.onMarkAll,
  });

  final int unreadCount;
  final bool isLoading;
  final VoidCallback onBack;
  final VoidCallback? onMarkAll;

  @override
  Widget build(BuildContext context) {
    final subtitle = isLoading
        ? 'Yukleniyor...'
        : unreadCount > 0
        ? '$unreadCount okunmamis bildirim'
        : 'Hepsi okundu';

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: const _HeaderAuraPainter()),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _SoftCircleButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: onBack,
                  semanticLabel: 'Geri',
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Bildirimler',
                        style: AppTypography.h2.copyWith(
                          color: AppColors.ink,
                          fontSize: 26,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: unreadCount > 0
                              ? AppColors.primary
                              : AppColors.inkSoft,
                          fontWeight: unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onMarkAll != null) _MarkAllPill(onTap: onMarkAll!),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Üst bandın arkasındaki iki yumuşak ışık lekesi.
class _HeaderAuraPainter extends CustomPainter {
  const _HeaderAuraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, Color color, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    blob(
      Offset(size.width * 0.9, size.height * 0.1),
      size.width * 0.5,
      AppColors.primaryLight,
      0.30,
    );
    blob(
      Offset(size.width * 0.1, size.height * 0.9),
      size.width * 0.45,
      AppColors.sand,
      0.26,
    );
  }

  @override
  bool shouldRepaint(covariant _HeaderAuraPainter oldDelegate) => false;
}

class _SoftCircleButton extends StatelessWidget {
  const _SoftCircleButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.creamTop,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.inkSoft.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.ink),
        ),
      ),
    );
  }
}

class _MarkAllPill extends StatelessWidget {
  const _MarkAllPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Tumunu okundu isaretle',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryLight, AppColors.primary],
            ),
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.32),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                'Tumunu oku',
                style: AppTypography.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bugun", "Dun" gibi zaman başlıkları — iki yanında incecik çizgiyle.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            color: AppColors.inkSoft,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Container(
            height: 1,
            color: AppColors.inkSoft.withValues(alpha: 0.16),
          ),
        ),
      ],
    );
  }
}

/// Tek bildirim kartı.
///
/// Okunmamışken: tür renginde sol şerit, sıcak krem gradyan, ince renkli
/// çerçeve ve nefes alan bir nokta. Okununca hepsi sönüp düz beyaza döner —
/// listeye bakınca ne kaldığı bir bakışta anlaşılır.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.pulse,
    required this.onDismissed,
    this.onTap,
  });

  final Map<String, dynamic> notification;
  final Animation<double> pulse;
  final VoidCallback onDismissed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isRead = notification['isRead'] as bool? ?? false;
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final type = notification['type'] as String? ?? 'system';
    final createdAt = notification['createdAt'] as String?;
    final id = notification['id'] as String;
    final style = _TypeStyle.of(type);

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: const _DismissBackground(),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        onDismissed();
      },
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: isRead
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.creamTop,
                      style.soft.withValues(alpha: 0.22),
                    ],
                  ),
            color: isRead ? AppColors.surface : null,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: isRead
                  ? AppColors.inkSoft.withValues(alpha: 0.10)
                  : style.accent.withValues(alpha: 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: isRead ? 0.05 : 0.10),
                blurRadius: isRead ? 8 : 18,
                offset: Offset(0, isRead ? 2 : 8),
              ),
              if (!isRead)
                BoxShadow(
                  color: style.soft.withValues(alpha: 0.28),
                  blurRadius: 26,
                  spreadRadius: -8,
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tür rengindeki sol şerit — okunmuşta görünmez.
                  SizedBox(
                    width: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isRead
                            ? null
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [style.soft, style.accent],
                              ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TypeMedallion(style: style, isRead: isRead),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: AppColors.ink,
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.w600,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (!isRead) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      _UnreadDot(
                                        color: style.accent,
                                        pulse: pulse,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  message,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.inkSoft,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  children: [
                                    _TypeChip(style: style, muted: isRead),
                                    if (createdAt != null) ...[
                                      const SizedBox(width: AppSpacing.sm),
                                      Container(
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.inkSoft.withValues(
                                            alpha: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Text(
                                        _formatDate(createdAt),
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.inkSoft.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tür ikonunun yuvarlak yuvası. Okunmuş kartta renk çekilir.
class _TypeMedallion extends StatelessWidget {
  const _TypeMedallion({required this.style, required this.isRead});

  final _TypeStyle style;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isRead
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [style.soft, style.accent],
              ),
        color: isRead ? style.accent.withValues(alpha: 0.10) : null,
        boxShadow: isRead
            ? null
            : [
                BoxShadow(
                  color: style.accent.withValues(alpha: 0.34),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(
        style.icon,
        size: 20,
        color: isRead ? style.accent.withValues(alpha: 0.7) : Colors.white,
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.style, required this.muted});

  final _TypeStyle style;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: style.accent.withValues(alpha: muted ? 0.07 : 0.13),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        style.label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: style.accent.withValues(alpha: muted ? 0.65 : 1),
        ),
      ),
    );
  }
}

/// Okunmamış işareti — çevresinde yavaşça genişleyen bir hale.
class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.color, required this.pulse});

  final Color color;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(pulse.value);
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45 * (1 - t)),
                blurRadius: 4 + 6 * t,
                spreadRadius: 1 + 3 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Sola kaydırınca beliren silme zemini.
class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9E8E), Color(0xFFD64541)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.delete_outline_rounded, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            'Sil',
            style: AppTypography.bodyMedium.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yükleme sırasında kart iskeletleri — boş ekran yerine listenin ritmi.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.sm,
        AppSpacing.screenPadding,
        AppSpacing.xxl,
      ),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) => ShimmerLoader(
        isLoading: true,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerContainer(width: 42, height: 42, borderRadius: 21),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerContainer(
                      width: index.isEven ? 150 : 190,
                      height: 13,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const ShimmerContainer(
                      width: double.infinity,
                      height: 11,
                    ),
                    const SizedBox(height: 6),
                    const ShimmerContainer(width: 120, height: 11),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bildirim yokken: sıcak bir hale ve içinde sakin bir zil.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      // RefreshIndicator'ın çalışması için boş durumda da kaydırılabilir kalır.
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(painter: const _EmptyAuraPainter()),
                  ),
                ),
              ),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.creamTop, AppColors.creamBottom],
                  ),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.36),
                      blurRadius: 34,
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.notifications_none_rounded,
                  size: 42,
                  color: AppColors.primary.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Sessizlik',
          style: AppTypography.h3.copyWith(color: AppColors.ink),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Text(
            'Yeni paketler, siparis hareketleri ve kampanyalar burada belirecek.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.inkSoft,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Boş durumun arkasındaki hale ve halkalar.
class _EmptyAuraPainter extends CustomPainter {
  const _EmptyAuraPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.9;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.primaryLight.withValues(alpha: 0.22),
            AppColors.primaryLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(
        center,
        56.0 + i * 22,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.primary.withValues(alpha: 0.16 / i),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EmptyAuraPainter oldDelegate) => false;
}

/// Yükleme başarısız olduğunda gösterilen sıcak hata kartı.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF9E8E), Color(0xFFD64541)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD64541).withValues(alpha: 0.32),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.ink),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryLight, AppColors.primary],
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.34),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Tekrar dene',
                      style: AppTypography.button.copyWith(fontSize: 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(String dateStr) {
  final date = _parseDate(dateStr);
  if (date == null) return '';

  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Simdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk once';
  if (diff.inHours < 24) return '${diff.inHours} saat once';
  if (diff.inDays < 7) return '${diff.inDays} gun once';
  return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
}
