import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/notification_api_service.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final _notificationApi = GetIt.I<NotificationApiService>();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _notificationApi.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _notificationApi.markAsRead(notification.id);
      // Cập nhật state cục bộ
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere(
            (n) => n.id == notification.id,
          );
          if (index != -1) {
            final old = _notifications[index];
            _notifications[index] = NotificationModel(
              id: old.id,
              type: old.type,
              title: old.title,
              body: old.body,
              referenceType: old.referenceType,
              referenceId: old.referenceId,
              isRead: true,
              createdAt: old.createdAt,
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Lỗi đánh dấu đã đọc: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty || _notifications.every((n) => n.isRead)) return;

    // Hiển thị loading nhanh
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đang đánh dấu đã đọc tất cả...'),
        duration: Duration(milliseconds: 500),
      ),
    );

    try {
      await _notificationApi.markAllAsRead();
      _fetchNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await _notificationApi.deleteNotification(id);
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Không thể xóa thông báo: ${e.toString().replaceAll('Exception: ', '')}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().toUtc().difference(dateTime.toUtc());
    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  IconData _getIcon(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.account_balance_wallet_rounded;
      case 'system':
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return const Color(0xFFD4AF37); // Gold
      case 'system':
      default:
        return AppColors.primaryLight;
    }
  }

  Color _getIconBgColor(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return const Color(0xFFFCF8F2);
      case 'system':
      default:
        return AppColors.primary.withOpacity(0.06);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        title: const Text(
          'Thông báo',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_notifications.isNotEmpty && _notifications.any((n) => !n.isRead))
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(
                Icons.done_all_rounded,
                size: 18,
                color: AppColors.primaryLight,
              ),
              label: const Text(
                'Đọc tất cả',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.primaryLight,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchNotifications,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Thử lại',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _notifications.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.04),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: AppColors.primary.withOpacity(0.25),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Không có thông báo mới',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mọi cập nhật về trạng thái nạp VIP, gợi ý phối đồ hoặc ưu đãi sẽ hiển thị tại đây.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.primary.withOpacity(0.55),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: AppColors.primary,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _notifications.length,
                itemBuilder: (context, index) {
                  final item = _notifications[index];
                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      color: AppColors.error,
                      child: const Icon(
                        Icons.delete_sweep_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    onDismissed: (direction) => _deleteNotification(item.id),
                    child: _buildNotificationItem(item),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildNotificationItem(NotificationModel item) {
    return InkWell(
      onTap: () {
        _markAsRead(item);
        _showDetailsDialog(item);
      },
      child: Container(
        decoration: BoxDecoration(
          color: item.isRead
              ? Colors.transparent
              : AppColors.primary.withOpacity(0.02),
          border: Border(
            bottom: BorderSide(
              color: AppColors.primary.withOpacity(0.05),
              width: 0.8,
            ),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _getIconBgColor(item.type),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIcon(item.type),
                color: _getIconColor(item.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w700
                                : FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE45B62),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: item.isRead
                          ? AppColors.primary.withOpacity(0.65)
                          : AppColors.primary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatRelativeTime(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog(NotificationModel item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getIconBgColor(item.type),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIcon(item.type),
                  color: _getIconColor(item.type),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.body,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Thời gian: ${_formatTimeFull(item.createdAt)}',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeFull(DateTime dateTime) {
    final local = dateTime.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')} - ${local.day}/${local.month}/${local.year}';
  }
}
