import 'dart:io';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/datasources/bg_removal_service.dart';
import '../../../../data/datasources/wardrobe_api_service.dart';
import '../../../../data/datasources/outfit_api_service.dart';
import '../../../../data/datasources/auth_local_storage.dart';
import '../../../../data/datasources/subscription_api_service.dart';
import '../profile/subscription_page.dart';
import '../../../../domain/entities/clothing_item.dart';
import 'canvas_outfit_page.dart';

class ClosetPage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const ClosetPage({super.key, this.onMenuPressed});

  @override
  State<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends State<ClosetPage>
    with SingleTickerProviderStateMixin {
  final WardrobeApiService _apiService = GetIt.I<WardrobeApiService>();
  final OutfitApiService _outfitApiService = GetIt.I<OutfitApiService>();
  final ImagePicker _picker = ImagePicker();

  // Tab controller
  late TabController _tabController;

  // Wardrobe tab state
  List<ClothingItem> _items = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';

  // Outfit collage tab state
  List<Map<String, dynamic>> _outfits = [];
  bool _isLoadingOutfits = true;

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

  final Map<String, String> _categoryLabel = {
    'Top': 'Áo',
    'Bottom': 'Quần/Váy',
    'Dress': 'Đầm',
    'Outerwear': 'Áo khoác',
    'Shoes': 'Giày',
    'Bag': 'Túi',
    'Accessory': 'Phụ kiện',
    'Other': 'Khác',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1 && _outfits.isEmpty && !_isLoadingOutfits) {
          _fetchOutfits();
        }
      }
    });
    _fetchItems();
    _fetchOutfits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);

    try {
      final category = _categoryMap[_selectedCategory];
      final result = await _apiService.getItems(
        category: category == null || category.isEmpty ? null : category,
      );

      if (mounted) {
        setState(() {
          _items = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải dữ liệu tủ đồ: $e')),
      );
    }
  }

  Future<void> _fetchOutfits() async {
    setState(() => _isLoadingOutfits = true);
    try {
      final result = await _outfitApiService.getUserOutfits();
      if (mounted) {
        setState(() {
          _outfits = result;
          _isLoadingOutfits = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingOutfits = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải trang phục: $e')),
      );
    }
  }

  Future<void> _openCanvasBuilder() async {
    if (_tabController.index != 1) {
      _tabController.animateTo(1);
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const CanvasOutfitPage(),
        fullscreenDialog: true,
      ),
    );
    if (saved == true && mounted) {
      _fetchOutfits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Container(
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
                  const SizedBox(width: 14),
                  const Text(
                    'Tủ đồ của tôi',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  // Add button only shows on wardrobe tab
                  ListenableBuilder(
                    listenable: _tabController,
                    builder: (context, _) {
                      if (_tabController.index == 0) {
                        return Row(
                          children: [
                            IconButton(
                              onPressed: _pickAndAddClothes,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              tooltip: 'Thêm đồ',
                            ),
                            IconButton(
                              onPressed: _fetchItems,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: AppColors.primary,
                                size: 28,
                              ),
                              tooltip: 'Làm mới',
                            ),
                          ],
                        );
                      }
                      // Outfit tab: + button to create new + refresh
                      return Row(
                        children: [
                          IconButton(
                            onPressed: _openCanvasBuilder,
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            tooltip: 'Tạo bộ phối mới',
                          ),
                          IconButton(
                            onPressed: _fetchOutfits,
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: AppColors.primary,
                              size: 28,
                            ),
                            tooltip: 'Làm mới',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── Tab Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.checkroom_rounded, size: 18),
                      text: 'Quần áo',
                      height: 52,
                    ),
                    Tab(
                      icon: Icon(Icons.style_rounded, size: 18),
                      text: 'Trang phục',
                      height: 52,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Tab Content ──────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWardrobeTab(),
                  _buildOutfitCollageTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 1 — Wardrobe (Quần áo)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildWardrobeTab() {
    return Column(
      children: [
        // Category filter chips
        SizedBox(
          height: 54,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            children: _categoryMap.keys.map((label) {
              final active = _selectedCategory == label;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: active,
                  onSelected: (_) {
                    if (_selectedCategory == label) return;
                    setState(() => _selectedCategory = label);
                    _fetchItems();
                  },
                  label: Text(label),
                  labelStyle: TextStyle(
                    color: active ? Colors.white : AppColors.primary,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? _emptyState()
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.68,
                          ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return FadeInUp(
                          delay: Duration(milliseconds: 45 * (index % 8)),
                          child: GestureDetector(
                            onTap: () => _showItemDetails(item),
                            child: _itemCard(item),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 2 — Outfit Collage (Bộ phối đồ)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildOutfitCollageTab() {
    if (_isLoadingOutfits) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_outfits.isEmpty) {
      return _emptyOutfitState();
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.75,
      ),
      itemCount: _outfits.length,
      itemBuilder: (context, index) {
        final outfit = _outfits[index];
        return FadeInUp(
          delay: Duration(milliseconds: 45 * (index % 8)),
          child: GestureDetector(
            onTap: () => _showOutfitDetails(outfit),
            child: _outfitCollageCard(outfit),
          ),
        );
      },
    );
  }

  Widget _outfitCollageCard(Map<String, dynamic> outfit) {
    final String title = outfit['Title']?.toString() ?? outfit['title']?.toString() ?? 'Bộ phối đồ';
    final String? snapshotUrl = outfit['CanvasSnapshotUrl']?.toString() ??
        outfit['canvasSnapshotUrl']?.toString() ??
        outfit['snapshotUrl']?.toString();
    final bool isPublic = outfit['IsPublic'] == true || outfit['isPublic'] == true;


    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Collage image
                  if (snapshotUrl == null || snapshotUrl.isEmpty)
                    Container(
                      color: AppColors.secondary,
                      child: const Icon(
                        Icons.style_rounded,
                        color: AppColors.primary,
                        size: 48,
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFF8F9FA),
                      child: Image.network(
                        snapshotUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.primary,
                            size: 48,
                          ),
                        ),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: AppColors.secondary.withOpacity(0.5),
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                      ),
                    ),
                  // Public / Private badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPublic
                            ? Colors.green.withOpacity(0.85)
                            : Colors.white.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPublic ? Icons.public_rounded : Icons.lock_rounded,
                            size: 10,
                            color: isPublic ? Colors.white : AppColors.primary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isPublic ? 'Công khai' : 'Riêng tư',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isPublic ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 13,
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOutfitDetails(Map<String, dynamic> outfit) {
    final String title = outfit['Title']?.toString() ?? outfit['title']?.toString() ?? 'Bộ phối đồ';
    final String? snapshotUrl = outfit['CanvasSnapshotUrl']?.toString() ??
        outfit['canvasSnapshotUrl']?.toString() ??
        outfit['snapshotUrl']?.toString();
    final bool isPublic = outfit['IsPublic'] == true || outfit['isPublic'] == true;
    final String createdAt = outfit['CreatedAt']?.toString() ??
        outfit['createdAt']?.toString() ?? '';
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = '${dt.day}/${dt.month}/${dt.year} lúc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Extract items from outfit (support both PascalCase and camelCase from .NET API)
    final dynamic rawItems = outfit['Items'] ?? outfit['items'];
    List<Map<String, dynamic>> items = [];
    if (rawItems is List) {
      items = rawItems.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle bar
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
                    const SizedBox(height: 16),

                    // Title row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isPublic
                                ? Colors.green.withOpacity(0.12)
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPublic ? Icons.public_rounded : Icons.lock_rounded,
                                size: 12,
                                color: isPublic ? Colors.green : AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPublic ? 'Công khai' : 'Riêng tư',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isPublic ? Colors.green : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    if (dateLabel.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Tạo lúc: $dateLabel',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary.withOpacity(0.5),
                          ),
                        ),
                      ),

                    // Snapshot / Flat-lay image
                    if (snapshotUrl != null && snapshotUrl.isNotEmpty)
                      Stack(
                        children: [
                          Container(
                            height: 320,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.network(
                                snapshotUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Center(
                                  child: Icon(Icons.broken_image_outlined, size: 64, color: AppColors.primary),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Material(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(30),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(30),
                                onTap: () => _downloadOutfitImage(snapshotUrl),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.download_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Tải ảnh',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                    // Items in outfit
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Các món trong bộ phối',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final String? imgUrl = item['imageUrl']?.toString() ??
                                item['image_url']?.toString();
                            final String itemName = item['name']?.toString() ?? 'Món đồ';
                            return Column(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: imgUrl != null && imgUrl.isNotEmpty
                                      ? Image.network(
                                          imgUrl,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              Container(
                                            width: 72,
                                            height: 72,
                                            color: AppColors.secondary,
                                            child: const Icon(Icons.checkroom_rounded, size: 30),
                                          ),
                                        )
                                      : Container(
                                          width: 72,
                                          height: 72,
                                          color: AppColors.secondary,
                                          child: const Icon(Icons.checkroom_rounded, size: 30),
                                        ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary),
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.edit_rounded),
                            label: const Text('Đổi tên', style: TextStyle(height: 1.25)),
                            onPressed: () {
                              Navigator.pop(context);
                              _renameOutfit(outfit);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Xóa', style: TextStyle(height: 1.25)),
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmDeleteOutfit(outfit);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _renameOutfit(Map<String, dynamic> outfit) async {
    final String title = outfit['Title']?.toString() ?? outfit['title']?.toString() ?? '';
    final String outfitId = outfit['Id']?.toString() ?? outfit['id']?.toString() ?? '';
    if (outfitId.isEmpty) return;

    final TextEditingController textController = TextEditingController(text: title);

    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Đổi tên trang phục'),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Tên trang phục',
              hintText: 'Nhập tên mới...',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) {
                  Navigator.pop(context, text);
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      _showLoadingDialog('Đang đổi tên...');
      try {
        await _outfitApiService.updateOutfitTitle(outfitId, newTitle);
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đổi tên trang phục thành công!')),
        );
        _fetchOutfits();
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: Đổi tên thất bại. $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteOutfit(Map<String, dynamic> outfit) async {
    final String title = outfit['Title']?.toString() ?? outfit['title']?.toString() ?? 'Bộ phối đồ';
    final String outfitId = outfit['Id']?.toString() ?? outfit['id']?.toString() ?? '';
    if (outfitId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa trang phục "$title" không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _showLoadingDialog('Đang xóa...');
      try {
        await _outfitApiService.deleteOutfit(outfitId);
        try {
          await GetIt.I<SubscriptionApiService>().syncSubscriptionStatus();
        } catch (_) {}
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa trang phục thành công!')),
        );
        _fetchOutfits();
      } catch (e) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: Xóa thất bại. $e')),
        );
      }
    }
  }

  Future<void> _downloadOutfitImage(String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy link ảnh để tải!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _showLoadingDialog('Đang tải ảnh về máy...');

    try {
      final dio = Dio();
      final response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data as List<int>),
        quality: 100,
        name: "vcloset_outfit_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        if (result != null && result['isSuccess'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Lưu thành công! Đã lưu ảnh bộ phối vào Thư viện. 📲'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception(result?['errorMessage'] ?? 'Không thể lưu ảnh vào thư viện.');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải ảnh về máy: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _emptyOutfitState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.style_rounded,
            size: 76,
            color: AppColors.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có trang phục nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hãy phối đồ từ tab "Phòng thử đồ".',
            style: TextStyle(color: AppColors.primary.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Shared helpers
  // ─────────────────────────────────────────────────────────────────

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(width: 20),
                Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showItemDetails(ClothingItem item) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chi tiết trang phục',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: item.imageUrl.isEmpty
                      ? Container(
                          height: 200,
                          width: 200,
                          color: AppColors.secondary,
                          child: const Icon(Icons.image_not_supported_outlined, size: 64),
                        )
                      : Image.network(
                          item.imageUrl,
                          height: 220,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            width: 200,
                            color: AppColors.secondary,
                            child: const Icon(Icons.broken_image_outlined, size: 64),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              _detailRow('Tên món đồ', item.name.isEmpty ? 'Chưa đặt tên' : item.name),
              const Divider(),
              _detailRow('Thương hiệu', item.brand?.isNotEmpty == true ? item.brand! : 'Chưa có thương hiệu'),
              const Divider(),
              _detailRow('Phân loại', _categoryLabel[item.category] ?? item.category),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Chỉnh sửa', style: TextStyle(height: 1.25)),
                      onPressed: () {
                        Navigator.pop(context);
                        _showEditDialog(item);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete_forever_rounded),
                      label: const Text('Xóa', style: TextStyle(height: 1.25)),
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(item);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(ClothingItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa "${item.name}" khỏi tủ đồ không?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _showLoadingDialog('Đang xóa...');
      final deleted = await _apiService.deleteItem(item.id);
      Navigator.pop(context);

      if (deleted) {
        // Giảm số lượng tủ đồ cục bộ
        final localStorage = GetIt.I<AuthLocalStorage>();
        final currentCount = localStorage.getWardrobeItemCount();
        await localStorage.saveWardrobeItemCount(currentCount > 0 ? currentCount - 1 : 0);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa món đồ khỏi tủ đồ thành công!')),
        );
        _fetchItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Xóa thất bại.')),
        );
      }
    }
  }

  Future<void> _showEditDialog(ClothingItem item) async {
    String name = item.name;
    String brand = item.brand ?? '';
    String category = item.category;

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

    String currentCatName = 'Khác';
    for (var entry in categoryOptions.entries) {
      if (entry.value.toLowerCase() == item.category.toLowerCase()) {
        currentCatName = entry.key;
        break;
      }
    }
    category = categoryOptions[currentCatName]!;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Chỉnh sửa thông tin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Tên món đồ'),
                      onChanged: (val) => name = val,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: brand,
                      decoration: const InputDecoration(labelText: 'Thương hiệu'),
                      onChanged: (val) => brand = val,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: currentCatName,
                      decoration: const InputDecoration(labelText: 'Loại trang phục'),
                      items: categoryOptions.keys.map((String key) {
                        return DropdownMenuItem<String>(
                          value: key,
                          child: Text(key),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            currentCatName = val;
                            category = categoryOptions[val]!;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'name': name,
                      'brand': brand,
                      'category': category,
                    });
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      _showLoadingDialog('Đang cập nhật...');
      final updated = await _apiService.updateItem(item.id, result);
      Navigator.pop(context);

      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công!')),
        );
        _fetchItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Cập nhật thất bại.')),
        );
      }
    }
  }

  Future<Map<String, String>?> _showDetailsDialog(File imageFile) async {
    String name = 'Đồ mới thêm ${DateTime.now().second}';
    String category = 'Top';
    String currentCatName = 'Áo';

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
                            style: TextStyle(fontSize: 11, color: AppColors.primary, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
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

  Future<void> _pickAndAddClothes() async {
    _showBgRemovalGuidelines();
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
                    Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: 8),
                    Text(
                      'Lưu ý chụp ảnh tách nền',
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
                              Icon(Icons.checkroom_rounded, size: 36, color: Colors.green.shade700),
                              const SizedBox(height: 6),
                              const Text(
                                'Ảnh phẳng / Treo',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nền trơn, rõ nét',
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
                              Icon(Icons.photo_filter_rounded, size: 36, color: Colors.red.shade700),
                              const SizedBox(height: 6),
                              Text(
                                'Không nên chọn',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nền rối, nhiều đồ vật',
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
                              TextSpan(text: 'Trải phẳng quần áo trên sàn đơn sắc hoặc treo trên móc trước tường trơn. Chụp thẳng từ trên xuống hoặc chính diện, đủ ánh sáng.'),
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
                              TextSpan(text: 'Chụp quần áo bị nhăn nheo, gấp nếp. Tránh hậu cảnh có quá nhiều đồ đạc xung quanh hoặc có màu nền trùng với màu quần áo.'),
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
                      _pickAndAddClothesSource(ImageSource.camera);
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
                      _pickAndAddClothesSource(ImageSource.gallery);
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

  Future<void> _pickAndAddClothesSource(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image == null) return;

      final details = await _showDetailsDialog(File(image.path));
      if (details == null) return;

      // Kiểm tra Credits trước khi thực hiện
      final localStorage = GetIt.I<AuthLocalStorage>();
      final bgCredits = localStorage.getBgRemovalCredits();
      if (bgCredits <= 0) {
        if (mounted) {
          SubscriptionPage.showOutOfCreditsSheet(context, isBgRemoval: true);
        }
        return;
      }

      if (!mounted) return;
      bool isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Đang tách nền & lưu vào tủ đồ...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => isDialogOpen = false);

      final bgRemovalService = GetIt.I<BgRemovalService>();
      final Uint8List? resultBytes = await bgRemovalService.removeBackground(File(image.path));

      // Trừ 1 credit xóa nền
      await localStorage.updateCredits(bgCredits: bgCredits - 1);

      File fileToUpload = File(image.path);
      if (resultBytes != null) {
        final tempFile = File('${Directory.systemTemp.path}/transparent_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(resultBytes);
        fileToUpload = tempFile;
      }

      final newItem = await _apiService.uploadAndCreateItem(
        imageFile: fileToUpload,
        category: details['category']!,
        name: details['name']!,
      );

      if (mounted && isDialogOpen) {
        Navigator.pop(context);
      }

      if (newItem != null) {
        // Tăng số lượng tủ đồ cục bộ
        final currentCount = localStorage.getWardrobeItemCount();
        await localStorage.saveWardrobeItemCount(currentCount + 1);

        _fetchItems();

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Thêm thành công!'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(fileToUpload, height: 150),
                  const SizedBox(height: 10),
                  Text('Tên: ${newItem.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('Món đồ đã được tách nền và lưu vào tủ đồ.', style: TextStyle(color: Colors.green, fontSize: 12)),
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
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lỗi: Không thể lưu món đồ mới.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        String errorMsg = e.toString();
        if (e is DioException) {
          if (e.response?.statusCode == 413) {
            errorMsg = 'Ảnh tải lên quá lớn (giới hạn 30MB). Vui lòng chọn hoặc chụp ảnh nhẹ hơn.';
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

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.dry_cleaning_rounded,
            size: 76,
            color: AppColors.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chưa có món đồ nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hãy chụp món đồ đầu tiên từ tab Camera.',
            style: TextStyle(color: AppColors.primary.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(ClothingItem item) {
    final imageUrl = item.imageUrl;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl.isEmpty)
                    Container(
                      color: AppColors.secondary,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFF8F9FA),
                      width: double.infinity,
                      height: double.infinity,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: AppColors.secondary,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _categoryLabel[item.category] ?? item.category,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name.isEmpty ? 'Món đồ chưa đặt tên' : item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
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
