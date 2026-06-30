import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'auth_local_storage.dart';
import '../../main.dart'; // Để sử dụng global navigatorKey
import '../../core/app_routes.dart';

class SignalRService {
  // Singleton pattern
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  HubConnection? _hubConnection;
  final _localStorage = GetIt.I<AuthLocalStorage>();

  // Stream để các widget lắng nghe số thông báo chưa đọc
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get onUnreadCountChanged => _unreadCountController.stream;

  // Stream để các widget lắng nghe thông báo mới (raw Map từ JSON)
  final _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onNewNotification =>
      _notificationController.stream;

  // Stream để các widget lắng nghe cập nhật trạng thái thanh toán mới
  final _paymentUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onPaymentUpdate =>
      _paymentUpdateController.stream;

  void initSignalR() {
    final token = _localStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint("SignalR: Không tìm thấy AccessToken để kết nối.");
      return;
    }

    final baseUrl = dotenv.get('API_URL');
    final userId = _localStorage.getUserId() ?? 0;
    // Đường dẫn NotificationHub trên Backend C#, cần truyền thêm userId lên query string
    final hubUrl = "$baseUrl/notificationHub?userId=$userId";

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(accessTokenFactory: () async => token),
        )
        .withAutomaticReconnect()
        .build();

    // Lắng nghe sự kiện "ForceLogout" từ Hub
    _hubConnection!.on("ForceLogout", (arguments) {
      final String message = (arguments != null && arguments.isNotEmpty)
          ? arguments.first.toString()
          : "Tài khoản của bạn vừa được đăng nhập từ một thiết bị khác.";
      _handleForceLogout(message);
    });

    // Lắng nghe sự kiện "ReceiveUnreadCount" — BE gửi số thông báo chưa đọc
    _hubConnection!.on("ReceiveUnreadCount", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final count = int.tryParse(arguments.first.toString()) ?? 0;
        debugPrint("SignalR: ReceiveUnreadCount = $count");
        _unreadCountController.add(count);
      }
    });

    // Lắng nghe sự kiện "ReceiveNotification" — BE gửi object thông báo mới
    _hubConnection!.on("ReceiveNotification", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final raw = arguments.first;
          final Map<String, dynamic> notification = (raw is Map)
              ? Map<String, dynamic>.from(raw)
              : {};
          debugPrint("SignalR: ReceiveNotification = $notification");
          _notificationController.add(notification);
        } catch (e) {
          debugPrint("SignalR: Lỗi parse ReceiveNotification: $e");
        }
      }
    });

    // Lắng nghe sự kiện "ReceivePaymentUpdate" — BE gửi cập nhật trạng thái thanh toán
    _hubConnection!.on("ReceivePaymentUpdate", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final raw = arguments.first;
          final Map<String, dynamic> update = (raw is Map)
              ? Map<String, dynamic>.from(raw)
              : {};
          debugPrint("SignalR: ReceivePaymentUpdate = $update");
          _paymentUpdateController.add(update);
        } catch (e) {
          debugPrint("SignalR: Lỗi parse ReceivePaymentUpdate: $e");
        }
      }
    });

    _startConnection();
  }

  Future<void> _startConnection() async {
    try {
      if (_hubConnection != null &&
          _hubConnection!.state == HubConnectionState.Disconnected) {
        await _hubConnection!.start();
        debugPrint("SignalR: Kết nối thành công tới Hub!");
      }
    } catch (e) {
      debugPrint("SignalR: Lỗi kết nối Hub: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      if (_hubConnection != null &&
          _hubConnection!.state != HubConnectionState.Disconnected) {
        await _hubConnection!.stop().timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () {
                debugPrint("SignalR: Ngắt kết nối Hub quá hạn (timeout).");
              },
            );
        debugPrint("SignalR: Đã ngắt kết nối Hub.");
      }
    } catch (e) {
      debugPrint("SignalR: Lỗi khi ngắt kết nối Hub: $e");
    }
  }

  void _handleForceLogout(String message) async {
    // Bước 1: Xóa Token / Clear Local Storage
    await _localStorage.clearSession();

    // Ngắt kết nối SignalR
    await disconnect();

    final context = navigatorKey.currentContext;
    if (context == null) return;

    // Bước 2: Hiển thị Dialog thông báo
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text(
                'Cảnh báo bảo mật',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(); // Đóng popup

                // Bước 3: Điều hướng văng ra màn hình Login và xóa sạch lịch sử
                navigatorKey.currentState?.pushNamedAndRemoveUntil(
                  AppRoutes.login,
                  (Route<dynamic> route) => false,
                );
              },
              child: const Text(
                'Đồng ý',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
