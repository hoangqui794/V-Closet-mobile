import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:camera/camera.dart';
import '../../../data/datasources/bg_removal_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../profile/subscription_page.dart';

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
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('Lỗi khởi tạo camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
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
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    
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
    if (_flashMode == FlashMode.always) return Icons.flash_on;
    if (_flashMode == FlashMode.auto) return Icons.flash_auto;
    return Icons.flash_off;
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<Map<String, String>?> _showDetailsDialog(File imageFile) async {
    String name = 'Đồ mới thêm ${DateTime.now().second}';
    String category = 'Top'; 
    String currentCatName = 'Áo';

    final Map<String, String> categoryOptions = {
      'Áo': 'Top',
      'Quần/Váy': 'Bottom',
      'Váy/Đầm': 'Dress',
      'Áo khoác': 'Outerwear',
      'Giày dép': 'Shoes',
      'Túi xách': 'Bag',
      'Phụ kiện': 'Accessory',
      'Khác': 'Other'
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
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Phân loại đồ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 20),
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(imageFile, height: 120, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    initialValue: name,
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
        if (_cameraController == null || !_cameraController!.value.isInitialized) return;
        image = await _cameraController!.takePicture();
      }
      
      if (image == null) return;

      // HIỂN THỊ POPUP YÊU CẦU NHẬP TÊN & DANH MỤC TRƯỚC
      final details = await _showDetailsDialog(File(image.path));
      if (details == null) return; // Người dùng bấm hủy

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
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thêm thành công!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hiển thị chính cái ảnh đã tách nền
                Image.file(fileToUpload, height: 150),
                const SizedBox(height: 10),
                Text('Tên: ${newItem.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                const Text('Ảnh đã được tách nền và lưu vào Tủ đồ thành công.', style: TextStyle(color: Colors.green, fontSize: 12)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
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
                      IconButton(
                        icon: Icon(_getFlashIcon(), color: Colors.white),
                        onPressed: _toggleFlash, // Chuyển đổi Flash
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
