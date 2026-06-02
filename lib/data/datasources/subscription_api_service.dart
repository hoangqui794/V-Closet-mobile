import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'api_service.dart';
import 'auth_local_storage.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String? description;
  final double price;
  final String currency;
  final int durationDays;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    required this.durationDays,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num? ?? 0.0).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      durationDays: json['durationDays'] as int? ?? 30,
      isActive: json['isActive'] as bool? ?? true,
    );
  }
}

class MySubscription {
  final bool hasActivePremium;
  final String? planName;
  final String? planType;
  final DateTime? expiresAt;
  final int daysRemaining;
  final int bgRemovalCredits;
  final int tryOnCredits;
  final int wardrobeItemCount;
  final int? wardrobeItemLimit;

  MySubscription({
    required this.hasActivePremium,
    this.planName,
    this.planType,
    this.expiresAt,
    required this.daysRemaining,
    required this.bgRemovalCredits,
    required this.tryOnCredits,
    required this.wardrobeItemCount,
    this.wardrobeItemLimit,
  });

  factory MySubscription.fromJson(Map<String, dynamic> json) {
    return MySubscription(
      hasActivePremium: json['hasActivePremium'] as bool? ?? false,
      planName: json['planName'] as String?,
      planType: json['planType'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      daysRemaining: json['daysRemaining'] as int? ?? 0,
      bgRemovalCredits: json['bgRemovalCredits'] as int? ?? 0,
      tryOnCredits: json['tryOnCredits'] as int? ?? 0,
      wardrobeItemCount: json['wardrobeItemCount'] as int? ?? 0,
      wardrobeItemLimit: json['wardrobeItemLimit'] as int?,
    );
  }
}

class PaymentTransaction {
  final String id;
  final String planName;
  final double amount;
  final String currency;
  final String paymentGateway;
  final String status;
  final String? gatewayTransactionId;
  final DateTime createdAt;

  PaymentTransaction({
    required this.id,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.paymentGateway,
    required this.status,
    this.gatewayTransactionId,
    required this.createdAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      paymentGateway: json['paymentGateway'] as String? ?? '',
      status: json['status'] as String? ?? '',
      gatewayTransactionId: json['gatewayTransactionId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class SubscriptionApiService {
  final ApiService _apiService;

  SubscriptionApiService(this._apiService);

  /// GET /api/subscriptions/plans
  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final response = await _apiService.get('/api/subscriptions/plans');
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data as List<dynamic>? ?? [];
        return list
            .map((json) => SubscriptionPlan.fromJson(json as Map<String, dynamic>))
            .where((plan) => plan.isActive)
            .toList();
      }
      throw Exception('Không thể lấy danh sách gói dịch vụ.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// GET /api/subscriptions/me (hoặc /api/users/me/subscription)
  Future<MySubscription> getMySubscription() async {
    try {
      final response = await _apiService.get('/api/subscriptions/me');
      if (response.statusCode == 200) {
        return MySubscription.fromJson(response.data as Map<String, dynamic>);
      }
      throw Exception('Không thể tải trạng thái gói dịch vụ của bạn.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Đồng bộ trạng thái và credits từ BE về SharedPreferences cục bộ
  Future<MySubscription> syncSubscriptionStatus() async {
    final mySub = await getMySubscription();
    final localStorage = GetIt.I<AuthLocalStorage>();

    // Luôn cập nhật hasActivePremium từ server — nguồn dữ liệu chính xác nhất
    await localStorage.saveHasActivePremium(mySub.hasActivePremium);

    final localPlan = localStorage.getSubscriptionType();
    final serverPlan = mySub.planType ?? 'free';

    if (localPlan != serverPlan) {
      // Đổi loại gói: Cấp phát credits mặc định cho gói mới
      int initialBg = 5;
      int initialTryOn = 5;

      if (serverPlan == 'premium_monthly') {
        initialBg = 30;
        initialTryOn = 30;
      } else if (serverPlan == 'premium_yearly') {
        initialBg = 360;
        initialTryOn = 360;
      }

      await localStorage.saveSubscription(serverPlan, initialBg, initialTryOn);
    } else {
      // Gói giữ nguyên: Cập nhật nếu server trả về giá trị thực tế > 0, nếu không giữ credits cũ
      int finalBg = localStorage.getBgRemovalCredits();
      int finalTryOn = localStorage.getTryOnCredits();

      if (mySub.bgRemovalCredits > 0) {
        finalBg = mySub.bgRemovalCredits;
      }
      if (mySub.tryOnCredits > 0) {
        finalTryOn = mySub.tryOnCredits;
      }

      await localStorage.saveSubscription(serverPlan, finalBg, finalTryOn);
    }

    return mySub;
  }

  /// GET /api/subscriptions/transactions
  Future<List<PaymentTransaction>> getTransactions() async {
    try {
      final response = await _apiService.get('/api/subscriptions/transactions');
      if (response.statusCode == 200) {
        final List<dynamic> list = response.data as List<dynamic>? ?? [];
        return list.map((json) => PaymentTransaction.fromJson(json as Map<String, dynamic>)).toList();
      }
      throw Exception('Không thể tải lịch sử giao dịch.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// POST /api/subscriptions/purchase
  /// Trả về URL thanh toán PayOS/MoMo/VNPay
  Future<String> purchase(String planId, {String paymentGateway = 'momo'}) async {
    try {
      final response = await _apiService.post(
        '/api/subscriptions/purchase',
        data: {
          'planId': planId,
          'paymentGateway': paymentGateway,
        },
      );
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        final paymentUrl = (data['payUrl'] ?? data['paymentUrl']) as String? ?? '';
        if (paymentUrl.isEmpty) {
          throw Exception('Không nhận được liên kết thanh toán từ hệ thống.');
        }
        return paymentUrl;
      }
      throw Exception('Khởi tạo giao dịch mua gói thất bại.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Phân tích lỗi từ Dio client
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
    return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra kết nối mạng.';
  }
}
