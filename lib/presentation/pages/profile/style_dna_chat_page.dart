import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/gemini_api_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../pages/profile/personal_color_profile.dart';

class StyleDnaChatPage extends StatefulWidget {
  final Map<String, dynamic> profileData;

  const StyleDnaChatPage({super.key, required this.profileData});

  @override
  State<StyleDnaChatPage> createState() => _StyleDnaChatPageState();
}

class _StyleDnaChatPageState extends State<StyleDnaChatPage> {
  final _localStorage = GetIt.I<AuthLocalStorage>();
  final _geminiService = GetIt.I<GeminiApiService>();
  final _wardrobeService = GetIt.I<WardrobeApiService>();

  final List<Map<String, String>> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<String> _wardrobeItemNames = [];
  bool _isLoading = false;
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // 1. Tải danh sách đồ trong tủ
    try {
      final items = await _wardrobeService.getItems();
      _wardrobeItemNames = items.map((i) => i.name).toList();
    } catch (e) {
      debugPrint('Lỗi tải tủ đồ: $e');
    }

    // 2. Thêm lời chào ban đầu từ AI Stylist
    final name = widget.profileData['displayName'] ?? widget.profileData['DisplayName'] ?? 'bạn';
    final helloMessage = 'Xin chào $name! Tôi là AI Stylist cá nhân của bạn. Dựa trên hồ sơ chiều cao, cân nặng, tông da và tủ đồ thực tế của bạn, tôi sẽ giúp bạn thiết kế những bộ cánh thời trang và cá nhân hóa nhất. Hôm nay bạn muốn mặc đồ đi đâu hay có câu hỏi gì cho tôi không?';
    
    setState(() {
      _messages.add({
        'role': 'model',
        'text': helloMessage,
      });
      _isLoading = false;
      _isInitLoaded = true;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    _textController.clear();
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
      });
      _isLoading = true;
    });
    _scrollToBottom();

    // Lấy thông tin Style DNA
    final skinTone = _localStorage.getSkinTone() ?? 'trung_binh';
    final colorPref = _localStorage.getColorPref() ?? 'trung_tinh';
    final personalColorProfile = PersonalColorProfile.resolve(
      skinTone: skinTone,
      colorPref: colorPref,
      stylePref: _localStorage.getStylePref(),
    );
    final suggestedColors = personalColorProfile.bestColors.map((swatch) => swatch.name).join(', ');

    // Gọi Gemini API
    try {
      final response = await _geminiService.chatStyle(
        messages: _messages,
        userDisplayName: widget.profileData['displayName']?.toString() ?? widget.profileData['DisplayName']?.toString() ?? 'Khách hàng',
        gender: widget.profileData['gender']?.toString() ?? widget.profileData['Gender']?.toString() ?? 'female',
        skinTone: skinTone,
        bodyType: _localStorage.getBodyType() ?? 'trung_binh',
        stylePref: _localStorage.getStylePref() ?? 'casual',
        suggestedColors: suggestedColors,
        heightCm: widget.profileData['heightCm'] != null ? double.tryParse(widget.profileData['heightCm'].toString()) : null,
        weightKg: widget.profileData['weightKg'] != null ? double.tryParse(widget.profileData['weightKg'].toString()) : null,
        country: widget.profileData['country']?.toString() ?? widget.profileData['Country']?.toString(),
        wardrobeItemNames: _wardrobeItemNames,
      );

      if (response != null) {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': response,
          });
        });
      } else {
        setState(() {
          _messages.add({
            'role': 'model',
            'text': 'Rất tiếc, tôi đang gặp lỗi kết nối với máy chủ AI. Bạn hãy thử lại sau nhé!',
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'model',
          'text': 'Đã xảy ra lỗi không mong muốn. Xin lỗi bạn vì sự bất tiện này.',
        });
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.profileData['heightCm']?.toString() ?? widget.profileData['HeightCm']?.toString();
    final weight = widget.profileData['weightKg']?.toString() ?? widget.profileData['WeightKg']?.toString();
    
    final stylePref = _localStorage.getStylePref() ?? 'casual';
    String stylePrefText = 'Casual';
    if (stylePref == 'cong_so') stylePrefText = 'Công sở';
    if (stylePref == 'streetwear') stylePrefText = 'Streetwear';
    if (stylePref == 'thanh_lich') stylePrefText = 'Thanh lịch';
    if (stylePref == 'sporty') stylePrefText = 'Sporty';

    // Tạo các gợi ý nhanh
    final List<String> suggestions = [
      'Gợi ý phối đồ đi đám cưới',
      if (height != null && weight != null) 'Tư vấn phối đồ cho người cao $height cm',
      'Tông da của tôi nên mặc màu gì?',
      'Tôi muốn phối đồ đi chơi cuối tuần',
      'Mặc gì đi làm phong cách $stylePrefText?',
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF8E94F2).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF8E94F2).withOpacity(0.25),
                  width: 1.2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF8E94F2),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'AI Stylist cá nhân',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Tư vấn trực tuyến · Đang hoạt động',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, 'go_to_studio'),
              icon: const Icon(Icons.auto_awesome_rounded, size: 12, color: Colors.white),
              label: const Text(
                'Thử đồ AI',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8E94F2),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isModel = msg['role'] == 'model';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment:
                        isModel ? MainAxisAlignment.start : MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isModel) ...[
                        Container(
                          width: 32,
                          height: 32,
                          margin: const EdgeInsets.only(right: 8, top: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E94F2).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF8E94F2).withOpacity(0.25),
                              width: 1.2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.forum_rounded,
                              color: Color(0xFF8E94F2),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isModel
                                ? const Color(0xFFF3F3F7)
                                : const Color(0xFF2C2A4A),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: isModel
                                  ? Radius.zero
                                  : const Radius.circular(18),
                              bottomRight: isModel
                                  ? const Radius.circular(18)
                                  : Radius.zero,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: MarkdownText(
                            text: msg['text'] ?? '',
                            style: TextStyle(
                              color: isModel ? const Color(0xFF1C1C1E) : Colors.white,
                              fontSize: 15,
                              height: 1.45,
                              fontWeight: isModel ? FontWeight.w500 : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading && _isInitLoaded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E94F2).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF8E94F2).withOpacity(0.25),
                        width: 1.2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.forum_rounded,
                        color: Color(0xFF8E94F2),
                        size: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'AI Stylist đang soạn câu trả lời...',
                          style: TextStyle(
                            color: Color(0xFF888890),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Gợi ý câu hỏi nhanh
          if (!_isLoading)
            Container(
              height: 48,
              margin: const EdgeInsets.only(top: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 8),
                    child: ActionChip(
                      onPressed: () => _sendMessage(suggestions[index]),
                      backgroundColor: Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFE2E2E6), width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      label: Text(
                        suggestions[index],
                        style: const TextStyle(
                          color: Color(0xFF484850),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          // Thanh nhập tin nhắn
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFEEEEF2), width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F7),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _textController,
                        style: const TextStyle(fontSize: 15),
                        textInputAction: TextInputAction.send,
                        onSubmitted: _sendMessage,
                        decoration: const InputDecoration(
                          hintText: 'Hỏi AI Stylist về cách phối đồ...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9A9AA2),
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _sendMessage(_textController.text),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF242424),
                      ),
                      child: const Icon(
                        Icons.send_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const MarkdownText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> children = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      bool isListItem = false;
      String lineContent = line;
      if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        isListItem = true;
        lineContent = trimmed.substring(2);
      } else if (trimmed.startsWith('• ')) {
        isListItem = true;
        lineContent = trimmed.substring(2);
      }

      final List<TextSpan> spans = [];
      final parts = lineContent.split('**');
      for (int i = 0; i < parts.length; i++) {
        final isBold = i % 2 == 1;
        spans.add(
          TextSpan(
            text: parts[i],
            style: isBold
                ? style.copyWith(fontWeight: FontWeight.bold, color: style.color)
                : style,
          ),
        );
      }

      final textWidget = RichText(
        text: TextSpan(
          children: spans,
        ),
      );

      if (isListItem) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: style.copyWith(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Expanded(child: textWidget),
              ],
            ),
          ),
        );
      } else {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: textWidget,
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
