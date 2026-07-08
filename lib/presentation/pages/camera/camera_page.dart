import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:camera/camera.dart';
import 'package:dio/dio.dart';
import '../../../data/datasources/bg_removal_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../data/datasources/ad_service.dart';
import '../../../data/datasources/gemini_api_service.dart';
import '../../../core/theme/app_colors.dart';
import '../profile/subscription_page.dart';
import '../profile/personal_color_detail_page.dart';
import 'color_harmony_checker_page.dart';

class CameraPage extends StatefulWidget {
  final VoidCallback? onClose;
  const CameraPage({super.key, this.onClose});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final ImagePicker _picker = ImagePicker();
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIndex = 0;
  FlashMode _flashMode = FlashMode.off;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        _cameraController = CameraController(
          _cameras![_selectedCameraIndex],
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        await _cameraController!.setFlashMode(_flashMode);
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      return;
    }
    
    _selectedCameraIndex = _selectedCameraIndex == 0 ? 1 : 0;
    await _cameraController?.dispose();
    
    _cameraController = CameraController(
      _cameras![_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );
    
    try {
      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(_flashMode);
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Lỗi khi đổi camera: $e');
    }
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    
    FlashMode nextMode;
    if (_flashMode == FlashMode.off) {
      nextMode = FlashMode.always;
    } else if (_flashMode == FlashMode.always) {
      nextMode = FlashMode.auto;
    } else {
      nextMode = FlashMode.off;
    }
    
    try {
      await _cameraController!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (e) {
      debugPrint('Lỗi khi đổi chế độ flash: $e');
    }
  }

  IconData _getFlashIcon() {
    if (_flashMode == FlashMode.always) {
      return Icons.flash_on;
    }
    if (_flashMode == FlashMode.auto) {
      return Icons.flash_auto;
    }
    return Icons.flash_off;
  }

  void _showBgRemovalGuidelines() {
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
                      'Lưu ý chụp ảnh tách nền',
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
                                  Icons.checkroom_rounded,
                                  Colors.green.shade600,
                                  'Treo phẳng',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.wallpaper_rounded,
                                  Colors.green.shade600,
                                  'Nền đơn sắc',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.wb_sunny_rounded,
                                  Colors.green.shade600,
                                  'Đủ ánh sáng',
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
                                  Icons.strikethrough_s_rounded,
                                  Colors.red.shade600,
                                  'Bị nhăn nheo',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.grid_off_rounded,
                                  Colors.red.shade600,
                                  'Hậu cảnh rối',
                                ),
                              ),
                              Expanded(
                                child: buildKeywordItem(
                                  Icons.invert_colors_off_rounded,
                                  Colors.red.shade600,
                                  'Trùng màu nền',
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

            // Got it button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Đã hiểu',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<Map<String, String>?> _showDetailsDialog(File imageFile) async {
    String name = 'Đang nhận dạng...';
    String category = 'Top'; 
    String currentCatName = 'Áo';
    String detectedColor = '';
    bool isAnalyzing = true;

    final TextEditingController nameController = TextEditingController(text: name);

    final Map<String, String> categoryOptions = {
      'Áo': 'Top',
      'Quần/Váy': 'Bottom',
      'Đầm': 'Dress',
      'Áo khoác': 'Outerwear',
      'Giày': 'Shoes',
      'Túi': 'Bag',
      'Phụ kiện': 'Accessory',
      'Khác': 'Other'
    };

    final Map<String, String> reverseCategoryMap = {
      'Top': 'Áo',
      'Bottom': 'Quần/Váy',
      'Dress': 'Đầm',
      'Outerwear': 'Áo khoác',
      'Shoes': 'Giày',
      'Bag': 'Túi',
      'Accessory': 'Phụ kiện',
      'Other': 'Khác'
    };

    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (isAnalyzing) {
              isAnalyzing = false;
              GetIt.I<GeminiApiService>().analyzeClothingImage(imageFile).then((result) {
                if (result != null && context.mounted) {
                  setModalState(() {
                    name = result['name'] ?? 'Món đồ mới';
                    category = result['category'] ?? 'Top';
                    currentCatName = reverseCategoryMap[category] ?? 'Áo';
                    detectedColor = result['color'] ?? '';
                    nameController.text = name;
                  });
                } else if (context.mounted) {
                  setModalState(() {
                    name = 'Đồ mới thêm ${DateTime.now().second}';
                    nameController.text = name;
                  });
                }
              });
            }

            final bool isAiRunning = nameController.text == 'Đang nhận dạng...';

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Phân loại đồ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.brandText)),
                    const SizedBox(height: 20),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(imageFile, height: 120, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Lưu ý nhỏ ở dưới ảnh preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: AppColors.primaryLight, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mẹo: Ảnh quần áo phẳng phiu, nền đơn sắc sẽ tách nền sạch đẹp nhất.',
                              style: TextStyle(fontSize: 11, color: AppColors.brandText, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    if (isAiRunning)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryLight),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '🤖 AI đang phân tích ảnh & nhận diện...',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primary.withOpacity(0.7),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (detectedColor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.palette_rounded, size: 14, color: AppColors.primaryLight),
                            const SizedBox(width: 6),
                            Text(
                              'AI nhận diện màu sắc: $detectedColor',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 4),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Tên món đồ',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: currentCatName,
                      decoration: const InputDecoration(
                        labelText: 'Loại trang phục',
                        border: OutlineInputBorder(),
                      ),
                      items: categoryOptions.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            currentCatName = val;
                            category = categoryOptions[val]!;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {'name': name, 'category': category});
                        },
                        child: const Text('Lưu & Tách nền', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Hàm xử lý chung: Chọn ảnh -> Tách nền -> Up lên Tủ đồ
  Future<void> _processAndUpload(bool isFromGallery) async {
    try {
      XFile? image;
      if (isFromGallery) {
        image = await _picker.pickImage(source: ImageSource.gallery);
      } else {
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          return;
        }
        image = await _cameraController!.takePicture();
      }
      
      if (image == null) {
        return;
      }

      // HIỂN THỊ POPUP YÊU CẦU NHẬP TÊN & DANH MỤC TRƯỚC
      final details = await _showDetailsDialog(File(image.path));
      if (details == null) {
        return; // Người dùng bấm hủy
      }

      // Kiểm tra Credits trước khi thực hiện
      final localStorage = GetIt.I<AuthLocalStorage>();
      final bgCredits = localStorage.getBgRemovalCredits();
      if (bgCredits <= 0) {
        if (mounted) {
          SubscriptionPage.showOutOfCreditsSheet(context, isBgRemoval: true);
        }
        return;
      }

      setState(() => _isLoading = true);

      // 1. GỌI API TÁCH NỀN TRƯỚC
      final bgRemovalService = GetIt.I<BgRemovalService>();
      final Uint8List? resultBytes = await bgRemovalService.removeBackground(File(image.path));
      
      // Trừ 1 credit xóa nền
      await localStorage.updateCredits(bgCredits: bgCredits - 1);
      
      File fileToUpload = File(image.path);
      
      // Nếu tách nền thành công, tạo 1 file tạm chứa ảnh trong suốt để chuẩn bị upload
      if (resultBytes != null) {
        final tempFile = File('${Directory.systemTemp.path}/transparent_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(resultBytes);
        fileToUpload = tempFile;
      }

      // 2. GỌI API UPLOAD VÀO TỦ ĐỒ (Sử dụng ảnh đã tách nền)
      final wardrobeService = GetIt.I<WardrobeApiService>();
      final newItem = await wardrobeService.uploadAndCreateItem(
        imageFile: fileToUpload,
        category: details['category']!, 
        name: details['name']!,
      );

      setState(() => _isLoading = false);

      if (newItem != null && mounted) {
        // Tăng số lượng tủ đồ cục bộ
        final currentCount = localStorage.getWardrobeItemCount();
        await localStorage.saveWardrobeItemCount(currentCount + 1);

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 32),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Thêm thành công!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brandText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Món đồ đã được tách nền và lưu vào tủ đồ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    height: 160,
                    width: 160,
                    decoration: BoxDecoration(
                      color: AppColors.muted.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.secondary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Image.file(
                            fileToUpload,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      newItem.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brandText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        AdService().showInterstitialAd(
                          onDismissed: () {},
                          force: false,
                        );
                      },
                      child: const Text(
                        'Đóng',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Không thể tải ảnh lên tủ đồ')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMsg = e.toString();
        if (e is DioException) {
          if (e.response?.statusCode == 413) {
            errorMsg = 'Ảnh chụp quá lớn (giới hạn 30MB). Vui lòng chọn hoặc chụp ảnh nhẹ hơn.';
          } else {
            final data = e.response?.data;
            if (data is Map) {
              if (data['error'] != null) {
                errorMsg = data['error'].toString();
              } else if (data['message'] != null) {
                errorMsg = data['message'].toString();
              }
            } else if (data != null) {
              final dataStr = data.toString();
              if (dataStr.contains('<html') || dataStr.contains('<!DOCTYPE html>')) {
                errorMsg = 'Không thể kết nối đến hệ thống. Vui lòng thử lại sau.';
              } else {
                errorMsg = dataStr;
                if (errorMsg.length > 250) {
                  errorMsg = '${errorMsg.substring(0, 250)}...';
                }
              }
            }
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 1,
                  height: _cameraController!.value.previewSize?.width ?? 1,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            Container(
              color: Colors.black, 
              child: const Center(child: CircularProgressIndicator(color: Colors.white))
            ),
          
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          if (widget.onClose != null) {
                            widget.onClose!();
                          }
                        },
                      ),
                      const Text(
                        'CHỤP ẢNH',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.palette_rounded, color: Colors.white),
                             onPressed: () async {
                               final result = await Navigator.push(
                                 context,
                                 MaterialPageRoute(builder: (_) => const ColorHarmonyCheckerPage()),
                               );
                               if (result is Map && context.mounted) {
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(
                                     builder: (_) => PersonalColorDetailPage(
                                       isFromScan: true,
                                       scannedSkinTone: result['skinTone']?.toString(),
                                       scannedColorPref: result['colorPref']?.toString(),
                                     ),
                                   ),
                                 );
                               }
                             },
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
                            onPressed: _showBgRemovalGuidelines,
                          ),
                          IconButton(
                            icon: Icon(_getFlashIcon(), color: Colors.white),
                            onPressed: _toggleFlash, // Chuyển đổi Flash
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : IconButton(
                            icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
                            onPressed: () => _processAndUpload(true), // isFromGallery = true
                          ),
                      GestureDetector(
                        onTap: _isLoading ? null : () => _processAndUpload(false), // isFromGallery = false
                        child: Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 32),
                        onPressed: _switchCamera, // Đổi camera trước/sau
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
