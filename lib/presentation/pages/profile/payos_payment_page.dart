import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';

class PayOSPaymentPage extends StatefulWidget {
  final String paymentUrl;
  final String planName;

  const PayOSPaymentPage({
    super.key,
    required this.paymentUrl,
    required this.planName,
  });

  @override
  State<PayOSPaymentPage> createState() => _PayOSPaymentPageState();
}

class _PayOSPaymentPageState extends State<PayOSPaymentPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint("PayOS WebView Error: ${error.description}");
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            debugPrint("PayOS Navigation request to: $url");

            // 1. Bắt Custom Scheme Redirect từ PayOS
            if (url.startsWith('vcloset://')) {
              final uri = Uri.parse(url);
              final status = uri.queryParameters['status'] ?? 'unknown';
              debugPrint("PayOS Captured scheme status: $status");
              
              if (mounted) {
                Navigator.of(context).pop(status);
              }
              return NavigationDecision.prevent;
            }

            // 2. Bắt các deeplink mở app ngân hàng khác (vietqr://, bidvsmartbanking://,...)
            if (!url.startsWith('http://') && !url.startsWith('https://')) {
              try {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  debugPrint("PayOS Không thể mở deep link ngoài: $url");
                }
              } catch (e) {
                debugPrint("PayOS Lỗi mở deep link ngoài: $e");
              }
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.planName,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Text(
              'Thanh toán an toàn qua PayOS',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.primary),
          onPressed: () => Navigator.of(context).pop(), // Trả về null khi bấm nút đóng
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                value: _loadingProgress,
                backgroundColor: Colors.grey[200],
                color: AppColors.primary,
                minHeight: 3,
              ),
            ),
          if (_isLoading && _loadingProgress < 0.3)
            const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}
