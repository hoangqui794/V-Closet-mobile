import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'auth_local_storage.dart';

/// Service quản lý kết nối SignalR tới ChatHub (/hubs/chat).
/// 
/// Sử dụng:
///   // Khởi tạo kết nối (gọi 1 lần khi vào màn hình chat)
///   await ChatSignalRService().connect();
///
///   // Tham gia phòng chat
///   await ChatSignalRService().joinRoom(roomId);
///
///   // Lắng nghe tin nhắn mới
///   ChatSignalRService().onReceiveMessage.listen((msg) { ... });
///
///   // Rời phòng và ngắt kết nối khi dispose
///   await ChatSignalRService().leaveRoom(roomId);
///   await ChatSignalRService().disconnect();

class ChatSignalRService {
  // Singleton pattern
  static final ChatSignalRService _instance = ChatSignalRService._internal();
  factory ChatSignalRService() => _instance;
  ChatSignalRService._internal();

  HubConnection? _hubConnection;
  final _localStorage = GetIt.I<AuthLocalStorage>();

  // Stream broadcast: phát ra mỗi khi nhận tin nhắn mới từ Hub
  // Payload là Map<String, dynamic> tương ứng với ChatMessageResponseDto của BE
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get onReceiveMessage => _messageController.stream;

  bool get isConnected =>
      _hubConnection != null &&
      _hubConnection!.state == HubConnectionState.Connected;

  /// Khởi tạo & bắt đầu kết nối tới ChatHub
  Future<void> connect() async {
    // Nếu đã kết nối rồi thì không cần làm lại
    if (isConnected) return;

    final token = _localStorage.getAccessToken();
    if (token == null || token.isEmpty) {
      debugPrint("ChatSignalR: Không tìm thấy AccessToken.");
      return;
    }

    final baseUrl = dotenv.get('API_URL');
    final hubUrl = "$baseUrl/hubs/chat";

    _hubConnection = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => token,
          ),
        )
        .withAutomaticReconnect()
        .build();

    // Lắng nghe sự kiện "ReceiveMessage" từ ChatHub
    // BE gửi: _hubContext.Clients.Group(roomId).SendAsync("ReceiveMessage", chatMessageDto)
    _hubConnection!.on("ReceiveMessage", (arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        try {
          final raw = arguments.first;
          final Map<String, dynamic> message = (raw is Map)
              ? Map<String, dynamic>.from(raw)
              : {};
          debugPrint("ChatSignalR: ReceiveMessage = $message");
          _messageController.add(message);
        } catch (e) {
          debugPrint("ChatSignalR: Lỗi parse ReceiveMessage: $e");
        }
      }
    });

    try {
      await _hubConnection!.start();
      debugPrint("ChatSignalR: Kết nối thành công tới ChatHub!");
    } catch (e) {
      debugPrint("ChatSignalR: Lỗi kết nối ChatHub: $e");
    }
  }

  /// Tham gia phòng chat để nhận tin nhắn real-time của phòng đó
  /// Phải gọi sau khi connect() đã thành công
  Future<void> joinRoom(String roomId) async {
    if (!isConnected) {
      debugPrint("ChatSignalR: Chưa kết nối, không thể JoinRoom.");
      return;
    }
    try {
      await _hubConnection!.invoke("JoinRoom", args: [roomId]);
      debugPrint("ChatSignalR: Đã JoinRoom $roomId");
    } catch (e) {
      debugPrint("ChatSignalR: Lỗi JoinRoom: $e");
    }
  }

  /// Rời phòng chat (gọi khi dispose màn hình chat)
  Future<void> leaveRoom(String roomId) async {
    if (!isConnected) return;
    try {
      await _hubConnection!.invoke("LeaveRoom", args: [roomId]);
      debugPrint("ChatSignalR: Đã LeaveRoom $roomId");
    } catch (e) {
      debugPrint("ChatSignalR: Lỗi LeaveRoom: $e");
    }
  }

  /// Ngắt kết nối hoàn toàn khỏi ChatHub
  Future<void> disconnect() async {
    if (_hubConnection != null &&
        _hubConnection!.state != HubConnectionState.Disconnected) {
      await _hubConnection!.stop();
      debugPrint("ChatSignalR: Đã ngắt kết nối ChatHub.");
    }
  }
}
