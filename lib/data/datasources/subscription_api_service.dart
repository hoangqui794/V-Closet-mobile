import 'dart:io';
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
  final int? durationDays;
  final int grantedBgCredits;
  final int grantedTryOnCredits;
  final bool isActive;

  SubscriptionPlan({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.currency,
    this.durationDays,
    required this.grantedBgCredits,
    required this.grantedTryOnCredits,
    required this.isActive,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num? ?? 0.0).toDouble(),
      currency: json['currency'] as String? ?? 'VND',
      durationDays: json['durationDays'] as int?,
      grantedBgCredits: json['grantedBgCredits'] as int? ?? 0,
      grantedTryOnCredits: json['grantedTryOnCredits'] as int? ?? 0,
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
  final int outfitCount;
  final int? outfitLimit;

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
    required this.outfitCount,
    this.outfitLimit,
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
      outfitCount: json['outfitCount'] as int? ?? 0,
      outfitLimit: json['outfitLimit'] as int?,
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
    // Lưu số lượng đồ tủ đồ
    await localStorage.saveWardrobeItemCount(mySub.wardrobeItemCount);
    // Lưu số lượng outfit
    await localStorage.saveOutfitCount(mySub.outfitCount);
    await localStorage.saveOutfitLimit(mySub.outfitLimit);

    final serverPlan = mySub.planType ?? 'free';
    await localStorage.saveSubscription(serverPlan, mySub.bgRemovalCredits, mySub.tryOnCredits);

    return mySub;
  }

  /// POST /api/subscriptions/ad-reward
  /// Trả về MySubscription cập nhật mới
  Future<MySubscription> claimAdReward(String rewardType) async {
    try {
      final response = await _apiService.post(
        '/api/subscriptions/ad-reward',
        data: {'rewardType': rewardType},
      );
      if (response.statusCode == 200) {
        // Đồng bộ lại local storage sau khi nhận phần thưởng ad thành công
        return await syncSubscriptionStatus();
      }
      throw Exception('Không thể nhận phần thưởng từ quảng cáo.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
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

  /// Upload ảnh bill/chứng từ chuyển khoản lên BE
  Future<String> uploadPaymentProof(File imageFile) async {
    try {
      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiService.post(
        '/api/manual-payments/upload-proof',
        data: formData,
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return data['url'] as String;
      }
      throw Exception('Upload ảnh chứng từ thất bại.');
    } on DioException catch (e) {
      throw Exception(_getDioErrorMessage(e));
    }
  }

  /// Nộp chứng từ thanh toán chuyển khoản thủ công
  Future<Map<String, dynamic>> submitManualPayment({
    required String planId,
    required String proofImageUrl,
    String? userNote,
  }) async {
    try {
      final response = await _apiService.post(
        '/api/manual-payments/submit',
        data: {
          'planId': planId,
          'proofImageUrl': proofImageUrl,
          'userNote': userNote,
        },
      );
      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      throw Exception('Nộp chứng từ chuyển khoản thất bại.');
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
