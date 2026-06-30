import 'package:dio/dio.dart';
import 'api_service.dart';

class NotificationModel {
  final String id;
  final String type;
  final String title;
  final String body;
  final String? referenceType;
  final int? referenceId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.referenceType,
    this.referenceId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'System',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      referenceType: json['referenceType'] as String?,
      referenceId: json['referenceId'] as int?,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class NotificationApiService {
  final ApiService _apiService;

  NotificationApiService(this._apiService);

  /// Lấy danh sách thông báo của người dùng hiện tại
  Future<List<NotificationModel>> getNotifications({
    bool? isRead,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _apiService.get(
        '/api/notifications',
        queryParameters: {
          if (isRead != null) 'isRead': isRead,
          'page': page,
          'pageSize': pageSize,
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data as List<dynamic>? ?? [];
        return list
            .map(
              (json) =>
                  NotificationModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      }
      throw Exception('Không thể tải danh sách thông báo.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Lấy số lượng thông báo chưa đọc
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get('/api/notifications/unread-count');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['count'] as int? ?? 0;
      }
      throw Exception('Không thể tải số lượng thông báo chưa đọc.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Đánh dấu một thông báo là đã đọc
  Future<void> markAsRead(String id) async {
    try {
      final response = await _apiService.patch('/api/notifications/$id/read');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Không thể cập nhật trạng thái thông báo.');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Đánh dấu tất cả thông báo là đã đọc
  Future<void> markAllAsRead() async {
    try {
      final response = await _apiService.post('/api/notifications/read-all');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Không thể đánh dấu đọc tất cả thông báo.');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Xóa hoàn toàn một thông báo
  Future<void> deleteNotification(String id) async {
    try {
      final response = await _apiService.delete('/api/notifications/$id');
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Không thể xóa thông báo.');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Xóa hàng loạt thông báo được chọn
  Future<void> bulkDelete(List<String> ids) async {
    try {
      final response = await _apiService.post(
        '/api/notifications/bulk-delete',
        data: {'notificationIds': ids},
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Không thể xóa hàng loạt thông báo.');
      }
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Phân tích lỗi từ Dio
  String _getDioErrorMessage(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data != null) {
        if (data is Map) {
          if (data['message'] != null) return data['message'].toString();
          if (data['errors'] != null && data['errors'] is Map) {
            final errorsMap = data['errors'] as Map;
            final buffer = StringBuffer();
            errorsMap.forEach((key, value) {
              if (value is List) {
                buffer.writeln(value.join(', '));
              } else {
                buffer.writeln('$value');
              }
            });
            if (buffer.isNotEmpty) return buffer.toString().trim();
          }
        }
        if (data is String && data.isNotEmpty) return data;
      }
      return 'Lỗi hệ thống (${e.response?.statusCode}). Vui lòng thử lại sau.';
    }
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra lại mạng.';
  }
}
