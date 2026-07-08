import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../widgets/profile/style_dna_card.dart';
import 'style_dna_chat_page.dart';
import 'style_dna_quiz_page.dart';

class StyleDnaPage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final void Function(int index)? onNavigateTo;
  const StyleDnaPage({super.key, this.onMenuPressed, this.onNavigateTo});

  @override
  State<StyleDnaPage> createState() => _StyleDnaPageState();
}

class _StyleDnaPageState extends State<StyleDnaPage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _userService = GetIt.I<UserApiService>();

  Map<String, dynamic>? _profileData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    if (!_localStorage.getHasCompletedStyleQuiz()) return;
    setState(() => _isLoading = true);
    try {
      final profile = await _userService.getMyProfile();
      setState(() {
        _profileData = profile;
      });
    } catch (e) {
      debugPrint('Lỗi tải thông tin cá nhân trên trang Style DNA: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuiz = _localStorage.getHasCompletedStyleQuiz();
    final gender = _profileData?['gender']?.toString() ?? _profileData?['Gender']?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu_rounded, color: AppColors.brandText),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: const Text(
          'Phong cách',
          style: TextStyle(
            color: AppColors.brandText,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.brandText))
          : RefreshIndicator(
              color: AppColors.brandText,
              onRefresh: _fetchProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                child: Column(
                  children: [
                    if (!hasQuiz)
                      _buildNoQuizPanel()
                    else ...[
                      StyleDnaCard(
                        gender: gender,
                        onRefresh: _fetchProfileData,
                      ),
                      const SizedBox(height: 16),
                      _buildAiStylistCard(),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _retakeQuiz,
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'Làm lại trắc nghiệm',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.brandText,
                              side: const BorderSide(color: AppColors.brandText, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildNoQuizPanel() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.primary.withOpacity(0.08), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryLight, size: 64),
          const SizedBox(height: 18),
          const Text(
            'Khám phá Phong cách của bạn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khảo sát nhanh để AI phân tích màu tôn da và vóc dáng, gợi ý công thức phối đồ chuẩn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.primary.withOpacity(0.6),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _retakeQuiz,
              icon: const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Bắt đầu trắc nghiệm',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _retakeQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDnaQuizPage(
          onCompleted: () {
            Navigator.pop(context);
            _fetchProfileData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎉 Đã cập nhật Phong cách cá nhân thành công!'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAiStylistCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.aiGradientStart,
            AppColors.aiGradientEnd,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.aiGradientStart.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (_profileData == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đang tải dữ liệu hồ sơ của bạn... Hãy thử lại sau giây lát.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StyleDnaChatPage(profileData: _profileData!),
              ),
            );
            if (result == 'go_to_studio' && mounted) {
              widget.onNavigateTo?.call(4); // Chuyển sang tab Studio (Index 4)
            }
          },
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.3), width: 1),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.circle, color: Colors.greenAccent, size: 8),
                          SizedBox(width: 6),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.forum_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Trò chuyện với AI Stylist',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tư vấn phối đồ theo vóc dáng, màu tôn da và tủ đồ thực tế của bạn.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Trò chuyện ngay',
                            style: TextStyle(
                              color: AppColors.brandText,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.brandText,
                            size: 12,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
