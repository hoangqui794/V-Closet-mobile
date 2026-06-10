import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/outfit_api_service.dart';
import '../../../data/datasources/tryon_api_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/ad_service.dart';
import '../../../domain/entities/clothing_item.dart';
import '../profile/subscription_page.dart';

class OutfitPage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const OutfitPage({super.key, this.onMenuPressed});

  @override
  State<OutfitPage> createState() => _OutfitPageState();
}

class _OutfitPageState extends State<OutfitPage> with TickerProviderStateMixin {
  final TryOnApiService _tryOnApiService = GetIt.I<TryOnApiService>();
  final WardrobeApiService _wardrobeApiService = GetIt.I<WardrobeApiService>();
  final OutfitApiService _outfitApiService = GetIt.I<OutfitApiService>();
  final ImagePicker _picker = ImagePicker();



  // Selected state
  String? _selectedModelUrl;
  File? _selectedModelFile;
  final List<ClothingItem> _selectedGarments = [];
  String _selectedCategory = 'auto'; // auto, tops, bottoms, one-pieces
  bool _restoreBackground = true;

  // Selected saved outfit snapshot as garment
  String? _selectedOutfitSnapshotUrl;  // URL ảnh snapshot bộ phối đồ đã chọn
  String? _selectedOutfitTitle;         // Tên bộ phối đồ đã chọn

  // Wardrobe list state
  List<ClothingItem> _wardrobeItems = [];
  bool _isLoadingWardrobe = true;
  String _wardrobeFilter = 'Tất cả';

  // Saved outfits state (for section 2 outfit picker)
  List<Map<String, dynamic>> _savedOutfits = [];
  bool _isLoadingOutfits = true;

  // AI Generation State
  bool _isGenerating = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _predictionId;
  String? _resultUrl;
  String _loadingMessage = 'Đang khởi tạo AI...';
  String? _errorMessage;
  bool _isSavingImage = false;

  // Scanning Animation
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  // Pre-defined sample models – full-body shots
  final List<Map<String, String>> _sampleModels = [
    {
      'name': 'Mẫu Nữ 1',
      'url': 'assets/images/mau_nu_1.jpg',
      'gender': 'female'
    },
    {
      'name': 'Mẫu Nữ 2',
      'url': 'assets/images/mau_nu_2.jpg',
      'gender': 'female'
    },
    {
      'name': 'Mẫu Nữ 3',
      'url': 'assets/images/mau_nu_3.jpg',
      'gender': 'female'
    },
    {
      'name': 'Mẫu Nam 1',
      'url': 'assets/images/mau_nam_1.jpg',
      'gender': 'male'
    },
    {
      'name': 'Mẫu Nam 2',
      'url': 'assets/images/mau_nam_2.jpg',
      'gender': 'male'
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchWardrobe();
    _fetchSavedOutfits();

    // Setup scanning animation
    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _scanController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _scanController.forward();
        }
      });

    // Default select first model
    _selectedModelUrl = _sampleModels[0]['url'];
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _fetchWardrobe() async {
    setState(() => _isLoadingWardrobe = true);
    try {
      final items = await _wardrobeApiService.getItems();
      setState(() {
        _wardrobeItems = items;
        _isLoadingWardrobe = false;
      });
    } catch (e) {
      setState(() => _isLoadingWardrobe = false);
      debugPrint('Lỗi tải tủ đồ: $e');
    }
  }

  Future<void> _fetchSavedOutfits() async {
    setState(() => _isLoadingOutfits = true);
    try {
      final outfits = await _outfitApiService.getUserOutfits();
      setState(() {
        _savedOutfits = outfits;
        _isLoadingOutfits = false;
      });
    } catch (e) {
      setState(() => _isLoadingOutfits = false);
      debugPrint('Lỗi tải bộ phối đồ: $e');
    }
  }

  Future<void> _refreshAllData() async {
    await Future.wait([_fetchWardrobe(), _fetchSavedOutfits()]);
  }

  // Pick custom model photo
  Future<void> _pickModelImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() {
        _selectedModelFile = File(file.path);
        _selectedModelUrl = null; // Clear sample selection
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  void _showModelUploadGuidelines() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Lưu ý chọn ảnh người mẫu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Illustration comparison row (Nên vs Không nên)
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.green.shade50.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.shade200, width: 1),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.accessibility_new_rounded, size: 36, color: Colors.green.shade700),
                              const SizedBox(height: 6),
                              const Text(
                                'Chuẩn chính diện',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đứng thẳng, rõ thân',
                                style: TextStyle(fontSize: 9, color: Colors.green.shade800),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade200, width: 1),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_rounded, size: 36, color: Colors.red.shade700),
                              const SizedBox(height: 6),
                              Text(
                                'Không nên chọn',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nghiêng, bị che khuất',
                                style: TextStyle(fontSize: 9, color: Colors.red.shade800),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(Icons.cancel_rounded, color: Colors.red, size: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Detailed text guidelines
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                            children: [
                              TextSpan(text: 'Nên: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              TextSpan(text: 'Chọn ảnh chụp chính diện, đứng thẳng, rõ thân người. Mặc quần áo ôm sát sườn hoặc thon gọn (áo phông mỏng, quần/váy ôm).'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
                            children: [
                              TextSpan(text: 'Tránh: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              TextSpan(text: 'Ảnh đứng nghiêng/chụp xéo góc, tay khoanh trước ngực, tay che người hoặc tay đút túi. Không mặc quần áo quá phồng, quá rộng hoặc áo khoác phao dày.'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Camera / Gallery Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickModelImage(ImageSource.camera);
                    },
                    icon: const Icon(Icons.camera_alt_rounded, color: AppColors.primaryLight, size: 18),
                    label: const Text(
                      'Chụp ảnh mới',
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickModelImage(ImageSource.gallery);
                    },
                    icon: const Icon(Icons.photo_library_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Chọn từ thư viện',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Timer helper
  void _startTimer() {
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
        // Update messages based on duration
        if (_elapsedSeconds < 4) {
          _loadingMessage = 'Đang phân tích phom dáng hình thể...';
        } else if (_elapsedSeconds < 8) {
          _loadingMessage = 'Đang tách nền trang phục sản phẩm...';
        } else if (_elapsedSeconds < 12) {
          _loadingMessage = 'Đang mặc thử trang phục lên mô hình...';
        } else {
          _loadingMessage = 'AI đang căn chỉnh chi tiết cuối cùng...';
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  void _toggleGarmentSelection(ClothingItem item) {
    setState(() {
      final isSelected = _selectedGarments.any((g) => g.id == item.id);

      if (isSelected) {
        // Bỏ chọn
        _selectedGarments.removeWhere((g) => g.id == item.id);
      } else {
        // Thêm vào danh sách – cho phép chọn nhiều món đồ tự do
        _selectedGarments.add(item);
      }

      // Auto-set the best Fashn AI tryon category
      final selectedCats = _selectedGarments.map((g) => g.category.toLowerCase()).toList();
      if (selectedCats.contains('dress')) {
        _selectedCategory = 'one-pieces';
      } else if (selectedCats.contains('top') && selectedCats.contains('bottom')) {
        _selectedCategory = 'auto';
      } else if (selectedCats.contains('top')) {
        _selectedCategory = 'tops';
      } else if (selectedCats.contains('bottom')) {
        _selectedCategory = 'bottoms';
      } else {
        _selectedCategory = 'auto';
      }
    });
  }

  Future<Uint8List> _generateCollageBytes({List<ClothingItem>? targetItems}) async {
    final itemsToUse = targetItems ?? _selectedGarments;
    final dio = Dio();
    final Map<String, ui.Image> decodedImages = {};
    
    for (final item in itemsToUse) {
      try {
        final url = item.originalImageUrl ?? item.imageUrl;
        final response = await dio.get(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = response.data as List<int>;
        
        final codec = await ui.instantiateImageCodec(Uint8List.fromList(bytes));
        final frame = await codec.getNextFrame();
        decodedImages[item.id] = frame.image;
      } catch (e) {
        debugPrint('Lỗi tải/giải mã ảnh ${item.name}: $e');
      }
    }
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasWidth = 600.0;
    const canvasHeight = 800.0;
    
    // Fill background
    final paintBg = Paint()..color = const Color(0xFFF3F3F3);
    canvas.drawRect(const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight), paintBg);
    
    // Draw each item based on its category
    for (final item in itemsToUse) {
      final img = decodedImages[item.id];
      if (img == null) continue;
      
      final targetRect = _targetRectForCategory(item.category.toLowerCase());
      
      _paintImageFit(canvas, img, targetRect);
    }
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(canvasWidth.toInt(), canvasHeight.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Rect _targetRectForCategory(String category) {
    if (category == 'top') {
      return const Rect.fromLTWH(50, 50, 220, 280);
    }
    if (category == 'outerwear') {
      return const Rect.fromLTWH(330, 50, 220, 280);
    }
    if (category == 'bottom') {
      return const Rect.fromLTWH(50, 380, 220, 380);
    }
    if (category == 'dress') {
      return const Rect.fromLTWH(50, 80, 220, 550);
    }
    if (category == 'bag') {
      return const Rect.fromLTWH(330, 380, 220, 200);
    }
    if (category == 'shoes') {
      return const Rect.fromLTWH(330, 600, 220, 160);
    }
    return const Rect.fromLTWH(330, 200, 220, 220);
  }

  void _paintImageFit(Canvas canvas, ui.Image img, Rect rect) {
    final double srcWidth = img.width.toDouble();
    final double srcHeight = img.height.toDouble();
    
    final double destWidth = rect.width;
    final double destHeight = rect.height;
    
    final double scale = (destWidth / srcWidth < destHeight / srcHeight)
        ? destWidth / srcWidth
        : destHeight / srcHeight;
        
    final double w = srcWidth * scale;
    final double h = srcHeight * scale;
    
    final double x = rect.left + (destWidth - w) / 2;
    final double y = rect.top + (destHeight - h) / 2;
    
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, srcWidth, srcHeight),
      Rect.fromLTWH(x, y, w, h),
      Paint()..isAntiAlias = true,
    );
  }

  // Start Virtual Tryon Process
  Future<void> _startTryOn() async {
    if (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn trang phục để thử.')),
      );
      return;
    }

    final bool isMultiGarment = _selectedGarments.length > 1;

    // Kiểm tra Credits trước khi thực hiện (mỗi lần thử đồ AI chỉ tốn 1 lượt)
    final localStorage = GetIt.I<AuthLocalStorage>();
    final tryonCredits = localStorage.getTryOnCredits();
    if (tryonCredits < 1) {
      SubscriptionPage.showOutOfCreditsSheet(context, isBgRemoval: false);
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _resultUrl = null;
      _loadingMessage = 'Đang khởi tạo AI...';
    });

    _scanController.forward();
    _startTimer();

    try {
      final dio = Dio();
      dio.options.baseUrl = GetIt.I<Dio>().options.baseUrl;
      String? modelUrlToUse = _selectedModelUrl;

      // Check if we need to run via the files upload API
      final bool isCustomModel = _selectedModelFile != null;
      final bool isOutfitSnapshot = _selectedOutfitSnapshotUrl != null;
      final bool isLocalModel = modelUrlToUse != null && modelUrlToUse.startsWith('assets/');

      if (isMultiGarment || isCustomModel || isOutfitSnapshot || isLocalModel) {
        // We will call the /api/TryOn/run-files endpoint using FormData
        
        // 1. Prepare model file bytes
        List<int> modelBytes;
        String modelFilename;
        
        if (isCustomModel) {
          setState(() => _loadingMessage = 'Đang chuẩn bị ảnh người mẫu của bạn...');
          modelBytes = await _selectedModelFile!.readAsBytes();
          final pathLower = _selectedModelFile!.path.toLowerCase();
          final ext = pathLower.endsWith('.png') ? '.png' : '.jpg';
          modelFilename = 'model$ext';
        } else if (isLocalModel) {
          setState(() => _loadingMessage = 'Đang tải người mẫu từ ứng dụng...');
          final ByteData data = await rootBundle.load(modelUrlToUse);
          modelBytes = data.buffer.asUint8List();
          modelFilename = modelUrlToUse.split('/').last;
        } else {
          setState(() => _loadingMessage = 'Đang tải thông tin người mẫu...');
          final modelResponse = await dio.get(
            modelUrlToUse!,
            options: Options(responseType: ResponseType.bytes),
          );
          modelBytes = modelResponse.data as List<int>;
          modelFilename = 'model.png';
        }

        // 2. Prepare garment file bytes
        List<int> garmentBytes;
        if (isOutfitSnapshot) {
          setState(() => _loadingMessage = 'Đang tải ảnh bộ phối đồ...');
          final snapshotResponse = await dio.get(
            _selectedOutfitSnapshotUrl!,
            options: Options(responseType: ResponseType.bytes),
          );
          garmentBytes = snapshotResponse.data as List<int>;
        } else if (isMultiGarment) {
          setState(() => _loadingMessage = 'Đang ghép ảnh phối đồ (Flat Lay)...');
          garmentBytes = await _generateCollageBytes();
        } else {
          setState(() => _loadingMessage = 'Đang tải thông tin trang phục...');
          final garment = _selectedGarments.first;
          final garmentResponse = await dio.get(
            garment.originalImageUrl ?? garment.imageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          garmentBytes = garmentResponse.data as List<int>;
        }

        // 3. Upload and trigger prediction
        setState(() => _loadingMessage = 'Đang gửi dữ liệu phối đồ lên Cloud...');
        
        final uploadFormData = FormData.fromMap({
          "modelFile": MultipartFile.fromBytes(
            modelBytes,
            filename: modelFilename,
          ),
          "garmentFile": MultipartFile.fromBytes(
            garmentBytes,
            filename: 'garment.png',
          ),
          "category": _selectedCategory,
          "restoreBackground": _restoreBackground.toString(),
        });
        
        final response = await GetIt.I<Dio>().post(
          '/api/tryon/run-files',
          data: uploadFormData,
        );
        
        if (response.statusCode == 200 && response.data != null) {
          _predictionId = response.data['predictionId'] as String?;
          // Trừ 1 credit thử đồ AI
          await localStorage.updateCredits(tryonCredits: tryonCredits - 1);
        } else {
          throw Exception('Lỗi khởi tạo tiến trình thử đồ phối.');
        }
      } else {
        // Single garment, sample model: use fast run-wardrobe API
        setState(() => _loadingMessage = 'Đang gửi yêu cầu phối đồ...');
        final garment = _selectedGarments.first;
        _predictionId = await _tryOnApiService.runTryOnWithWardrobe(
          wardrobeItemId: garment.id,
          modelUrl: modelUrlToUse,
          category: _selectedCategory,
          restoreBackground: _restoreBackground,
        );
        // Trừ 1 credit thử đồ AI
        await localStorage.updateCredits(tryonCredits: tryonCredits - 1);
      }

      if (_predictionId == null) {
        throw Exception('Không nhận được ID tiến trình từ máy chủ AI.');
      }

      // 2. Start polling for status
      _pollStatus();
    } catch (e) {
      _stopTimer();
      _scanController.stop();
      String msg = e.toString();
      if (e is DioException) {
        if (e.response?.statusCode == 413) {
          msg = 'Dung lượng ảnh quá lớn (giới hạn 30MB). Vui lòng chọn hoặc chụp ảnh nhẹ hơn.';
        } else {
          final errorData = e.response?.data;
          if (errorData is Map) {
            if (errorData.containsKey('error')) {
              msg = errorData['error'].toString();
            } else if (errorData.containsKey('message')) {
              msg = errorData['message'].toString();
            }
          } else if (errorData != null) {
            final errorStr = errorData.toString();
            if (errorStr.contains('<html') || errorStr.contains('<!DOCTYPE html>')) {
              msg = 'Máy chủ AI tạm thời không phản hồi. Vui lòng thử lại sau.';
            } else {
              msg = errorStr;
              if (msg.length > 250) {
                msg = '${msg.substring(0, 250)}...';
              }
            }
          }
        }
      }
      debugPrint('Try-on exception: $e');
      debugPrint('Try-on error message: $msg');
      setState(() {
        _isGenerating = false;
        _errorMessage = msg;
      });
    }
  }

  // Polling helper
  Future<void> _pollStatus() async {
    if (_predictionId == null) return;

    int pollCount = 0;
    const maxPolls = 30; // 30 tries * 3s = 90s timeout

    Timer.periodic(const Duration(seconds: 3), (timer) async {
      pollCount++;
      if (!_isGenerating) {
        timer.cancel();
        return;
      }

      if (pollCount > maxPolls) {
        timer.cancel();
        _stopTimer();
        _scanController.stop();
        setState(() {
          _isGenerating = false;
          _errorMessage = 'Thời gian xử lý quá lâu. Vui lòng thử lại sau.';
        });
        return;
      }

      try {
        final result = await _tryOnApiService.checkStatus(_predictionId!);
        if (result == null) return;

        final status = result['status'] as String;
        final outputUrl = result['outputUrl'] as String?;
        final error = result['error'] as String?;

        if (status == 'completed' && outputUrl != null) {
          timer.cancel();
          _stopTimer();
          _scanController.stop();
          AdService().showInterstitialAd(
            onDismissed: () {
              if (mounted) {
                setState(() {
                  _isGenerating = false;
                  _resultUrl = outputUrl;
                });
              }
            },
          );
        } else if (status == 'failed' || error != null) {
          timer.cancel();
          _stopTimer();
          _scanController.stop();
          debugPrint('Try-on failed error: $error');
          setState(() {
            _isGenerating = false;
            _errorMessage = 'Thử đồ thất bại do lỗi xử lý AI. Vui lòng thử lại sau.';
          });
        }
      } catch (e) {
        debugPrint('Lỗi kiểm tra trạng thái: $e');
      }
    });
  }

  // Save AI Try-On image to mobile gallery
  Future<void> _saveImageToGallery(String imageUrl) async {
    setState(() => _isSavingImage = true);
    
    // Show download starting SnackBar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang lưu hình ảnh vào Thư viện của bạn...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final dio = Dio();
      final response = await dio.get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data as List<int>),
        quality: 100,
        name: "vcloset_tryon_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result != null && result['isSuccess'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lưu thành công! Đã lưu ảnh thử đồ ảo vào Thư viện.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result?['errorMessage'] ?? 'Không thể lưu ảnh vào thư viện.');
      }
    } catch (e) {
      debugPrint('Save image exception: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lưu ảnh thất bại. Vui lòng thử lại sau.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingImage = false);
      }
    }
  }

  // Filtered wardrobe list
  List<ClothingItem> get _filteredGarments {
    if (_wardrobeFilter == 'Tất cả') {
      // Filter out non-wearables like bags and shoes for standard tryon
      return _wardrobeItems.where((item) {
        final cat = item.category.toLowerCase();
        return cat == 'top' || cat == 'bottom' || cat == 'dress' || cat == 'outerwear' || cat == 'other';
      }).toList();
    }
    
    final Map<String, String> filterMap = {
      'Áo': 'top',
      'Quần/Váy': 'bottom',
      'Đầm/Váy liền': 'dress',
      'Áo khoác': 'outerwear',
      'Khác': 'other',
    };
    
    final targetCat = filterMap[_wardrobeFilter];
    return _wardrobeItems.where((item) => item.category.toLowerCase() == targetCat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leadingWidth: 74,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Center(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () {
                  final scaffold = Scaffold.maybeOf(context);
                  if (scaffold != null && scaffold.hasDrawer) {
                    scaffold.openDrawer();
                  } else {
                    widget.onMenuPressed?.call();
                  }
                },
                icon: const Icon(
                  Icons.menu_rounded,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
        title: const Text(
          'Studio Phối Đồ AI',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: _buildVirtualTryOnRoom(),
      ),
    );
  }

  // ================= TAB 1: VIRTUAL TRY-ON ROOM =================

  Widget _buildVirtualTryOnRoom() {
    if (_isGenerating) {
      return _buildScanningState();
    }

    if (_resultUrl != null) {
      return _buildResultState();
    }

    return RefreshIndicator(
      onRefresh: _refreshAllData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

  
            // 1. SELECT MODEL IMAGE
            _sectionHeader('1. Chọn người mẫu thử đồ'),
            const SizedBox(height: 12),
            _buildModelSelector(),
            const SizedBox(height: 24),
  
            // 2. SELECT WARDROBE ITEM
            _sectionHeader('2. Chọn quần áo từ tủ đồ hoặc trang phục'),
            const SizedBox(height: 10),
            _buildOutfitPicker(),
            const SizedBox(height: 12),
            _buildGarmentSelector(),
            _buildSelectedGarmentsPreview(),
            const SizedBox(height: 24),
  
            // 3. OPTIONS
            _sectionHeader('3. Cấu hình AI'),
            const SizedBox(height: 12),
            _buildTryOnConfig(),
            const SizedBox(height: 20),
            _buildTryOnNotes(),
            const SizedBox(height: 24),
  
            // ACTION BUTTON
            FadeInUp(
              child: Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null)
                        ? [Colors.grey.shade400, Colors.grey.shade400] 
                        : [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null) ? [] : [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null) ? null : _startTryOn,
                  icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                  label: const Text(
                    'Bắt đầu thử đồ ảo AI',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildModelSelector() {
    return SizedBox(
      height: 130,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // ADD CUSTOM BUTTON
          GestureDetector(
            onTap: _showModelUploadGuidelines,
            child: Container(
              width: 88,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _selectedModelFile != null ? AppColors.primaryLight : Colors.grey.shade300,
                  width: _selectedModelFile != null ? 2.5 : 1,
                ),
              ),
              child: _selectedModelFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_selectedModelFile!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 28),
                        SizedBox(height: 6),
                        Text('Tải ảnh\ncủa bạn', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, height: 1.3), textAlign: TextAlign.center),
                      ],
                    ),
            ),
          ),

          // PRE-DEFINED SAMPLE MODELS
          ..._sampleModels.map((model) {
            final isSelected = _selectedModelUrl == model['url'] && _selectedModelFile == null;
            final isFemale = model['gender'] == 'female';
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedModelUrl = model['url'];
                  _selectedModelFile = null;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 88,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryLight : Colors.grey.shade200,
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ] : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      model['url']!.startsWith('assets/')
                          ? Image.asset(
                              model['url']!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                            )
                          : Image.network(
                              model['url']!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey.shade100,
                                  child: const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey.shade100,
                                child: const Center(child: Icon(Icons.person, color: Colors.grey, size: 36)),
                              ),
                            ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isFemale ? Icons.female_rounded : Icons.male_rounded,
                                color: isFemale ? Colors.pinkAccent : Colors.lightBlueAccent,
                                size: 12,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                model['name']!,
                                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 6,
                          right: 6,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                          ),
                        )
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─── Saved Outfit Picker (section 2) ─────────────────────────────────────
  Widget _buildOutfitPicker() {
    // Loading state
    if (_isLoadingOutfits) {
      return const SizedBox(
        height: 108,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    // Empty state
    if (_savedOutfits.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.style_outlined, color: Colors.grey.shade400, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chưa có trang phục nào',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text('Tạo trang phục trong tab Tủ đồ trước',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Outfit cards
    return FadeInLeft(
      duration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.style_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
              const Text(
                'Chọn từ trang phục đã lưu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
              const Spacer(),
              if (_selectedOutfitSnapshotUrl != null)
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedOutfitSnapshotUrl = null;
                    _selectedOutfitTitle = null;
                  }),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close_rounded, size: 13, color: Colors.red.shade400),
                      const SizedBox(width: 2),
                      Text('Bỏ chọn', style: TextStyle(fontSize: 11, color: Colors.red.shade400, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _savedOutfits.length,
              itemBuilder: (context, index) {
                final outfit = _savedOutfits[index];
                final snapshotUrl = outfit['CanvasSnapshotUrl'] as String? ??
                    outfit['canvasSnapshotUrl'] as String? ??
                    outfit['snapshotUrl'] as String? ??
                    '';
                final title = outfit['Title'] as String? ??
                    outfit['title'] as String? ??
                    'Bộ phối đồ';
                final isSelected = _selectedOutfitSnapshotUrl == snapshotUrl;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedOutfitSnapshotUrl = null;
                        _selectedOutfitTitle = null;
                      } else {
                        _selectedOutfitSnapshotUrl = snapshotUrl;
                        _selectedOutfitTitle = title;
                        // Clear individual wardrobe selections
                        _selectedGarments.clear();
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 86,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryLight : Colors.grey.shade200,
                        width: isSelected ? 2.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primary.withOpacity(0.18), blurRadius: 8, offset: const Offset(0, 4))]
                          : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
                    ),
                    child: Stack(
                      children: [
                        // Snapshot image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: snapshotUrl.isNotEmpty
                              ? Image.network(
                                  snapshotUrl,
                                  width: 86,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 86,
                                      height: 110,
                                      color: Colors.grey.shade100,
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                                    );
                                  },
                                  errorBuilder: (context, error, stack) => Container(
                                    width: 86,
                                    height: 110,
                                    color: Colors.grey.shade100,
                                    child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 28),
                                  ),
                                )
                              : Container(
                                  width: 86,
                                  height: 110,
                                  color: Colors.grey.shade100,
                                  child: const Icon(Icons.style_rounded, color: Colors.grey, size: 30),
                                ),
                        ),
                        // Title overlay at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [Colors.black.withOpacity(0.72), Colors.transparent],
                              ),
                            ),
                            child: Text(
                              title,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // Selected checkmark
                        if (isSelected)
                          const Positioned(
                            top: 5,
                            right: 5,
                            child: CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_selectedOutfitSnapshotUrl != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.primaryLight, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Đã chọn: "$_selectedOutfitTitle" — ảnh này sẽ được dùng làm trang phục thử đồ AI',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGarmentSelector() {
    if (_isLoadingWardrobe) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_wardrobeItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            const Icon(Icons.dry_cleaning_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 10),
            const Text('Tủ đồ trống!', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('Hãy thêm đồ ở tab Tủ đồ trước.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchWardrobe,
              child: const Text('Tải lại tủ đồ'),
            )
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category filters inside wardrobe
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: ['Tất cả', 'Áo', 'Quần/Váy', 'Đầm/Váy liền', 'Áo khoác', 'Khác'].map((filter) {
              final active = _wardrobeFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active,
                  onSelected: (_) {
                    setState(() => _wardrobeFilter = filter);
                  },
                  label: Text(filter, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.normal)),
                  selectedColor: AppColors.accent,
                  labelStyle: TextStyle(color: active ? AppColors.primary : Colors.black87),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Garments Grid – wrap vào GridView để hiển thị đầy đủ
        if (_filteredGarments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Không tìm thấy quần áo phù hợp ở danh mục này.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: _filteredGarments.length,
            itemBuilder: (context, index) {
              final item = _filteredGarments[index];
              final isSelected = _selectedGarments.any((g) => g.id == item.id);

              return GestureDetector(
                onTap: () => _toggleGarmentSelection(item),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryLight : Colors.grey.shade200,
                      width: isSelected ? 2.5 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? AppColors.primary.withOpacity(0.12)
                            : Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: Image.network(
                                item.originalImageUrl ?? item.imageUrl,
                                width: double.infinity,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey.shade50,
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.grey.shade100,
                                  child: const Icon(Icons.broken_image_outlined, color: Colors.grey, size: 30),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                            child: Text(
                              item.name.isEmpty ? 'Không tên' : item.name,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: AppColors.primaryLight,
                            child: const Icon(Icons.check_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          )
      ],
    );
  }

  // Helper: chuyển category tiếng Anh sang tiếng Việt
  String _categoryLabel(String cat) {
    switch (cat.toLowerCase()) {
      case 'top': return 'Áo';
      case 'bottom': return 'Quần/Váy';
      case 'dress': return 'Đầm';
      case 'outerwear': return 'Áo khoác';
      case 'bag': return 'Túi';
      case 'shoes': return 'Giày';
      default: return 'Khác';
    }
  }

  Widget _buildSelectedGarmentsPreview() {
    if (_selectedGarments.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chọn (${_selectedGarments.length} món)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedGarments.clear()),
                child: const Text(
                  'Xóa tất cả',
                  style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedGarments.length,
              itemBuilder: (context, idx) {
                final item = _selectedGarments[idx];
                return Container(
                  width: 78,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primaryLight.withOpacity(0.6), width: 1.5),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Ảnh sản phẩm
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          item.originalImageUrl ?? item.imageUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, e, s) =>
                              const Icon(Icons.broken_image_outlined, color: Colors.grey),
                        ),
                      ),
                      // Nhãn loại (tiếng Việt) ở dưới
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.55),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            _categoryLabel(item.category),
                            style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      // Nút X – to hơn, dễ nhấn
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedGarments.removeAt(idx)),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                              ],
                            ),
                            child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (_selectedGarments.length > 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hệ thống sẽ tự động ghép các món đồ thành 1 ảnh Flat Lay trước khi mặc thử lên người mẫu.',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildTryOnConfig() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          // Category Choice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Vùng mặc thử:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
              DropdownButton<String>(
                value: _selectedCategory,
                underline: const SizedBox(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                items: const [
                  DropdownMenuItem(value: 'auto', child: Text('Tự động nhận diện')),
                  DropdownMenuItem(value: 'tops', child: Text('Áo (Tops)')),
                  DropdownMenuItem(value: 'bottoms', child: Text('Quần/Váy (Bottoms)')),
                  DropdownMenuItem(value: 'one-pieces', child: Text('Đầm/Váy liền')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              )
            ],
          ),
          const Divider(),
          // Restore Background Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Giữ nguyên hậu cảnh:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                  Text('Giúp ảnh chân thực, tự nhiên hơn', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Switch(
                value: _restoreBackground,
                activeThumbColor: AppColors.primary,
                onChanged: (val) => setState(() => _restoreBackground = val),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTryOnNotes() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.accent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Lưu ý để phối đồ AI đẹp nhất:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildNoteItem(
            Icons.person_pin_rounded,
            'Ảnh người mẫu: Chụp thẳng, rõ nét, đủ sáng, tư thế đứng thẳng tự nhiên (tay buông thõng hai bên, không che thân). Tránh mặc đồ quá rộng/phồng.',
          ),
          const SizedBox(height: 8),
          _buildNoteItem(
            Icons.checkroom_rounded,
            'Ảnh trang phục: Chọn ảnh rõ nét, chụp phẳng (Flat Lay) hoặc ảnh sản phẩm chụp trên nền trơn/trắng.',
          ),
        ],
      ),
    );
  }

  Widget _buildNoteItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.primaryLight.withOpacity(0.8),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.primary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ================= STATE: SCANNING ANIMATION =================

  Widget _buildScanningState() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Magic scanning image container
              Stack(
                alignment: Alignment.center,
                children: [
                  // Combined avatar preview
                  Container(
                    width: 260,
                    height: 320,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.12),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Model image
                          if (_selectedModelFile != null)
                            Image.file(_selectedModelFile!, fit: BoxFit.cover)
                          else if (_selectedModelUrl != null)
                            _selectedModelUrl!.startsWith('assets/')
                                ? Image.asset(_selectedModelUrl!, fit: BoxFit.cover)
                                : Image.network(_selectedModelUrl!, fit: BoxFit.cover),
                          
                          // Semi-transparent overlay
                          Container(color: Colors.black26),
                        ],
                      ),
                    ),
                  ),

                  // Animated Laser scanning line
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: _scanAnimation.value * 300 + 10, // Moves up and down the container
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.greenAccent,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.greenAccent.withOpacity(0.8),
                                blurRadius: 16,
                                spreadRadius: 3,
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Garment badge overlap (overlapping stack for multiple garments)
                  if (_selectedGarments.isNotEmpty)
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: SizedBox(
                        width: 70.0 + (_selectedGarments.length - 1) * 15.0,
                        height: 70.0,
                        child: Stack(
                          children: List.generate(_selectedGarments.length, (index) {
                            final item = _selectedGarments[index];
                            return Positioned(
                              left: index * 15.0,
                              child: Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.primaryLight, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 6,
                                      offset: Offset(2, 2),
                                    )
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.network(item.imageUrl, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 24),

              // Elapsed and loading text
              Text(
                '${_elapsedSeconds}s',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                _loadingMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  height: 1.25,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Tiến trình AI thường mất khoảng 10-15 giây để hoàn tất.',
                style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.25),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Cancel processing button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () {
                  setState(() {
                    _isGenerating = false;
                    _predictionId = null;
                  });
                  _stopTimer();
                  _scanController.stop();
                },
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text(
                  'Hủy bỏ yêu cầu',
                  style: TextStyle(fontWeight: FontWeight.bold, height: 1.25),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // ================= STATE: RESULT STATE =================

  Widget _buildResultState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: FadeInScale(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.1),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: InteractiveViewer(
                    maxScale: 4.0,
                    child: Image.network(
                      _resultUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isSavingImage
                      ? null
                      : () => _saveImageToGallery(_resultUrl!),
                  icon: _isSavingImage
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _isSavingImage ? 'Đang tải...' : 'Tải xuống',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    // Reset to try again
                    setState(() {
                      _resultUrl = null;
                      _predictionId = null;
                    });
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử đồ khác', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }


}

// Fade in scale animation helper for result state
class FadeInScale extends StatefulWidget {
  final Widget child;
  const FadeInScale({super.key, required this.child});

  @override
  State<FadeInScale> createState() => _FadeInScaleState();
}

class _FadeInScaleState extends State<FadeInScale> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
