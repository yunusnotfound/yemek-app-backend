import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/theme.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/storage/token_storage.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final TokenStorage _tokenStorage = createDefaultTokenStorage();
  late final DioClient _dioClient = DioClient(tokenStorage: _tokenStorage);

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

      setState(() {
        _notifications = items.map((e) => e as Map<String, dynamic>).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error =
            e.response?.data?['message'] as String? ??
            'Bildirimler yuklenemedi';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Bir hata olustu';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(String id, int index) async {
    try {
      await _dioClient.dio.patch('/notifications/$id/read');
      setState(() {
        _notifications[index]['isRead'] = true;
      });
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    try {
      await _dioClient.dio.patch('/notifications/mark-all-read');
      setState(() {
        for (final n in _notifications) {
          n['isRead'] = true;
        }
      });
    } catch (_) {}
  }

  Future<void> _deleteNotification(String id, int index) async {
    try {
      await _dioClient.dio.delete('/notifications/$id');
      setState(() {
        _notifications.removeAt(index);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          if (_notifications.any((n) => n['isRead'] == false))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Tumunu Oku'),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTypography.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh),
                label: const Text('Tekrar Dene'),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Bildirim yok', style: AppTypography.h3),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Yeni bildirimler burada gorunecek',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _notifications.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationCard(notification, index);
        },
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification, int index) {
    final isRead = notification['isRead'] as bool? ?? false;
    final title = notification['title'] as String? ?? '';
    final message = notification['message'] as String? ?? '';
    final type = notification['type'] as String? ?? 'system';
    final createdAt = notification['createdAt'] as String?;
    final id = notification['id'] as String;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _deleteNotification(id, index),
      child: GestureDetector(
        onTap: isRead ? null : () => _markAsRead(id, index),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isRead
                ? AppColors.surface
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: isRead
                ? null
                : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: _getTypeColor(type).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getTypeIcon(type),
                  size: 20,
                  color: _getTypeColor(type),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isRead
                            ? FontWeight.normal
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message,
                      style: AppTypography.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _formatDate(createdAt),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'order_status':
        return Icons.inventory_2_outlined;
      case 'new_package':
        return Icons.fastfood_outlined;
      case 'promotion':
        return Icons.local_offer_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'order_status':
        return AppColors.info;
      case 'new_package':
        return AppColors.success;
      case 'promotion':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Simdi';
      if (diff.inMinutes < 60) return '${diff.inMinutes} dk once';
      if (diff.inHours < 24) return '${diff.inHours} saat once';
      if (diff.inDays < 7) return '${diff.inDays} gun once';
      return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
    } catch (_) {
      return '';
    }
  }
}
