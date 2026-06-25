import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import 'personal_color_detail_page.dart';
import 'style_dna_quiz_page.dart';

class PersonalColorCheckPage extends StatefulWidget {
  const PersonalColorCheckPage({super.key});

  @override
  State<PersonalColorCheckPage> createState() => _PersonalColorCheckPageState();
}

class _PersonalColorCheckPageState extends State<PersonalColorCheckPage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();

  Future<void> _startColorCheck() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StyleDnaQuizPage(
          onCompleted: () {
            Navigator.pop(context);
          },
        ),
      ),
    );

    if (!mounted) return;
    if (_localStorage.getHasCompletedStyleQuiz()) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PersonalColorDetailPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _localStorage.getHasCompletedStyleQuiz();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF25252B),
                              ),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                            if (hasResult)
                              IconButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PersonalColorDetailPage(),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.history_rounded,
                                  color: Color(0xFF25252B),
                                  size: 28,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tìm màu sắc của tôi',
                              style: TextStyle(
                                color: Color(0xFF25252B),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Cùng xem màu sắc nào hợp với bạn nhất nhé.',
                              style: TextStyle(
                                color: Color(0xFF9A9AA2),
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 380,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          children: const [
                            _TonePreviewCard(
                              title: 'Đồng tông ấm',
                              subtitle: 'Xuân ấm · Thu ấm',
                              imagePath: 'assets/images/mau_nu_1.jpg',
                              backgroundColor: Color(0xFF704A34),
                              alignment: Alignment.centerLeft,
                            ),
                            SizedBox(width: 10),
                            _TonePreviewCard(
                              title: 'Đồng tông lạnh',
                              subtitle: 'Hè lạnh · Đông lạnh',
                              imagePath: 'assets/images/mau_nu_3.jpg',
                              backgroundColor: Color(0xFF5663FF),
                              alignment: Alignment.centerRight,
                            ),
                            SizedBox(width: 10),
                            _TonePreviewCard(
                              title: 'Tông trung tính',
                              subtitle: 'Dịu nhẹ · Dễ phối',
                              imagePath: 'assets/images/mau_nam_1.jpg',
                              backgroundColor: Color(0xFFC9B7A0),
                              alignment: Alignment.center,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _startColorCheck,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF242424),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              hasResult ? 'Kiểm tra lại' : 'Bắt đầu kiểm tra',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TonePreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color backgroundColor;
  final Alignment alignment;

  const _TonePreviewCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.backgroundColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: alignment,
            child: Image.asset(
              imagePath,
              height: double.infinity,
              width: 220,
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.person_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 92,
                );
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 24,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 18,
            right: 18,
            child: Row(
              children: [
                _miniSwatch(Colors.white.withOpacity(0.9)),
                _miniSwatch(AppColors.secondary),
                _miniSwatch(backgroundColor.withOpacity(0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSwatch(Color color) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.45)),
      ),
    );
  }
}
