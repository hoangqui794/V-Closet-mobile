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

  static ClothingItem? pendingTryOnGarment;
  static String? pendingTryOnOutfitSnapshotUrl;
  static String? pendingTryOnOutfitTitle;

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
  int _activeStep = 0;
  bool _pickFromOutfits = false;

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
                    Icon(Icons.info_outline_rounded, color: AppColors.brandText, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Lưu ý chọn ảnh người mẫu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.brandText,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.brandText),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Detailed text guidelines (tách riêng Nên và Không nên theo chiều dọc, viết ít keyword kèm icon)
            Builder(
              builder: (context) {
                Widget buildKeywordItem(IconData icon, Color color, String keyword) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        keyword,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.brandText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    // Nên làm
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'NÊN LÀM',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.green.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.accessibility_new_rounded,
                                  Colors.green.shade600,
                                  'Đứng thẳng',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.checkroom_rounded,
                                  Colors.green.shade600,
                                  'Đồ ôm sát',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.center_focus_strong_rounded,
                                  Colors.green.shade600,
                                  'Rõ vóc dáng',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Tránh làm
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.shade200, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel_rounded, color: Colors.red.shade700, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'NÊN TRÁNH',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red.shade800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.directions_run_rounded,
                                  Colors.red.shade600,
                                  'Đứng nghiêng',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.front_hand_rounded,
                                  Colors.red.shade600,
                                  'Tay che người',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.layers_clear_rounded,
                                  Colors.red.shade600,
                                  'Đồ rộng/dày',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
    if (OutfitPage.pendingTryOnGarment != null || OutfitPage.pendingTryOnOutfitSnapshotUrl != null) {
      final garment = OutfitPage.pendingTryOnGarment;
      final outfitSnapshotUrl = OutfitPage.pendingTryOnOutfitSnapshotUrl;
      final outfitTitle = OutfitPage.pendingTryOnOutfitTitle;
      
      OutfitPage.pendingTryOnGarment = null;
      OutfitPage.pendingTryOnOutfitSnapshotUrl = null;
      OutfitPage.pendingTryOnOutfitTitle = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            if (garment != null) {
              _selectedGarments.clear();
              _selectedGarments.add(garment);
              _selectedOutfitSnapshotUrl = null;
              _selectedOutfitTitle = null;
            } else if (outfitSnapshotUrl != null) {
              _selectedOutfitSnapshotUrl = outfitSnapshotUrl;
              _selectedOutfitTitle = outfitTitle;
              _selectedGarments.clear();
            }
            _activeStep = 2; // Jump to AI Config step
          });
        }
      });
    }

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
                  color: AppColors.brandText,
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
            color: AppColors.brandText,
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

    Widget stepBody;
    switch (_activeStep) {
      case 0:
        stepBody = _buildModelSelectorStep();
        break;
      case 1:
        stepBody = _buildGarmentsSelectorStep();
        break;
      case 2:
      default:
        stepBody = _buildAiConfigStep();
        break;
    }

    return Column(
      children: [
        _buildStepIndicator(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refreshAllData,
            color: AppColors.brandText,
            child: stepBody,
          ),
        ),
        _buildWizardNavigationButtons(),
      ],
    );
  }



  Widget _buildModelSelector() {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // ADD CUSTOM BUTTON
          GestureDetector(
            onTap: _showModelUploadGuidelines,
            child: Container(
              width: 76,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedModelFile != null ? AppColors.primaryLight : Colors.grey.shade300,
                  width: _selectedModelFile != null ? 2.0 : 1,
                ),
              ),
              child: _selectedModelFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(_selectedModelFile!, fit: BoxFit.cover),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined, color: AppColors.brandText, size: 24),
                        SizedBox(height: 4),
                        Text('Tải ảnh\ncủa bạn', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.brandText, height: 1.2), textAlign: TextAlign.center),
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
                width: 76,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryLight : Colors.grey.shade200,
                    width: isSelected ? 2.0 : 1.2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandText),
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
        child: Center(child: CircularProgressIndicator(color: AppColors.brandText, strokeWidth: 2)),
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
              const Icon(Icons.style_rounded, size: 14, color: AppColors.brandText),
              const SizedBox(width: 5),
              const Text(
                'Chọn từ trang phục đã lưu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandText),
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
                                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandText)),
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
                    style: const TextStyle(fontSize: 11, color: AppColors.brandText, fontWeight: FontWeight.w600),
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
          child: CircularProgressIndicator(color: AppColors.brandText),
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
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brandText),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandText),
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
                  Icon(Icons.info_outline, size: 16, color: AppColors.brandText),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hệ thống sẽ tự động ghép các món đồ thành 1 ảnh Flat Lay trước khi mặc thử lên người mẫu.',
                      style: TextStyle(fontSize: 11, color: AppColors.brandText, fontWeight: FontWeight.w500),
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
              const Text('Vùng mặc thử:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandText)),
              DropdownButton<String>(
                value: _selectedCategory,
                underline: const SizedBox(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandText),
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
                  Text('Giữ nguyên hậu cảnh:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.brandText)),
                  Text('Giúp ảnh chân thực, tự nhiên hơn', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              Switch(
                value: _restoreBackground,
                activeThumbColor: AppColors.brandText,
                onChanged: (val) => setState(() => _restoreBackground = val),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTryOnNotes() {
    Widget buildMiniBadge(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint.withOpacity(0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight.withOpacity(0.85)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.brandText, size: 18),
            const SizedBox(height: 6),
            Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.brandText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandText.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.brandText.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tips_and_updates_rounded,
                  color: AppColors.brandText,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Mẹo phối đồ AI đẹp nhất:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brandText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Section 1: Người mẫu
          Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandText,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'MẪU',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.accessibility_new_rounded,
                          'Chụp thẳng',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.wb_sunny_rounded,
                          'Đủ ánh sáng',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.checkroom_rounded,
                          'Đồ ôm sát',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Section 2: Trang phục
          Row(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brandText,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Text(
                    'ĐỒ',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.wallpaper_rounded,
                          'Nền đơn sắc',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.aspect_ratio_rounded,
                          'Chụp phẳng',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: buildMiniBadge(
                          Icons.high_quality_rounded,
                          'Ảnh rõ nét',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
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
                          Container(color: Colors.black45),
                        ],
                      ),
                    ),
                  ),

                  // Simulated percentage progress in the center
                  Positioned.fill(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_scanningPercentage%',
                            style: const TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  offset: Offset(0, 4),
                                  blurRadius: 12,
                                )
                              ]
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Đang xử lý...',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black38,
                                    offset: Offset(0, 1),
                                    blurRadius: 3,
                                  )
                                ]
                              ),
                            ),
                          )
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
                  if (_selectedGarments.isNotEmpty || _selectedOutfitSnapshotUrl != null)
                    Positioned(
                      bottom: 12,
                      right: 12,
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
                          child: _selectedOutfitSnapshotUrl != null
                              ? Image.network(_selectedOutfitSnapshotUrl!, fit: BoxFit.cover)
                              : Image.network(_selectedGarments.first.imageUrl, fit: BoxFit.cover),
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
                  color: AppColors.brandText,
                  letterSpacing: 2
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                _loadingMessage,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandText,
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
                  child: BeforeAfterSlider(
                    beforeImage: _buildBeforeImage(),
                    afterImage: _buildAfterImage(),
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
                            color: AppColors.brandText,
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
                    side: const BorderSide(color: AppColors.brandText),
                    foregroundColor: AppColors.brandText,
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

  int get _scanningPercentage {
    if (_elapsedSeconds <= 0) return 0;
    if (_elapsedSeconds < 15) {
      return (_elapsedSeconds * 6.3).toInt();
    }
    int extra = (_elapsedSeconds - 15) ~/ 3;
    int val = 95 + extra;
    return val > 99 ? 99 : val;
  }

  Widget _buildModelSelectorStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn người mẫu thử đồ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn người mẫu có sẵn hoặc tải ảnh chụp của riêng bạn.',
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
          ),
          const SizedBox(height: 16),
          _buildModelSelector(),
          const SizedBox(height: 24),
          const Text(
            'Xem trước người mẫu',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brandText),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: _selectedModelFile != null
                    ? Image.file(
                        _selectedModelFile!,
                        fit: BoxFit.fitWidth,
                      )
                    : _selectedModelUrl != null
                        ? _selectedModelUrl!.startsWith('assets/')
                            ? Image.asset(
                                _selectedModelUrl!,
                                fit: BoxFit.fitWidth,
                              )
                            : Image.network(
                                _selectedModelUrl!,
                                fit: BoxFit.fitWidth,
                              )
                        : const SizedBox(
                            height: 200,
                            child: Center(
                              child: Icon(Icons.person, size: 72, color: Colors.grey),
                            ),
                          ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGarmentsSelectorStep() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chọn trang phục thử đồ',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Chọn quần áo từ tủ đồ của bạn để thử lên người mẫu.',
            style: TextStyle(fontSize: 11, color: Colors.grey, height: 1.3),
          ),
          const SizedBox(height: 16),
          
          // Toggle Picker Type
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pickFromOutfits = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_pickFromOutfits ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: !_pickFromOutfits ? AppColors.primaryLight : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Tủ đồ cá nhân',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_pickFromOutfits ? AppColors.primary : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _pickFromOutfits = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _pickFromOutfits ? AppColors.primary.withOpacity(0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _pickFromOutfits ? AppColors.primaryLight : Colors.grey.shade300,
                      ),
                    ),
                    child: Text(
                      'Trang phục phối sẵn',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _pickFromOutfits ? AppColors.primary : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          _pickFromOutfits ? _buildOutfitPicker() : _buildGarmentSelector(),
          _buildSelectedGarmentsPreview(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAiConfigStep() {
    final bool isOutfitSnapshot = _selectedOutfitSnapshotUrl != null;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Xác nhận & Cấu hình',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.brandText,
            ),
          ),
          const SizedBox(height: 16),
          
          // Selection Summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                // Model Preview
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Người mẫu',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 72,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: _selectedModelFile != null
                              ? Image.file(_selectedModelFile!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                              : _selectedModelUrl != null
                                  ? _selectedModelUrl!.startsWith('assets/')
                                      ? Image.asset(_selectedModelUrl!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                                      : Image.network(_selectedModelUrl!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                                  : const Icon(Icons.person, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Icon Arrow/Link
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add_rounded, color: Colors.grey, size: 20),
                ),
                
                // Garments Preview
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'Trang phục',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: 72,
                        height: 96,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: isOutfitSnapshot
                              ? Image.network(_selectedOutfitSnapshotUrl!, fit: BoxFit.cover)
                              : _selectedGarments.isNotEmpty
                                  ? Image.network(_selectedGarments.first.imageUrl, fit: BoxFit.contain)
                                  : const Icon(Icons.checkroom_rounded, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Cấu hình AI',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.brandText),
          ),
          const SizedBox(height: 10),
          _buildTryOnConfig(),
          const SizedBox(height: 20),
          _buildTryOnNotes(),
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
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          _stepNode(0, 'Người mẫu'),
          _stepDivider(0),
          _stepNode(1, 'Trang phục'),
          _stepDivider(1),
          _stepNode(2, 'Thử đồ AI'),
        ],
      ),
    );
  }

  Widget _stepNode(int stepIndex, String title) {
    final bool isActive = _activeStep == stepIndex;
    final bool isCompleted = _activeStep > stepIndex;
    
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted
                  ? AppColors.primary
                  : isActive
                      ? AppColors.primaryLight
                      : Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? AppColors.primary : Colors.grey.shade300,
                width: isActive ? 2 : 1,
              ),
              boxShadow: isActive ? [
                BoxShadow(
                  color: AppColors.primaryLight.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ] : [],
            ),
            child: Center(
              child: isCompleted
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : Text(
                      '${stepIndex + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isActive || isCompleted ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppColors.primary : Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _stepDivider(int stepIndex) {
    final bool isPassed = _activeStep > stepIndex;
    return Container(
      width: 36,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      color: isPassed ? AppColors.primary : Colors.grey.shade200,
    );
  }

  Widget _buildWizardNavigationButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      color: AppColors.background, // Match screen background so it blends perfectly
      child: Row(
        children: [
          if (_activeStep > 0)
            Expanded(
              child: SizedBox(
                height: 42,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _activeStep--),
                  child: const Text(
                    'Quay lại',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryLight, fontSize: 13),
                  ),
                ),
              ),
            ),
          if (_activeStep > 0) const SizedBox(width: 12),
          Expanded(
            child: _activeStep < 2
                ? SizedBox(
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: (_activeStep == 1 && _selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null)
                          ? null
                          : () => setState(() => _activeStep++),
                      child: const Text(
                        'Tiếp tục',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                    ),
                  )
                : Container(
                    height: 42,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null)
                            ? [Colors.grey.shade400, Colors.grey.shade400]
                            : [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null) ? [] : [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: (_selectedGarments.isEmpty && _selectedOutfitSnapshotUrl == null) ? null : _startTryOn,
                      icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                      label: const Text(
                        'Bắt đầu thử đồ AI',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeImage() {
    if (_selectedModelFile != null) {
      return Image.file(_selectedModelFile!, fit: BoxFit.cover, alignment: Alignment.topCenter);
    } else if (_selectedModelUrl != null) {
      return _selectedModelUrl!.startsWith('assets/')
          ? Image.asset(_selectedModelUrl!, fit: BoxFit.cover, alignment: Alignment.topCenter)
          : Image.network(_selectedModelUrl!, fit: BoxFit.cover, alignment: Alignment.topCenter);
    }
    return const Center(child: Icon(Icons.person, size: 72, color: Colors.grey));
  }

  Widget _buildAfterImage() {
    return Image.network(
      _resultUrl!,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator(color: AppColors.brandText));
      },
    );
  }
}

// Before/After Split comparison slider widget
class BeforeAfterSlider extends StatefulWidget {
  final Widget beforeImage;
  final Widget afterImage;

  const BeforeAfterSlider({
    super.key,
    required this.beforeImage,
    required this.afterImage,
  });

  @override
  State<BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _BeforeAfterSliderState extends State<BeforeAfterSlider> {
  double _clipFactor = 0.5; // Starts in the middle

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              _clipFactor = (details.localPosition.dx / width).clamp(0.0, 1.0);
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Before Image (Base layer)
              widget.beforeImage,

              // After Image (Clipped layer)
              ClipRect(
                clipper: _SliderRectClipper(_clipFactor),
                child: widget.afterImage,
              ),

              // Slider Handle (Line)
              Positioned(
                top: 0,
                bottom: 0,
                left: width * _clipFactor - 1.5,
                child: Container(
                  width: 3,
                  color: Colors.white,
                ),
              ),

              // Slider Handle (Thumb)
              Positioned(
                top: 0,
                bottom: 0,
                left: width * _clipFactor - 20,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.brandText,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chevron_left_rounded, size: 14, color: Colors.white),
                          Icon(Icons.chevron_right_rounded, size: 14, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Before Label
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Trước',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // After Label
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Sau',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SliderRectClipper extends CustomClipper<Rect> {
  final double clipFactor;
  _SliderRectClipper(this.clipFactor);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(size.width * clipFactor, 0.0, size.width, size.height);
  }

  @override
  bool shouldReclip(_SliderRectClipper oldClipper) {
    return oldClipper.clipFactor != clipFactor;
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
