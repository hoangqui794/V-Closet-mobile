import 'dart:async';
import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/tryon_api_service.dart';
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../domain/entities/clothing_item.dart';

class OutfitPage extends StatefulWidget {
  const OutfitPage({super.key});

  @override
  State<OutfitPage> createState() => _OutfitPageState();
}

class _OutfitPageState extends State<OutfitPage> with TickerProviderStateMixin {
  final TryOnApiService _tryOnApiService = GetIt.I<TryOnApiService>();
  final WardrobeApiService _wardrobeApiService = GetIt.I<WardrobeApiService>();
  final ImagePicker _picker = ImagePicker();

  // Selected state
  String? _selectedModelUrl;
  File? _selectedModelFile;
  ClothingItem? _selectedGarment;
  String _selectedCategory = 'auto'; // auto, tops, bottoms, one-pieces
  bool _restoreBackground = true;

  // Wardrobe list state
  List<ClothingItem> _wardrobeItems = [];
  bool _isLoadingWardrobe = true;
  String _wardrobeFilter = 'Tất cả';

  // AI Generation State
  bool _isGenerating = false;
  int _elapsedSeconds = 0;
  Timer? _timer;
  String? _predictionId;
  String? _resultUrl;
  String _loadingMessage = 'Đang khởi tạo AI...';
  String? _errorMessage;

  // Scanning Animation
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  // Pre-defined sample models from Unsplash
  final List<Map<String, String>> _sampleModels = [
    {
      'name': 'Mẫu Nữ 1',
      'url': 'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?q=80&w=600&auto=format&fit=crop',
      'gender': 'female'
    },
    {
      'name': 'Mẫu Nam 1',
      'url': 'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?q=80&w=600&auto=format&fit=crop',
      'gender': 'male'
    },
    {
      'name': 'Mẫu Nữ 2',
      'url': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?q=80&w=600&auto=format&fit=crop',
      'gender': 'female'
    },
    {
      'name': 'Mẫu Nam 2',
      'url': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?q=80&w=600&auto=format&fit=crop',
      'gender': 'male'
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchWardrobe();

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
      print('Lỗi tải tủ đồ: $e');
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
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

  // Start Virtual Tryon Process
  Future<void> _startTryOn() async {
    if (_selectedGarment == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn trang phục để thử.')),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _resultUrl = null;
      _loadingMessage = 'Đang kết nối dịch vụ AI...';
    });

    _scanController.forward();
    _startTimer();

    try {
      String? modelUrlToUse = _selectedModelUrl;

      // 1. If user uploaded a custom model photo, we need to upload it first.
      // We can use a Form Data upload to S3 via the backend run-files endpoint, 
      // or run tryon with files directly.
      if (_selectedModelFile != null) {
        setState(() => _loadingMessage = 'Đang tải ảnh người mẫu của bạn lên Cloud...');
        
        // For custom files, we call the backend via DIO directly.
        // The API route is /api/TryOn/run-files.
        final dio = Dio();
        dio.options.baseUrl = GetIt.I<Dio>().options.baseUrl;
        
        setState(() => _loadingMessage = 'Đang chuẩn bị dữ liệu hình ảnh...');
        
        final garmentResponse = await dio.get(
          _selectedGarment!.originalImageUrl ?? _selectedGarment!.imageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        
        final garmentBytes = garmentResponse.data as List<int>;
        
        final uploadFormData = FormData.fromMap({
          "modelFile": await MultipartFile.fromFile(
            _selectedModelFile!.path,
            filename: _selectedModelFile!.path.split(Platform.pathSeparator).last,
          ),
          "garmentFile": MultipartFile.fromBytes(
            garmentBytes,
            filename: 'garment.png',
          ),
          "category": _selectedCategory,
          "restoreBackground": _restoreBackground.toString(),
        });
        
        final apiEndpoint = '${dio.options.baseUrl}/TryOn/run-files';
        final response = await dio.post(apiEndpoint, data: uploadFormData);
        
        if (response.statusCode == 200 && response.data != null) {
          _predictionId = response.data['predictionId'] as String?;
        } else {
          throw Exception('Lỗi khởi tạo tiến trình thử đồ file.');
        }
      } else {
        // Use direct wardrobe item ID and sample model URL
        _predictionId = await _tryOnApiService.runTryOnWithWardrobe(
          wardrobeItemId: _selectedGarment!.id,
          modelUrl: modelUrlToUse,
          category: _selectedCategory,
          restoreBackground: _restoreBackground,
        );
      }

      if (_predictionId == null) {
        throw Exception('Không nhận được ID tiến trình từ máy chủ AI.');
      }

      // 2. Start polling for status
      _pollStatus();
    } catch (e) {
      _stopTimer();
      _scanController.stop();
      setState(() {
        _isGenerating = false;
        _errorMessage = 'Lỗi: ${e.toString()}';
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
          setState(() {
            _isGenerating = false;
            _resultUrl = outputUrl;
          });
        } else if (status == 'failed' || error != null) {
          timer.cancel();
          _stopTimer();
          _scanController.stop();
          setState(() {
            _isGenerating = false;
            _errorMessage = error ?? 'Thử đồ thất bại do lỗi xử lý AI.';
          });
        }
      } catch (e) {
        print('Lỗi kiểm tra trạng thái: $e');
      }
    });
  }

  // Filtered wardrobe list
  List<ClothingItem> get _filteredGarments {
    if (_wardrobeFilter == 'Tất cả') {
      // Filter out non-wearables like bags and shoes for standard tryon
      return _wardrobeItems.where((item) {
        final cat = item.category.toLowerCase();
        return cat == 'top' || cat == 'bottom' || cat == 'dress' || cat == 'outerwear';
      }).toList();
    }
    
    final Map<String, String> filterMap = {
      'Áo': 'top',
      'Quần/Váy': 'bottom',
      'Đầm/Váy liền': 'dress',
      'Áo khoác': 'outerwear',
    };
    
    final targetCat = filterMap[_wardrobeFilter];
    return _wardrobeItems.where((item) => item.category.toLowerCase() == targetCat).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          title: const Text(
            'Studio Phối Đồ AI',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          bottom: const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            tabs: [
              Tab(text: 'Phòng thử đồ ảo'),
              Tab(text: 'Gợi ý phối đồ'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            physics: const BouncingScrollPhysics(),
            children: [
              _buildVirtualTryOnRoom(),
              _buildStaticAiOutfits(),
            ],
          ),
        ),
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

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phòng thử đồ thông minh',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Mặc thử bất kỳ trang phục nào lên người mẫu ảo chỉ trong vài giây.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // 1. SELECT MODEL IMAGE
          _sectionHeader('1. Chọn người mẫu thử đồ'),
          const SizedBox(height: 12),
          _buildModelSelector(),
          const SizedBox(height: 24),

          // 2. SELECT WARDROBE ITEM
          _sectionHeader('2. Chọn quần áo từ tủ đồ'),
          const SizedBox(height: 12),
          _buildGarmentSelector(),
          const SizedBox(height: 24),

          // 3. OPTIONS
          _sectionHeader('3. Cấu hình AI'),
          const SizedBox(height: 12),
          _buildTryOnConfig(),
          const SizedBox(height: 32),

          // ACTION BUTTON
          FadeInUp(
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _selectedGarment == null 
                      ? [Colors.grey.shade400, Colors.grey.shade400] 
                      : [AppColors.primary, AppColors.primaryLight],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: _selectedGarment == null ? [] : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
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
                onPressed: _selectedGarment == null ? null : _startTryOn,
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
          ]
        ],
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
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          // ADD CUSTOM BUTTON
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                        title: const Text('Chụp ảnh mới'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickModelImage(ImageSource.camera);
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                        title: const Text('Chọn từ thư viện'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickModelImage(ImageSource.gallery);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
            child: Container(
              width: 80,
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
                        Icon(Icons.add_a_photo_outlined, color: AppColors.primary, size: 24),
                        SizedBox(height: 4),
                        Text('Tải ảnh', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
            ),
          ),

          // PRE-DEFINED SAMPLE MODELS
          ..._sampleModels.map((model) {
            final isSelected = _selectedModelUrl == model['url'] && _selectedModelFile == null;
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedModelUrl = model['url'];
                  _selectedModelFile = null;
                });
              },
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primaryLight : Colors.transparent,
                    width: 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(model['url']!, fit: BoxFit.cover),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.black54,
                          child: Text(
                            model['name']!,
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      if (isSelected)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: CircleAvatar(
                            radius: 8,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.check, size: 10, color: Colors.white),
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
            children: ['Tất cả', 'Áo', 'Quần/Váy', 'Đầm/Váy liền', 'Áo khoác'].map((filter) {
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

        // Garments Row
        SizedBox(
          height: 140,
          child: _filteredGarments.isEmpty
              ? const Center(child: Text('Không tìm thấy quần áo phù hợp ở danh mục này.', style: TextStyle(color: Colors.grey, fontSize: 12)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _filteredGarments.length,
                  itemBuilder: (context, index) {
                    final item = _filteredGarments[index];
                    final isSelected = _selectedGarment?.id == item.id;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGarment = isSelected ? null : item;
                          
                          // Smart auto-update category config based on selected clothing category
                          if (!isSelected) {
                            final cat = item.category.toLowerCase();
                            if (cat == 'top') _selectedCategory = 'tops';
                            else if (cat == 'bottom') _selectedCategory = 'bottoms';
                            else if (cat == 'dress') _selectedCategory = 'one-pieces';
                            else if (cat == 'outerwear') _selectedCategory = 'tops';
                          }
                        });
                      },
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryLight : Colors.grey.shade200,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                                child: Image.network(
                                  item.imageUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 30),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Text(
                                item.name.isEmpty ? 'Không tên' : item.name,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
        )
      ],
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
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _restoreBackground = val),
              )
            ],
          )
        ],
      ),
    );
  }

  // ================= STATE: SCANNING ANIMATION =================

  Widget _buildScanningState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
                      color: AppColors.primary.withValues(alpha: 0.12),
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
                        Image.network(_selectedModelUrl!, fit: BoxFit.cover),
                      
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
                            color: Colors.greenAccent.withValues(alpha: 0.8),
                            blurRadius: 16,
                            spreadRadius: 3,
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Garment badge overlap
              if (_selectedGarment != null)
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
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]
                    ),
                    child: ClipOval(
                      child: Image.network(_selectedGarment!.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                )
            ],
          ),
          const SizedBox(height: 36),

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
          const SizedBox(height: 10),
          
          Text(
            _loadingMessage,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text(
            'Tiến trình AI thường mất khoảng 10-15 giây để hoàn tất.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
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
            label: const Text('Hủy bỏ yêu cầu', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
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
                      color: AppColors.primary.withValues(alpha: 0.1),
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
                  onPressed: () {
                    // Simulating image saving to gallery
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Đang lưu hình ảnh vào Thư viện của bạn...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    Future.delayed(const Duration(milliseconds: 1500), () {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lưu thành công! Đã lưu ảnh thử đồ ảo vào Thư viện.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    });
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Tải xuống', style: TextStyle(fontWeight: FontWeight.bold)),
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

  // ================= TAB 2: ORIGINAL STATIC AI OUTFIT SUGGESTIONS =================

  Widget _buildStaticAiOutfits() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A3728), Color(0xFF7F5539)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gợi ý phối đồ bằng AI',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Sẵn sàng cho outfit tiếp theo?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kết hợp tự động áo, quần, váy và áo khoác chỉ với một chạm.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _featureCard(
            icon: Icons.auto_awesome_rounded,
            title: 'Phối nhanh một chạm',
            description:
                'Gợi ý thông minh dựa trên cân bằng danh mục và phong cách thiết kế.',
          ),
          _featureCard(
            icon: Icons.palette_outlined,
            title: 'Hài hòa màu sắc',
            description: 'Tận dụng vòng tròn màu sắc để outfit luôn đồng điệu.',
          ),
          _featureCard(
            icon: Icons.calendar_month_outlined,
            title: 'Mẫu theo dịp',
            description:
                'Gợi ý tối ưu cho đi học, đi làm, hẹn hò hoặc dã ngoại.',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng gợi ý phối đồ đang được cập nhật!')),
                );
              },
              icon: const Icon(Icons.checkroom_rounded),
              label: const Text('Phối đồ thông minh ngay', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    height: 1.35,
                    color: AppColors.primary.withValues(alpha: 0.65),
                    fontSize: 12,
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
