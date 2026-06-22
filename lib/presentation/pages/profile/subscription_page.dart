import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/subscription_api_service.dart';
import '../../../data/datasources/ad_service.dart';
import '../../../data/datasources/signalr_service.dart';
import 'manual_payment_sheet.dart';
import 'survey_page.dart';
import 'payos_payment_page.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  static void showOutOfCreditsSheet(BuildContext context, {required bool isBgRemoval}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _OutOfCreditsSheet(isBgRemoval: isBgRemoval);
      },
    );
  }

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> with WidgetsBindingObserver {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _subscriptionApiService = GetIt.I<SubscriptionApiService>();

  List<SubscriptionPlan> _plans = [];
  List<PaymentTransaction> _transactions = [];
  bool _isLoadingPlans = true;
  bool _isLoadingTransactions = true;
  StreamSubscription<Map<String, dynamic>>? _paymentUpdateSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSubscriptionData();

    // Đăng ký lắng nghe cập nhật trạng thái thanh toán thời gian thực từ SignalR
    _paymentUpdateSubscription = SignalRService().onPaymentUpdate.listen((update) {
      if (!mounted) return;
      _handlePaymentUpdate(update);
    });
  }

  @override
  void dispose() {
    _paymentUpdateSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSubscriptionData();
    }
  }

  void _handlePaymentUpdate(Map<String, dynamic> update) {
    final status = update['status']?.toString();
    final message = update['message']?.toString() ?? 'Cập nhật trạng thái thanh toán mới.';

    if (status == 'success') {
      _showPaymentResultDialog(
        isSuccess: true,
        title: 'Thanh toán thành công',
        message: message,
      );
      _loadSubscriptionData();
    } else if (status == 'failed') {
      _showPaymentResultDialog(
        isSuccess: false,
        title: 'Thanh toán thất bại',
        message: message,
      );
      _loadSubscriptionData();
    }
  }

  void _showPaymentResultDialog({
    required bool isSuccess,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Icon(
                isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                color: isSuccess ? Colors.green : AppColors.error,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSuccess ? Colors.green : AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
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

  Future<void> _loadSubscriptionData() async {
    setState(() {
      _isLoadingPlans = true;
      _isLoadingTransactions = true;
    });

    try {
      await _subscriptionApiService.syncSubscriptionStatus();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Lỗi đồng bộ gói: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi đồng bộ: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    try {
      final plansList = await _subscriptionApiService.getPlans();
      setState(() {
        _plans = plansList;
        _isLoadingPlans = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingPlans = false;
      });
      debugPrint('Lỗi tải danh sách gói: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải gói: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }

    try {
      final transactionsList = await _subscriptionApiService.getTransactions();
      setState(() {
        _transactions = transactionsList;
        _isLoadingTransactions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTransactions = false;
      });
      debugPrint('Lỗi tải lịch sử giao dịch: $e');
    }
  }

  double _calculateOriginalPrice(double currentPrice, double discountRate) {
    if (discountRate <= 0 || discountRate >= 1) return currentPrice;
    final rawOriginal = currentPrice / (1 - discountRate);
    // Làm tròn lên hàng nghìn gần nhất (ví dụ: 148.750đ -> 149.000đ)
    return (rawOriginal / 1000).ceil() * 1000.0;
  }

  void _purchasePlan(SubscriptionPlan plan) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PaymentGatewaySelectorSheet(
          packageName: plan.name,
          price: plan.price,
          onSelected: (gateway) {
            Navigator.pop(sheetContext); // Close gateway selector
            _initiatePurchase(plan, gateway);
          },
        );
      },
    );
  }

  void _initiatePurchase(SubscriptionPlan plan, String gateway) async {
    if (gateway == 'manual_transfer') {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) {
          return ManualPaymentSheet(
            plan: plan,
            onSubmitSuccess: () {
              _loadSubscriptionData();
            },
          );
        },
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final paymentUrl = await _subscriptionApiService.purchase(plan.id, paymentGateway: gateway);
      if (!mounted) return;
      Navigator.pop(context); // Đóng loading dialog

      // Điều hướng tới trang thanh toán PayOS WebView
      if (gateway == 'payos') {
        final statusResult = await Navigator.push<String>(
          context,
          MaterialPageRoute(
            builder: (context) => PayOSPaymentPage(
              paymentUrl: paymentUrl,
              planName: plan.name,
            ),
          ),
        );

        if (statusResult == 'success') {
          _showPaymentResultDialog(
            isSuccess: true,
            title: 'Thanh toán thành công',
            message: 'Chúc mừng! Bạn đã đăng ký thành công gói "${plan.name}". Giao diện đang được cập nhật.',
          );
        } else if (statusResult == 'cancelled') {
          _showPaymentResultDialog(
            isSuccess: false,
            title: 'Thanh toán đã hủy',
            message: 'Giao dịch đăng ký gói "${plan.name}" đã bị hủy.',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang làm mới thông tin gói dịch vụ...'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
        
        await _loadSubscriptionData();
        return;
      }

      if (mounted) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) {
            return _PaymentVerificationSheet(
              packageName: plan.name,
              price: plan.price,
              paymentUrl: paymentUrl,
              gateway: gateway,
              onCheckStatus: () async {
                await _loadSubscriptionData();
              },
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Đóng loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPlan = _localStorage.getSubscriptionType();
    final hasActivePremium = _localStorage.getHasActivePremium();
    final bgCredits = _localStorage.getBgRemovalCredits();
    final tryonCredits = _localStorage.getTryOnCredits();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gói dịch vụ & Hạn mức',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Current status summary card
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hạn mức của bạn',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: !hasActivePremium
                              ? Colors.white.withOpacity(0.15)
                              : const Color(0xFFD4AF37),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          !hasActivePremium
                              ? 'GÓI MIỄN PHÍ'
                              : (currentPlan == 'monthly' || currentPlan == 'premium_monthly')
                                  ? 'PREMIUM THÁNG'
                                  : 'PREMIUM NĂM',
                          style: TextStyle(
                            color: !hasActivePremium ? Colors.white : AppColors.primaryDark,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _statusItem(
                          Icons.photo_filter_rounded,
                          'Xóa nền tự động',
                          '$bgCredits lượt',
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 40,
                        color: Colors.white24,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _statusItem(
                          Icons.auto_awesome_rounded,
                          'Thử đồ ảo AI',
                          '$tryonCredits lượt',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                padding: const EdgeInsets.all(4),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(
                    height: 38,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text('Gói Đăng Ký'),
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text('Nạp Lượt Thử'),
                    ),
                  ),
                  Tab(
                    height: 38,
                    child: Align(
                      alignment: Alignment.center,
                      child: Text('Lịch Sử'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tab contents
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlansTab(currentPlan, hasActivePremium),
                  _buildTopupTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _statusItem(IconData icon, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white70, size: 16),
            const SizedBox(width: 4),
            Text(
              title,
              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }

  Widget _buildPlansTab(String currentPlan, bool hasActivePremium) {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    try {
      final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

      return RefreshIndicator(
        onRefresh: _loadSubscriptionData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // FREE plan
            _planCard(
              title: 'Gói Miễn Phí (FREE)',
              price: '0 đ',
              period: 'Mặc định',
              isPremium: false,
              features: [
                'Tối đa 30 món đồ trong Tủ đồ số',
                '5 lượt xóa nền tự động / tháng',
                '5 lượt thử đồ AI thông minh / tháng',
                'Hiển thị quảng cáo biểu ngữ/video',
              ],
              buttonText: !hasActivePremium ? 'Đang sử dụng' : 'Gói mặc định',
              onPressed: null,
              isActive: !hasActivePremium,
            ),
            const SizedBox(height: 16),

            // Dynamic plans from BE (chỉ hiển thị các gói có phí và không phải gói lẻ)
            ..._plans.where((plan) {
              return plan.price > 0 && plan.durationDays != null;
            }).map((plan) {
              final formattedPrice = plan.price.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');
              final isMonthly = plan.durationDays! <= 30;
              // BE có thể trả planType dạng "monthly"/"yearly" hoặc "premium_monthly"/"premium_yearly"
              final isPlanActive = hasActivePremium && (
                isMonthly
                  ? (currentPlan == 'monthly' || currentPlan == 'premium_monthly')
                  : (currentPlan == 'yearly' || currentPlan == 'premium_yearly')
              );
              
              final discountRate = isMonthly ? 0.20 : 0.45;
              final discountPercent = isMonthly ? 'TIẾT KIỆM 20%' : 'TIẾT KIỆM 45%';
              final originalPriceVal = _calculateOriginalPrice(plan.price, discountRate);
              final formattedOriginalPrice = originalPriceVal.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _planCard(
                  title: plan.name,
                  price: '$formattedPrice đ',
                  period: ' / ${plan.durationDays} ngày',
                  isPremium: true,
                  isBestValue: isMonthly,
                  originalPrice: '$formattedOriginalPrice đ',
                  discountPercent: discountPercent,
                  features: plan.description != null && plan.description!.isNotEmpty
                      ? plan.description!
                          .split('.')
                          .map((e) => e.trim())
                          .where((e) => e.isNotEmpty)
                          .toList()
                      : isMonthly
                          ? [
                              'Không giới hạn tủ đồ số & canvas phối',
                              '30 lượt xóa nền tự động / tháng',
                              '30 lượt thử đồ AI / tháng',
                              'Không hiển thị quảng cáo (Ad-Free)',
                              'Ưu tiên tốc độ xử lý hàng đợi AI',
                            ]
                          : [
                              'Tương đương gói Premium Tháng',
                              'Cấp ngay 360 lượt xóa nền tự động',
                              'Cấp ngay 360 lượt thử đồ AI',
                              'Tiết kiệm chi phí lên đến 45%',
                              'Trải nghiệm sớm các tính năng AI mới',
                            ],
                  buttonText: isPlanActive ? 'Đang sử dụng' : 'Đăng ký ngay',
                  onPressed: isPlanActive
                      ? null
                      : () {
                          _purchasePlan(plan);
                        },
                  isActive: isPlanActive,
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in _buildPlansTab: $e\n$stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Lỗi hiển thị gói đăng ký',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTopupTab() {
    if (_isLoadingPlans) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    try {
      final topupPlans = _plans.where((plan) {
        return plan.durationDays == null && plan.price > 0;
      }).toList();

      if (topupPlans.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 64, color: AppColors.primary.withOpacity(0.2)),
              const SizedBox(height: 12),
              const Text(
                'Không tìm thấy gói cước lẻ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Vui lòng làm mới danh sách gói cước.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      }

      final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

      return RefreshIndicator(
        onRefresh: _loadSubscriptionData,
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 4),
              child: Text(
                'Hết lượt thử đồ trước kỳ hạn? Nạp thêm credits lẻ tức thì để tiếp tục sáng tạo phong cách không giới hạn.',
                style: TextStyle(
                  color: AppColors.primary.withOpacity(0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
            ...topupPlans.map((plan) {
              final formattedPrice = plan.price.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');
              
              int credits = plan.grantedTryOnCredits > 0 
                  ? plan.grantedTryOnCredits 
                  : (plan.grantedBgCredits > 0 ? plan.grantedBgCredits : 1);
              
              final unitCostValue = plan.price / credits;
              final unitCost = unitCostValue.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');

              final discountRate = credits == 10
                  ? 0.25
                  : credits == 25
                      ? 0.30
                      : 0.20;
              final discountPercentStr = credits == 10
                  ? '-25%'
                  : credits == 25
                      ? '-30%'
                      : '-20%';
              final originalPriceVal = _calculateOriginalPrice(plan.price, discountRate);
              final formattedOriginalPrice = originalPriceVal.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _topupCard(
                  title: plan.name,
                  price: '$formattedPrice đ',
                  unitCost: 'Chỉ $unitCost đ / lượt thử',
                  credits: credits,
                  description: plan.description ?? 'Hỗ trợ nạp nhanh cho nhu cầu phối đồ.',
                  isPopular: credits >= 25,
                  originalPrice: '$formattedOriginalPrice đ',
                  discountPercent: discountPercentStr,
                  onPressed: () {
                    _purchasePlan(plan);
                  },
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in _buildTopupTab: $e\n$stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Lỗi hiển thị gói cước lẻ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildTransactionsTab() {
    if (_isLoadingTransactions) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    try {
      if (_transactions.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history_rounded, size: 64, color: AppColors.primary.withOpacity(0.2)),
              const SizedBox(height: 12),
              const Text(
                'Chưa có giao dịch nào',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Các giao dịch thanh toán của bạn sẽ xuất hiện tại đây.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        );
      }

      final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');

      return RefreshIndicator(
        onRefresh: _loadSubscriptionData,
        color: AppColors.primary,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: _transactions.length,
          itemBuilder: (context, index) {
            try {
              final tx = _transactions[index];
              final formattedPrice = tx.amount.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');
              final isSuccess = tx.status == 'completed' || tx.status == 'success';
              final isPending = tx.status == 'pending';
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: AppColors.primary.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSuccess
                            ? Colors.green.withOpacity(0.08)
                            : isPending
                                ? Colors.orange.withOpacity(0.08)
                                : Colors.red.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSuccess
                            ? Icons.check_circle_outline_rounded
                            : isPending
                                ? Icons.pending_actions_rounded
                                : Icons.error_outline_rounded,
                        color: isSuccess
                            ? Colors.green
                            : isPending
                                ? Colors.orange
                                : Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tx.planName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cổng: ${tx.paymentGateway.toUpperCase()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Thời gian: ${tx.createdAt.toLocal().toString().substring(0, 16)}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '+$formattedPrice đ',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? Colors.green.withOpacity(0.08)
                                : isPending
                                    ? Colors.orange.withOpacity(0.08)
                                    : Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isSuccess
                                ? 'Thành công'
                                : isPending
                                    ? (tx.paymentGateway == 'manual_transfer' ? 'Chờ duyệt' : 'Chờ')
                                    : 'Thất bại',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSuccess
                                  ? Colors.green
                                  : isPending
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } catch (e, stack) {
              debugPrint('CRITICAL ERROR in Transactions itemBuilder: $e\n$stack');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text('Lỗi tải giao dịch: $e\n$stack', style: const TextStyle(color: Colors.red, fontSize: 10)),
              );
            }
          },
        ),
      );
    } catch (e, stack) {
      debugPrint('CRITICAL ERROR in _buildTransactionsTab: $e\n$stack');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Lỗi hiển thị lịch sử',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 8),
              Text(
                '$e',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _planCard({
    required String title,
    required String price,
    required String period,
    required bool isPremium,
    required List<String> features,
    required String buttonText,
    required VoidCallback? onPressed,
    bool isBestValue = false,
    bool isActive = false,
    String? originalPrice,
    String? discountPercent,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isActive
              ? AppColors.primary
              : isBestValue
                  ? const Color(0xFFD4AF37)
                  : AppColors.primary.withOpacity(0.08),
          width: isActive || isBestValue ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (isBestValue)
              PositionBar(
                text: 'BÁN CHẠY',
                color: const Color(0xFFD4AF37),
              ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'ĐANG SỬ DỤNG',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isPremium ? const Color(0xFF8B6508) : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (originalPrice != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          originalPrice,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (discountPercent != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEAEA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              discountPercent,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFEB5757),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: period,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 32, thickness: 0.8),
                  Column(
                    children: features.map((feature) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primaryLight,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                feature,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: onPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isActive
                            ? AppColors.primary.withOpacity(0.1)
                            : isPremium
                                ? const Color(0xFFD4AF37)
                                : AppColors.primary,
                        foregroundColor: isActive
                            ? AppColors.primary
                            : isPremium
                                ? AppColors.primaryDark
                                : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        buttonText,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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

  Widget _topupCard({
    required String title,
    required String price,
    required String unitCost,
    required int credits,
    required String description,
    required VoidCallback onPressed,
    bool isPopular = false,
    String? originalPrice,
    String? discountPercent,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.primary.withOpacity(0.08),
          width: isPopular ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isPopular)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'TIẾT KIỆM',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                if (originalPrice != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        originalPrice,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (discountPercent != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEAEA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            discountPercent,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFEB5757),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                ],
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: '   '),
                      TextSpan(
                        text: '($unitCost)',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.primary.withOpacity(0.6),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 0),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Mua',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class PositionBar extends StatelessWidget {
  final String text;
  final Color color;

  const PositionBar({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Transform.rotate(
        angle: pi / 4,
        child: Transform.translate(
          offset: const Offset(28, 14),
          child: Container(
            width: 120,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: color,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OutOfCreditsSheet extends StatefulWidget {
  final bool isBgRemoval;
  const _OutOfCreditsSheet({required this.isBgRemoval});

  @override
  State<_OutOfCreditsSheet> createState() => _OutOfCreditsSheetState();
}

class _OutOfCreditsSheetState extends State<_OutOfCreditsSheet> {
  final bool _isWatchingAd = false;
  final int _countdown = 5;

  void _watchAdForCredit() async {
    // Kiểm tra ad đã sẵn sàng chưa
    if (!AdService().isAdLoaded) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đang tải quảng cáo, vui lòng thử lại sau vài giây...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      // Load lại để lần sau có sẵn
      AdService().loadRewardedAd();
      return;
    }

    // Phát rewarded ad thật
    await AdService().showRewardedAd(
      onRewarded: (_) async {
        try {
          final rewardType = widget.isBgRemoval ? 'bg_removal' : 'try_on';
          await GetIt.I<SubscriptionApiService>().claimAdReward(rewardType);

          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Cảm ơn bạn! Đã cộng 1 lượt miễn phí.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Không thể nhận phần thưởng: $e'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      onFailed: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Quảng cáo chưa sẵn sàng, thử lại sau nhé.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
    );
  }

  void _doSurveyForCredits() async {
    final localStorage = GetIt.I<AuthLocalStorage>();
    final surveyUrl = localStorage.getSurveyUrl();

    // Mở trang khảo sát WebView và chờ nhận kết quả trả về
    final completed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => SurveyPage(surveyUrl: surveyUrl),
      ),
    );

    if (completed == true) {
      // Gọi API nhận thưởng
      try {
        // Show loading dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );

        await GetIt.I<SubscriptionApiService>().claimAdReward('survey');
        // Đồng bộ lại trạng thái gói dịch vụ để cập nhật local storage
        await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();

        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog
        Navigator.pop(context); // Close out-of-credits sheet
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Cảm ơn bạn đã đóng góp ý kiến! Đã cộng 3 lượt thử đồ AI miễn phí.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context); // Close loading dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể nhận phần thưởng: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleText = widget.isBgRemoval ? 'Hết lượt xóa nền!' : 'Hết lượt thử đồ AI!';
    final descText = widget.isBgRemoval
        ? 'Bạn đã sử dụng hết hạn mức xóa nền tự động trong tháng này. Hãy nâng cấp Premium hoặc xem quảng cáo để tiếp tục.'
        : 'Bạn đã sử dụng hết hạn mức thử đồ AI thông minh trong tháng này. Hãy nâng cấp Premium hoặc xem quảng cáo để tiếp tục.';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: _isWatchingAd
          ? SizedBox(
              height: 250,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 54),
                    const SizedBox(height: 16),
                    Text(
                      'Quảng cáo tài trợ V-Closet sẽ kết thúc sau $_countdown giây...',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Không tắt màn hình hoặc thoát ứng dụng',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),

                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),

                Text(
                  descText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // Button options
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close out-of-credits sheet
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Nâng cấp PREMIUM (Gói 30 lượt)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (widget.isBgRemoval) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: _watchAdForCredit,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ondemand_video_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Xem quảng cáo tài trợ (Nhận 1 lượt)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (!widget.isBgRemoval && !GetIt.I<AuthLocalStorage>().getHasCompletedSurvey()) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _doSurveyForCredits,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD4AF37),
                        side: const BorderSide(color: Color(0xFFD4AF37), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 18),
                      label: const Text(
                        'Làm khảo sát (Nhận 3 lượt thử miễn phí)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _PaymentVerificationSheet extends StatefulWidget {
  final String packageName;
  final double price;
  final String? paymentUrl;
  final String gateway;
  final Future<void> Function() onCheckStatus;

  const _PaymentVerificationSheet({
    required this.packageName,
    required this.price,
    this.paymentUrl,
    this.gateway = 'momo',
    required this.onCheckStatus,
  });

  @override
  State<_PaymentVerificationSheet> createState() => _PaymentVerificationSheetState();
}

class _PaymentVerificationSheetState extends State<_PaymentVerificationSheet> {
  bool _isChecking = false;

  void _verify() async {
    setState(() => _isChecking = true);
    await widget.onCheckStatus();
    if (mounted) {
      setState(() => _isChecking = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật trạng thái gói dịch vụ từ máy chủ.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedPrice = widget.price.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');
    final isVnPay = widget.gateway == 'vnpay';
    final brandColor = isVnPay ? const Color(0xFF005BAA) : const Color(0xFFA50064);
    final buttonText = isVnPay ? 'Mở thanh toán VNPay' : 'Mở ứng dụng Ví MoMo';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.payment_rounded, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Đang thực hiện thanh toán...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            isVnPay
                ? 'Bạn có thể quét mã QR dưới bằng điện thoại khác, hoặc bấm nút mở trang thanh toán VNPay dưới đây để thanh toán trên điện thoại này cho "${widget.packageName}" ($formattedPrice đ).'
                : 'Bạn có thể quét mã QR dưới bằng điện thoại khác, hoặc bấm nút mở ứng dụng MoMo dưới đây để thanh toán trên điện thoại này cho "${widget.packageName}" ($formattedPrice đ).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.6), height: 1.4),
          ),
          if (widget.paymentUrl != null && widget.paymentUrl!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withOpacity(0.08)),
              ),
              child: Column(
                children: [
                  Image.network(
                    'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=${Uri.encodeComponent(widget.paymentUrl!)}',
                    width: 150,
                    height: 150,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        width: 150,
                        height: 150,
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.qr_code_2_rounded, size: 60, color: AppColors.textMuted);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isVnPay
                        ? 'Quét mã để tới trang thanh toán VNPay'
                        : 'Quét mã để thanh toán nhanh qua MoMo hoặc Ngân hàng',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final Uri url = Uri.parse(widget.paymentUrl!);
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(buttonText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: brandColor,
                  side: BorderSide(color: brandColor, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isChecking ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isChecking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Tôi đã hoàn tất chuyển khoản', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _PaymentGatewaySelectorSheet extends StatelessWidget {
  final String packageName;
  final double price;
  final ValueChanged<String> onSelected;

  const _PaymentGatewaySelectorSheet({
    required this.packageName,
    required this.price,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final formatCurrency = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedPrice = price.toStringAsFixed(0).replaceAllMapped(formatCurrency, (Match m) => '${m[1]}.');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 48),
          const SizedBox(height: 16),
          const Text(
            'Chọn phương thức thanh toán',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng chọn cổng thanh toán để mua gói "$packageName" ($formattedPrice đ).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.primary.withOpacity(0.6), height: 1.4),
          ),
          const SizedBox(height: 24),
          _buildGatewayCard(
            context: context,
            gateway: 'payos',
            title: 'Cổng thanh toán PayOS',
            subtitle: 'Thanh toán tự động qua mã VietQR Ngân hàng hoặc thẻ ATM/Visa',
            iconColor: const Color(0xFFE25822),
            logoText: 'PayOS',
            logoBgColor: const Color(0xFFFFF5EE),
          ),
          const SizedBox(height: 12),
          _buildGatewayCard(
            context: context,
            gateway: 'manual_transfer',
            title: 'Chuyển khoản thủ công (VietQR)',
            subtitle: 'Chuyển khoản ngân hàng 24/7 bằng mã VietQR hoặc STK',
            iconColor: AppColors.primary,
            logoText: 'Bank',
            logoBgColor: AppColors.primary.withOpacity(0.08),
          ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy bỏ', style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildGatewayCard({
    required BuildContext context,
    required String gateway,
    required String title,
    required String subtitle,
    required Color iconColor,
    required String logoText,
    required Color logoBgColor,
  }) {
    return InkWell(
      onTap: () => onSelected(gateway),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.1), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: logoBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  logoText,
                  style: TextStyle(
                    color: iconColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.5),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.primary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
