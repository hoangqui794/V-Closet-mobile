import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get_it/get_it.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/datasources/auth_local_storage.dart';
import '../../../../data/datasources/outfit_api_service.dart';
import '../../../../data/datasources/subscription_api_service.dart';
import '../../../../data/datasources/wardrobe_api_service.dart';
import '../../../../domain/entities/clothing_item.dart';
import '../profile/subscription_page.dart';

// ─── Data model for each item placed on canvas ────────────────────────────────

class _CanvasItem {
  final String uid; // unique ID on canvas (item.id + timestamp)
  final ClothingItem clothingItem;
  Offset position;
  double scale;
  int zIndex;

  _CanvasItem({
    required this.uid,
    required this.clothingItem,
    required this.position,
    required this.scale,
    this.zIndex = 0,
  });
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class CanvasOutfitPage extends StatefulWidget {
  const CanvasOutfitPage({super.key});

  @override
  State<CanvasOutfitPage> createState() => _CanvasOutfitPageState();
}

class _CanvasOutfitPageState extends State<CanvasOutfitPage> {
  final WardrobeApiService _wardrobeApiService = GetIt.I<WardrobeApiService>();
  final OutfitApiService _outfitApiService = GetIt.I<OutfitApiService>();

  // Canvas capture key
  final GlobalKey _canvasRepaintKey = GlobalKey();

  // Wardrobe
  List<ClothingItem> _wardrobeItems = [];
  bool _isLoadingWardrobe = true;
  String _wardrobeFilter = 'Tất cả';

  // Canvas state
  final List<_CanvasItem> _canvasItems = [];
  String? _selectedUid;
  int _nextZIndex = 0;

  // Per-item gesture tracking
  double _gestureBaseScale = 1.0;

  // Saving
  bool _isSaving = false;

  // Category chips
  final List<String> _categories = [
    'Tất cả',
    'Áo',
    'Quần/Váy',
    'Đầm',
    'Áo khoác',
    'Giày',
    'Túi',
    'Phụ kiện',
    'Khác',
  ];

  final Map<String, String> _categoryMap = {
    'Tất cả': '',
    'Áo': 'Top',
    'Quần/Váy': 'Bottom',
    'Đầm': 'Dress',
    'Áo khoác': 'Outerwear',
    'Giày': 'Shoes',
    'Túi': 'Bag',
    'Phụ kiện': 'Accessory',
    'Khác': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _loadWardrobe();
  }

  // ── Wardrobe ──────────────────────────────────────────────────────────────

  Future<void> _loadWardrobe() async {
    setState(() => _isLoadingWardrobe = true);
    try {
      final cat = _categoryMap[_wardrobeFilter];
      final items = await _wardrobeApiService.getItems(
        category: cat == null || cat.isEmpty ? null : cat,
      );
      if (mounted) {
        setState(() {
          _wardrobeItems = items;
          _isLoadingWardrobe = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWardrobe = false);
    }
  }

  // ── Canvas actions ────────────────────────────────────────────────────────

  void _addToCanvas(ClothingItem item) {
    // Scatter position so items don't stack perfectly
    final offset = Offset(
      60.0 + (_canvasItems.length % 4) * 30.0,
      60.0 + (_canvasItems.length % 4) * 30.0,
    );
    setState(() {
      _nextZIndex++;
      final uid = '${item.id}_${DateTime.now().millisecondsSinceEpoch}';
      _canvasItems.add(
        _CanvasItem(
          uid: uid,
          clothingItem: item,
          position: offset,
          scale: 1.0,
          zIndex: _nextZIndex,
        ),
      );
      _selectedUid = uid;
    });
  }

  void _selectItem(String uid) {
    setState(() {
      _selectedUid = uid;
      // Bring to front
      _nextZIndex++;
      final item = _canvasItems.firstWhere((c) => c.uid == uid);
      item.zIndex = _nextZIndex;
    });
  }

  void _deleteSelected() {
    if (_selectedUid == null) return;
    setState(() {
      _canvasItems.removeWhere((c) => c.uid == _selectedUid);
      _selectedUid = null;
    });
  }

  void _clearCanvas() {
    setState(() {
      _canvasItems.clear();
      _selectedUid = null;
      _nextZIndex = 0;
    });
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _saveOutfit() async {
    final localStorage = GetIt.I<AuthLocalStorage>();
    final count = localStorage.getOutfitCount();
    final limit = localStorage.getOutfitLimit();

    if (limit != null && count >= limit) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                SizedBox(width: 8),
                Text(
                  'Giới hạn tủ phối đồ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Tài khoản Miễn phí chỉ được tạo tối đa $limit bộ phối đồ. Vui lòng nâng cấp Premium để phối đồ không giới hạn!',
              style: const TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SubscriptionPage()),
                  ).then((_) {
                    GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
                  });
                },
                child: const Text('Nâng cấp ngay', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (_canvasItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy thêm ít nhất 1 món đồ lên canvas trước!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Deselect to remove selection border before capture
    setState(() => _selectedUid = null);
    await Future.delayed(const Duration(milliseconds: 120));

    // Capture canvas snapshot immediately BEFORE showing the save dialog.
    // This avoids recording the keyboard resize, page transitions, or modal bottom sheet overlay.
    Uint8List? preCapturedBytes;
    Size? canvasSize;
    try {
      final boundary = _canvasRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary != null) {
        canvasSize = _canvasRepaintKey.currentContext!.size;
        final uiImage = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        preCapturedBytes = byteData!.buffer.asUint8List();
      }
    } catch (e) {
      debugPrint('Lỗi chụp canvas trước khi lưu: $e');
    }

    // Get title & isPublic from user
    final result = await _showSaveDialog();
    if (result == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      Uint8List? bytes = preCapturedBytes;
      if (bytes == null) {
        // Fallback: try capturing now if pre-capture failed
        final boundary = _canvasRepaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary == null) throw Exception('Không thể chụp canvas');

        final uiImage = await boundary.toImage(pixelRatio: 2.5);
        final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
        bytes = byteData!.buffer.asUint8List();
      }

      final activeSize = canvasSize ?? _canvasRepaintKey.currentContext?.size;
      if (activeSize == null) throw Exception('Không thể xác định kích thước canvas');

      // Build items list for API
      final apiItems = _canvasItems.map((c) {
        return <String, dynamic>{
          'WardrobeItemId': c.clothingItem.id,
          'PosX': (c.position.dx / activeSize.width).clamp(0.0, 1.0),
          'PosY': (c.position.dy / activeSize.height).clamp(0.0, 1.0),
          'Scale': c.scale,
          'ZIndex': c.zIndex,
          'Rotation': 0,
        };
      }).toList();

      await _outfitApiService.createOutfit(
        title: result['title']!,
        isPublic: result['isPublic'] == 'true',
        snapshotBytes: bytes,
        items: apiItems,
      );

      try {
        await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
      } catch (e) {
        debugPrint('Lỗi đồng bộ gói dịch vụ sau khi lưu outfit: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu trang phục thành công! 🎉'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Signal success to parent
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi lưu: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _downloadCanvasImage() async {
    if (_canvasItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy thêm ít nhất 1 món đồ lên canvas trước!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Deselect to remove selection border before capture
    setState(() => _selectedUid = null);
    await Future.delayed(const Duration(milliseconds: 120));

    try {
      final boundary = _canvasRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Không thể chụp canvas');

      final uiImage = await boundary.toImage(pixelRatio: 3.0); // High quality
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: 'vcloset_canvas_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (mounted) {
        if (result != null && result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu ảnh canvas vào Thư viện! 📲'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
            ),
          );
        } else {
          throw Exception(result?['errorMessage'] ?? 'Không thể lưu ảnh');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải ảnh về máy: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<Map<String, String>?> _showSaveDialog() async {
    String title =
        'Outfit ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    bool isPublic = false;

    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryLight],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.style_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Lưu trang phục',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: title,
                    decoration: InputDecoration(
                      labelText: 'Tên trang phục',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.edit_rounded),
                    ),
                    onChanged: (val) => title = val,
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: const Text(
                        'Chia sẻ công khai',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text('Cộng đồng có thể xem bộ này'),
                      value: isPublic,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModal(() => isPublic = val),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        'Lưu trang phục',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context, {
                        'title': title,
                        'isPublic': isPublic.toString(),
                      }),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tạo trang phục',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_canvasItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(
                Icons.download_rounded,
                color: AppColors.primary,
              ),
              tooltip: 'Tải ảnh về máy',
              onPressed: _downloadCanvasImage,
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_sweep_rounded,
                color: Colors.redAccent,
              ),
              tooltip: 'Xóa tất cả',
              onPressed: _clearCanvas,
            ),
          ],
          const SizedBox(width: 4),
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: TextButton.icon(
                    onPressed: _saveOutfit,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text(
                      'Lưu',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
        ],
      ),
      body: Column(
        children: [
          // ── Canvas area ───────────────────────────────────────────────────
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.75, // 3:4 aspect ratio
                child: _buildCanvas(),
              ),
            ),
          ),

          // ── Divider with hint ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Chọn đồ bên dưới để thêm vào canvas · Kéo để di chuyển',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withOpacity(0.65),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Category filter ───────────────────────────────────────────────
          Container(
            color: Colors.white,
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final label = _categories[index];
                final active = _wardrobeFilter == label;
                return Center(
                  child: ChoiceChip(
                    selected: active,
                    label: Text(label, style: TextStyle(fontSize: 12)),
                    labelStyle: TextStyle(
                      color: active ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (val) {
                      if (!val) return;
                      setState(() => _wardrobeFilter = label);
                      _loadWardrobe();
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                );
              },
            ),
          ),

          // ── Wardrobe picker ───────────────────────────────────────────────
          Container(
            height: 140,
            color: Colors.white,
            child: _buildWardrobePicker(),
          ),
        ],
      ),
    );
  }

  // ── Canvas widget ─────────────────────────────────────────────────────────

  Widget _buildCanvas() {
    return GestureDetector(
      // Tap on empty canvas area → deselect
      onTap: () => setState(() => _selectedUid = null),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: RepaintBoundary(
            key: _canvasRepaintKey,
            child: Container(
              color: Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Grid pattern for empty state
                  if (_canvasItems.isEmpty)
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.style_rounded,
                            size: 72,
                            color: AppColors.primary.withOpacity(0.12),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Canvas trống',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary.withOpacity(0.25),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chọn đồ từ tủ bên dưới để thêm vào',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.primary.withOpacity(0.20),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Canvas items sorted by zIndex
                  ...(_canvasItems.toList()
                        ..sort((a, b) => a.zIndex.compareTo(b.zIndex)))
                      .map((canvasItem) => _buildCanvasItem(canvasItem)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasItem(_CanvasItem canvasItem) {
    final isSelected = _selectedUid == canvasItem.uid;
    const double baseSize = 140.0;
    final double currentSize = baseSize * canvasItem.scale;

    return Positioned(
      left: canvasItem.position.dx - 12,
      top: canvasItem.position.dy - 12,
      child: GestureDetector(
        // Tap to select / bring to front
        onTap: () => _selectItem(canvasItem.uid),

        // Scale recognizer handles both pan and pinch.
        onScaleStart: (details) {
          _gestureBaseScale = canvasItem.scale;
          _selectItem(canvasItem.uid);
        },
        onScaleUpdate: (details) {
          setState(() {
            // Pan with one or many fingers.
            canvasItem.position = Offset(
              canvasItem.position.dx + details.focalPointDelta.dx,
              canvasItem.position.dy + details.focalPointDelta.dy,
            );

            // Pinch scale.
            if (details.pointerCount >= 2) {
              canvasItem.scale = (_gestureBaseScale * details.scale).clamp(
                0.3,
                4.0,
              );
            }
          });
        },

        child: Container(
          width: currentSize + 24,
          height: currentSize + 24,
          color: Colors.transparent,
          child: Stack(
            children: [
              // Item image
              Positioned(
                left: 12,
                top: 12,
                width: currentSize,
                height: currentSize,
                child: Container(
                  decoration: isSelected
                      ? BoxDecoration(
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: canvasItem.clothingItem.imageUrl.isEmpty
                        ? Container(
                            color: AppColors.secondary,
                            child: const Icon(
                              Icons.checkroom_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                          )
                        : Image.network(
                            canvasItem.clothingItem.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: AppColors.secondary,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    size: 48,
                                  ),
                                ),
                          ),
                  ),
                ),
              ),

              // Delete button (only when selected)
              if (isSelected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _deleteSelected();
                    },
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),

              // Scale handle hint (only when selected)
              if (isSelected)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.open_with_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Wardrobe picker ───────────────────────────────────────────────────────

  Widget _buildWardrobePicker() {
    if (_isLoadingWardrobe) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_wardrobeItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.checkroom_rounded,
              size: 48,
              color: AppColors.primary.withOpacity(0.2),
            ),
            const SizedBox(height: 8),
            Text(
              'Không có đồ nào',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.45),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: _wardrobeItems.length,
      separatorBuilder: (context, index) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final item = _wardrobeItems[index];
        return GestureDetector(
          onTap: () => _addToCanvas(item),
          child: _wardrobePickerCard(item),
        );
      },
    );
  }

  Widget _wardrobePickerCard(ClothingItem item) {
    return Container(
      width: 90,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl.isEmpty)
                    Container(
                      color: AppColors.secondary,
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.primary,
                        size: 30,
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFF8F9FA),
                      padding: const EdgeInsets.all(4),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              color: AppColors.secondary,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 28,
                                color: AppColors.primary,
                              ),
                            ),
                      ),
                    ),
                  // Add overlay
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              item.name.isEmpty ? 'Món đồ' : item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
