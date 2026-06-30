import 'dart:async';
import 'dart:ui' as ui;
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
import '../../../../data/datasources/closet_api_service.dart';
import '../../../../data/datasources/outfit_api_service.dart';
import '../../../../data/datasources/auth_local_storage.dart';
import '../../../../data/datasources/subscription_api_service.dart';
import '../../../../data/datasources/ad_service.dart';
import '../profile/subscription_page.dart';
import '../../../../domain/entities/clothing_item.dart';
import '../../../../data/datasources/gemini_api_service.dart';
import 'canvas_outfit_page.dart';
import '../outfit/outfit_page.dart';

enum ClosetViewMode { closet, items }

class ClosetPage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final Function(int)? onNavigateTo;
  const ClosetPage({super.key, this.onMenuPressed, this.onNavigateTo});

  @override
  State<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends State<ClosetPage> with TickerProviderStateMixin {
  final WardrobeApiService _apiService = GetIt.I<WardrobeApiService>();
  final OutfitApiService _outfitApiService = GetIt.I<OutfitApiService>();
  final ClosetApiService _closetApiService = GetIt.I<ClosetApiService>();
  final ImagePicker _picker = ImagePicker();

  // Tab controller
  late TabController _tabController;

  // Cabinet door animation state
  AnimationController? _cabinetController;
  Animation<double>? _cabinetOpacityAnimation;
  bool _showCabinet = true;

  // View Mode
  ClosetViewMode _viewMode = ClosetViewMode.closet;

  // Wardrobe tab state
  List<ClothingItem> _items = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';

  // Custom closets list from BE
  List<Map<String, dynamic>> _userClosets = [];
  String? _selectedClosetId;
  String? _selectedClosetName;

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

  final Map<String, String> _categoryEmojiLabel = {
    'Tất cả': '✨',
    'Áo': '👕',
    'Quần/Váy': '👖',
    'Đầm': '👗',
    'Áo khoác': '🧥',
    'Giày': '👟',
    'Túi': '👜',
    'Phụ kiện': '🕶️',
    'Khác': '📦',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 1 &&
            _outfits.isEmpty &&
            !_isLoadingOutfits) {
          _fetchOutfits();
        }
      }
    });

    // Initialize cabinet animation
    final controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _cabinetController = controller;

    _cabinetOpacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
      ),
    );

    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showCabinet = false;
        });
      }
    });

    // Start opening cabinet doors automatically after 500ms
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && controller.status == AnimationStatus.dismissed) {
        controller.forward();
      }
    });

    _fetchItems();
    _fetchOutfits();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cabinetController?.dispose();
    super.dispose();
  }

  Future<void> _fetchItems() async {
    setState(() => _isLoading = true);

    try {
      final closetsResult = await _closetApiService.getClosets();

      final category = _categoryMap[_selectedCategory];
      final result = await _apiService.getItems(
        category: category == null || category.isEmpty ? null : category,
        closetId: _selectedClosetId,
      );

      if (mounted) {
        setState(() {
          _userClosets = closetsResult;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tải trang phục: $e')));
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
      body: Stack(
        children: [
          SafeArea(
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
                            if (_selectedClosetId != null) {
                              setState(() {
                                _selectedClosetId = null;
                                _selectedClosetName = null;
                                _viewMode = ClosetViewMode.closet;
                                _fetchItems();
                              });
                            } else {
                              final scaffold = Scaffold.maybeOf(context);
                              if (scaffold != null && scaffold.hasDrawer) {
                                scaffold.openDrawer();
                              } else {
                                widget.onMenuPressed?.call();
                              }
                            }
                          },
                          icon: Icon(
                            _selectedClosetId != null
                                ? Icons.arrow_back_rounded
                                : Icons.menu_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: _tabController,
                          builder: (context, _) {
                            if (_tabController.index == 0) {
                              if (_selectedClosetId != null) {
                                return Text(
                                  _selectedClosetName ?? 'Chi tiết tủ đồ',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              }
                              return _buildHeaderDropdown();
                            }
                            return const Text(
                              'Bộ phối đồ',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Add button only shows on wardrobe tab
                      ListenableBuilder(
                        listenable: _tabController,
                        builder: (context, _) {
                          if (_tabController.index == 0) {
                            return Row(
                              children: [
                                if (_selectedClosetId != null) ...[
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
                                if (_viewMode == ClosetViewMode.items)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
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
                          icon: Icon(Icons.door_sliding_rounded, size: 18),
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
                    children: [_buildWardrobeTab(), _buildOutfitCollageTab()],
                  ),
                ),
              ],
            ),
          ),
          _buildCabinetOverlay(),
        ],
      ),
    );
  }

  Widget _buildCabinetOverlay() {
    if (!_showCabinet ||
        _cabinetController == null ||
        _cabinetOpacityAnimation == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _cabinetController!,
      builder: (context, child) {
        final slideProgress = _cabinetController!.value; // 0.0 to 1.0
        final opacity = _cabinetOpacityAnimation!.value;

        if (opacity <= 0.0) {
          return const SizedBox.shrink();
        }

        return Positioned.fill(
          child: Opacity(
            opacity: opacity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final halfWidth = constraints.maxWidth / 2;
                final height = constraints.maxHeight;

                // Slide translation values using a smooth spring curve
                final curvedValue = Curves.easeInOutQuart.transform(
                  slideProgress,
                );
                final leftSlide = -halfWidth * curvedValue;
                final rightSlide = halfWidth * curvedValue;

                return Stack(
                  children: [
                    // Cabinet Left Door
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: halfWidth,
                      child: Transform.translate(
                        offset: Offset(leftSlide, 0),
                        child: _buildFrostedSlidingDoor(
                          isLeft: true,
                          width: halfWidth,
                          height: height,
                        ),
                      ),
                    ),

                    // Cabinet Right Door
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: halfWidth,
                      child: Transform.translate(
                        offset: Offset(rightSlide, 0),
                        child: _buildFrostedSlidingDoor(
                          isLeft: false,
                          width: halfWidth,
                          height: height,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildFrostedSlidingDoor({
    required bool isLeft,
    required double width,
    required double height,
  }) {
    final goldColor = const Color(0xFFD4AF37);
    final glassColor = const Color(
      0xFF1E2135,
    ).withOpacity(0.35); // Sleek translucent dark glass
    final metalFrameColor = const Color(0xFF3F4260);

    return GestureDetector(
      onTap: () {
        final controller = _cabinetController;
        if (controller != null &&
            !controller.isAnimating &&
            controller.value == 0) {
          controller.forward();
        }
      },
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(
                left: BorderSide(
                  color: isLeft ? metalFrameColor : goldColor.withOpacity(0.4),
                  width: isLeft ? 4 : 1.5,
                ),
                right: BorderSide(
                  color: !isLeft ? metalFrameColor : goldColor.withOpacity(0.4),
                  width: !isLeft ? 4 : 1.5,
                ),
                top: BorderSide(color: metalFrameColor, width: 3),
                bottom: BorderSide(color: metalFrameColor, width: 4),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Elegant thin grid divider on the glass for showroom aesthetic
                Column(
                  children: [
                    const Spacer(flex: 1),
                    Container(
                      height: 1.5,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    const Spacer(flex: 1),
                    Container(
                      height: 1.5,
                      color: Colors.white.withOpacity(0.08),
                    ),
                    const Spacer(flex: 1),
                  ],
                ),

                // Subtle gold corner borders
                Positioned(
                  top: 20,
                  left: isLeft ? 20 : null,
                  right: !isLeft ? 20 : null,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: goldColor.withOpacity(0.8),
                          width: 2,
                        ),
                        left: isLeft
                            ? BorderSide(
                                color: goldColor.withOpacity(0.8),
                                width: 2,
                              )
                            : BorderSide.none,
                        right: !isLeft
                            ? BorderSide(
                                color: goldColor.withOpacity(0.8),
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: isLeft ? 20 : null,
                  right: !isLeft ? 20 : null,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: goldColor.withOpacity(0.8),
                          width: 2,
                        ),
                        left: isLeft
                            ? BorderSide(
                                color: goldColor.withOpacity(0.8),
                                width: 2,
                              )
                            : BorderSide.none,
                        right: !isLeft
                            ? BorderSide(
                                color: goldColor.withOpacity(0.8),
                                width: 2,
                              )
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Premium gold inline accent trim
                Container(
                  margin: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: goldColor.withOpacity(0.12),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),

                // Center handle
                Positioned(
                  top: height / 2 - 60,
                  right: isLeft ? 10 : null,
                  left: !isLeft ? 10 : null,
                  child: Container(
                    width: 8,
                    height: 120,
                    decoration: BoxDecoration(
                      color: goldColor,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: Offset(isLeft ? 2 : -2, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 2,
                        height: 100,
                        color: Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setViewMode(ClosetViewMode mode) {
    setState(() {
      _viewMode = mode;
      _selectedClosetId = null;
      _selectedClosetName = null;
      _selectedCategory = 'Tất cả';
      _fetchItems();
    });
  }

  Widget _buildHeaderDropdown() {
    return PopupMenuButton<ClosetViewMode>(
      offset: const Offset(0, 40),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: _setViewMode,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<ClosetViewMode>>[
        PopupMenuItem<ClosetViewMode>(
          value: ClosetViewMode.closet,
          child: Row(
            children: const [
              Icon(
                Icons.door_sliding_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Xem tủ đồ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<ClosetViewMode>(
          value: ClosetViewMode.items,
          child: Row(
            children: const [
              Icon(
                Icons.checkroom_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              SizedBox(width: 12),
              Text(
                'Xem các món đồ',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              _viewMode == ClosetViewMode.closet ? 'Tủ đồ' : 'Xem các món đồ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.primary,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildClosetView() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      children: [
        _buildFeatureButtonsRow(),
        const SizedBox(height: 24),
        _buildClosetGrid(),
      ],
    );
  }

  Widget _buildFeatureButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildFeatureItem(
          icon: Icons.cloud_upload_outlined,
          label: 'Nhập món đồ',
          onTap: _pickAndAddClothes,
        ),
        _buildFeatureItem(
          icon: Icons.trending_up_rounded,
          label: 'Thống kê phong cách',
          onTap: _showStyleStatsBottomSheet,
        ),
        _buildFeatureItem(
          icon: Icons.auto_awesome_outlined,
          label: 'Tân trang',
          badgeText: 'AI',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tính năng Tân trang AI đang được phát triển.'),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String label,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.secondary.withOpacity(0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 24),
                ),
                if (badgeText != null)
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: badgeText == 'AI'
                            ? const Color(0xFF8A2BE2)
                            : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClosetGrid() {
    final cardCount = 1 + _userClosets.length + 1;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.62,
      ),
      itemCount: cardCount,
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildAllItemsCard();
        } else if (index == cardCount - 1) {
          return _buildCreateClosetCard();
        } else {
          final closet = _userClosets[index - 1];
          return _buildCustomClosetCard(closet);
        }
      },
    );
  }

  Widget _buildCustomClosetCard(Map<String, dynamic> closet) {
    final String closetId = (closet['id'] ?? closet['Id'])?.toString() ?? '';
    final String name =
        (closet['name'] ?? closet['Name'])?.toString() ?? 'Tủ đồ';
    final int itemCount = closet['itemCount'] ?? closet['ItemCount'] ?? 0;
    final List<dynamic> thumbnailUrls =
        closet['thumbnailUrls'] ?? closet['ThumbnailUrls'] ?? [];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedClosetId = closetId;
              _selectedClosetName = name;
              _viewMode = ClosetViewMode.items;
            });
            _fetchItems();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomCollageGrid(thumbnailUrls, closetId, itemCount),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      color: AppColors.primaryLight,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // ── Nút 3 chấm: Đổi tên & Xóa ──
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 18,
                        icon: const Icon(
                          Icons.more_vert_rounded,
                          color: AppColors.primaryLight,
                        ),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        offset: const Offset(0, 28),
                        onSelected: (value) async {
                          if (value == 'rename') {
                            await _renameCloset(
                              closetId: closetId,
                              currentName: name,
                            );
                          } else if (value == 'delete') {
                            await _deleteCloset(closetId: closetId, name: name);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'rename',
                            height: 44,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Đổi tên',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            height: 44,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: Colors.redAccent,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Xóa tủ đồ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    '$itemCount món đồ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCollageGrid(
    List<dynamic> urls,
    String closetId,
    int totalCount,
  ) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F2F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            GestureDetector(
              onTap: () {
                _pickAndAddClothes(closetId: closetId);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryLight,
                  size: 28,
                ),
              ),
            ),
            _buildCustomCollageCell(urls, 0, totalCount),
            _buildCustomCollageCell(urls, 1, totalCount),
            _buildCustomCollageCell(urls, 2, totalCount, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomCollageCell(
    List<dynamic> urls,
    int index,
    int totalCount, {
    bool isLast = false,
  }) {
    if (index >= urls.length) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.checkroom_rounded,
          color: AppColors.primary.withOpacity(0.15),
          size: 24,
        ),
      );
    }

    final String imageUrl = urls[index].toString();
    final remainingCount = totalCount - 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                color: AppColors.primary.withOpacity(0.2),
              ),
            )
          else
            Icon(
              Icons.checkroom_rounded,
              color: AppColors.primary.withOpacity(0.15),
            ),
          if (isLast && remainingCount > 0)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllItemsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _viewMode = ClosetViewMode.items;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCollageGrid(),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.push_pin_rounded,
                      color: AppColors.primaryLight,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tất cả món đồ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 18),
                  child: Text(
                    '${_items.length} món đồ',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.primary.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollageGrid() {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F2F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            GestureDetector(
              onTap: _pickAndAddClothes,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: AppColors.primaryLight,
                  size: 28,
                ),
              ),
            ),
            _buildCollageCell(0),
            _buildCollageCell(1),
            _buildCollageCell(2, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCollageCell(int index, {bool isLast = false}) {
    if (index >= _items.length) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          Icons.checkroom_rounded,
          color: AppColors.primary.withOpacity(0.15),
          size: 24,
        ),
      );
    }

    final item = _items[index];
    final remainingCount = _items.length - 3;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.imageUrl.isNotEmpty)
            Image.network(
              item.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.broken_image_outlined,
                color: AppColors.primary.withOpacity(0.2),
              ),
            )
          else
            Icon(
              Icons.checkroom_rounded,
              color: AppColors.primary.withOpacity(0.15),
            ),
          if (isLast && remainingCount > 0)
            Container(
              color: Colors.black.withOpacity(0.45),
              child: Center(
                child: Text(
                  '+$remainingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCreateClosetCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: AppColors.secondary.withOpacity(0.8),
          strokeWidth: 1.2,
          gap: 4.0,
          radius: 20.0,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _showCreateClosetDialog,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.door_sliding_outlined,
                      color: AppColors.primaryLight,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tạo tủ đồ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateClosetDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Tạo tủ đồ mới',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              hintText: 'Nhập tên tủ đồ (ví dụ: Đồ đi tiệc, Đồ mùa đông)',
              hintStyle: TextStyle(fontSize: 13, color: AppColors.muted),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.primaryLight),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  _showLoadingDialog('Đang tạo tủ đồ...');
                  final success = await _closetApiService.createCloset(name);
                  if (mounted) {
                    Navigator.pop(context); // Close loading dialog
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã tạo tủ đồ "$name" thành công!'),
                        ),
                      );
                      _fetchItems();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Không thể tạo tủ đồ. Vui lòng thử lại!',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Tạo', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Dùng cho nút 3 chấm trong card tủ đồ — đổi tên theo closetId cụ thể

  Future<void> _renameCloset({
    required String closetId,
    required String currentName,
  }) async {
    final textController = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Đổi tên tủ đồ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          content: TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Tên tủ đồ mới',
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.primaryLight),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                if (text.isNotEmpty) Navigator.pop(dialogContext, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Lưu', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != currentName) {
      _showLoadingDialog('Đang đổi tên tủ đồ...');
      final success = await _closetApiService.updateCloset(closetId, newName);
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          if (_selectedClosetId == closetId) {
            setState(() => _selectedClosetName = newName);
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã đổi tên tủ đồ thành "$newName"')),
          );
          _fetchItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đổi tên tủ đồ thất bại. Vui lòng thử lại!'),
            ),
          );
        }
      }
    }
  }

  /// Dùng cho nút 3 chấm trong card tủ đồ — xóa theo closetId cụ thể
  Future<void> _deleteCloset({
    required String closetId,
    required String name,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Xác nhận xóa tủ đồ',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            'Bạn có chắc chắn muốn xóa tủ đồ "$name" không?\n\nTất cả quần áo trong tủ đồ sẽ được tự động chuyển về tủ đồ chung (không bị xóa mất).',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Hủy',
                style: TextStyle(color: AppColors.primaryLight),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Xóa', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _showLoadingDialog('Đang xóa tủ đồ...');
      final success = await _closetApiService.deleteCloset(closetId);
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã xóa tủ đồ "$name" thành công!')),
          );
          if (_selectedClosetId == closetId) {
            setState(() {
              _selectedClosetId = null;
              _selectedClosetName = null;
              _viewMode = ClosetViewMode.closet;
            });
          }
          _fetchItems();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa tủ đồ thất bại. Vui lòng thử lại!'),
            ),
          );
        }
      }
    }
  }

  void _showStyleStatsBottomSheet() {
    final int totalCount = _items.length;
    final int topCount = _items
        .where((i) => i.category.toLowerCase() == 'top')
        .length;
    final int bottomCount = _items
        .where((i) => i.category.toLowerCase() == 'bottom')
        .length;
    final int dressCount = _items
        .where((i) => i.category.toLowerCase() == 'dress')
        .length;
    final int outerwearCount = _items
        .where((i) => i.category.toLowerCase() == 'outerwear')
        .length;
    final int shoesCount = _items
        .where((i) => i.category.toLowerCase() == 'shoes')
        .length;
    final int bagCount = _items
        .where((i) => i.category.toLowerCase() == 'bag')
        .length;
    final int otherCount =
        totalCount -
        (topCount +
            bottomCount +
            dressCount +
            outerwearCount +
            shoesCount +
            bagCount);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Thống kê tủ đồ 📊',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Bạn đang sở hữu tổng cộng $totalCount món đồ thời trang.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.primary.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 20),
              _buildStatRow('👕 Áo', topCount, totalCount),
              _buildStatRow('👖 Quần / Váy', bottomCount, totalCount),
              _buildStatRow('👗 Đầm', dressCount, totalCount),
              _buildStatRow('🧥 Áo khoác', outerwearCount, totalCount),
              _buildStatRow('👟 Giày', shoesCount, totalCount),
              _buildStatRow('👜 Túi xách', bagCount, totalCount),
              _buildStatRow('📦 Khác', otherCount, totalCount),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatRow(String title, int count, int total) {
    final double percentage = total > 0 ? (count / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: AppColors.primary.withOpacity(0.06),
                color: AppColors.primary,
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count (${(percentage * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 1 — Wardrobe (Quần áo)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildCategoryFilterChips() {
    final categories = _categoryMap.keys.toList();
    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final label = categories[i];
          final active = _selectedCategory == label;
          final displayLabel = _categoryEmojiLabel[label] ?? label;
          return GestureDetector(
            onTap: () {
              if (_selectedCategory == label) return;
              setState(() => _selectedCategory = label);
              _fetchItems();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: active
                    ? const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: active ? null : Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: active
                        ? AppColors.primary.withOpacity(0.28)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: active ? 8 : 4,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                displayLabel,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.primary,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 18,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWardrobeTab() {
    if (_viewMode == ClosetViewMode.closet) {
      return _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildClosetView();
    }

    return Column(
      children: [
        _buildCategoryFilterChips(),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? _emptyState()
              : _buildWardrobeBody(),
        ),
      ],
    );
  }

  Widget _buildWardrobeBody() {
    // Filter by selected category if not 'Tất cả'
    if (_selectedCategory != 'Tất cả') {
      return GridView.builder(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.72,
        ),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return FadeInUp(
            delay: Duration(milliseconds: 35 * (index % 9)),
            child: GestureDetector(
              onTap: () => _showItemDetails(item),
              child: _InteractiveClothingItemCard(
                item: item,
                categoryLabel: _categoryLabel,
              ),
            ),
          );
        },
      );
    }

    // "Tất cả" — Premium wardrobe compartment view
    final hangingItems = _items.where((item) {
      final c = item.category.toLowerCase();
      return c == 'top' || c == 'dress' || c == 'outerwear';
    }).toList();
    final bottomItems = _items
        .where((item) => item.category.toLowerCase() == 'bottom')
        .toList();
    final shoesBags = _items.where((item) {
      final c = item.category.toLowerCase();
      return c == 'shoes' || c == 'bag';
    }).toList();
    final otherItems = _items.where((item) {
      final c = item.category.toLowerCase();
      return c == 'accessory' || c == 'other';
    }).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
      children: [
        _buildClosetCompartment(
          icon: '👗',
          title: 'Đồ treo',
          subtitle: 'Áo · Đầm · Áo khoác',
          sectionType: 'hanger',
          sectionItems: hangingItems,
        ),
        _buildClosetCompartment(
          icon: '👖',
          title: 'Quần & Váy',
          subtitle: 'Đồ gấp · Kệ xếp',
          sectionType: 'shelf',
          sectionItems: bottomItems,
        ),
        _buildClosetCompartment(
          icon: '👟',
          title: 'Giày & Túi',
          subtitle: 'Kệ giày · Móc túi',
          sectionType: 'rack',
          sectionItems: shoesBags,
        ),
        _buildClosetCompartment(
          icon: '✨',
          title: 'Phụ kiện',
          subtitle: 'Ngăn kéo · Phụ kiện',
          sectionType: 'drawer',
          sectionItems: otherItems,
        ),
      ],
    );
  }

  Widget _buildClosetCompartment({
    required String icon,
    required String title,
    required String subtitle,
    required String sectionType,
    required List<ClothingItem> sectionItems,
  }) {
    if (sectionItems.isEmpty) return const SizedBox.shrink();

    final bool isHanger = sectionType == 'hanger';
    final bool isRack = sectionType == 'rack';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Compartment Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.05),
                  AppColors.secondary.withOpacity(0.12),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.secondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Icon compartment badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.12),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.primary.withOpacity(0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Item count badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${sectionItems.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Hanger Rod visual for hanging items ────────────────────
          if (isHanger)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Row(
                children: [
                  // Left bracket
                  Container(
                    width: 6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0B0B0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFB8B8B8),
                            Color(0xFFE8E8E8),
                            Color(0xFFB8B8B8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 3,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB0B0B0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            ),

          // ── Shelf edge for rack-type sections ──────────────────────
          if (isRack)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              height: 4,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFC0C0C0),
                    Color(0xFFE8E8E8),
                    Color(0xFFC0C0C0),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),

          // ── Horizontal scroll strip ────────────────────────────────
          SizedBox(
            height: isHanger
                ? 200
                : isRack
                ? 140
                : 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              itemCount: sectionItems.length,
              itemBuilder: (context, index) {
                final item = sectionItems[index];
                return FadeInRight(
                  delay: Duration(milliseconds: 40 * (index % 7)),
                  child: GestureDetector(
                    onTap: () => _showItemDetails(item),
                    child: _buildCompactClothingCard(
                      item: item,
                      cardWidth: isHanger
                          ? 110.0
                          : isRack
                          ? 100.0
                          : 110.0,
                      isHanger: isHanger,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCompactClothingCard({
    required ClothingItem item,
    required double cardWidth,
    required bool isHanger,
  }) {
    return Container(
      width: cardWidth,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Item image
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl.isEmpty)
                    Container(
                      color: AppColors.secondary.withOpacity(0.3),
                      child: const Icon(
                        Icons.checkroom_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    )
                  else
                    Container(
                      color: const Color(0xFFF5F5F5),
                      padding: const EdgeInsets.all(6),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.primaryLight,
                              size: 28,
                            ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Name label
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
            child: Text(
              item.name.isEmpty ? 'Chưa đặt tên' : item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // TAB 2 — Outfit Lookbook (Bộ phối đồ)
  // ─────────────────────────────────────────────────────────────────

  Widget _buildOutfitCollageTab() {
    if (_isLoadingOutfits) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Đang tải bộ phối...',
              style: TextStyle(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }
    if (_outfits.isEmpty) {
      return _emptyOutfitState();
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Header banner ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tủ trang phục của tôi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_outfits.length} bộ phối đã tạo',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_outfits.length} bộ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Featured card (first outfit, full-width hero) ──────────────
        SliverToBoxAdapter(
          child: FadeInDown(
            child: GestureDetector(
              onTap: () => _showOutfitDetails(_outfits[0]),
              child: _buildFeaturedOutfitCard(_outfits[0]),
            ),
          ),
        ),

        // ── Grid of remaining outfits ─────────────────────────────────
        if (_outfits.length > 1) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.grid_view_rounded,
                    size: 16,
                    color: AppColors.primaryLight,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'T\u1ea5t c\u1ea3 b\u1ed9 ph\u1ed1i',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((context, index) {
                final outfit = _outfits[index + 1];
                return FadeInUp(
                  delay: Duration(milliseconds: 45 * (index % 6)),
                  child: GestureDetector(
                    onTap: () => _showOutfitDetails(outfit),
                    child: _outfitCollageCard(outfit),
                  ),
                );
              }, childCount: _outfits.length - 1),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.82,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _buildFeaturedOutfitCard(Map<String, dynamic> outfit) {
    final String title =
        outfit['Title']?.toString() ??
        outfit['title']?.toString() ??
        'Bộ phối đồ';
    final String? snapshotUrl =
        outfit['CanvasSnapshotUrl']?.toString() ??
        outfit['canvasSnapshotUrl']?.toString() ??
        outfit['snapshotUrl']?.toString();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8F4FF), Color(0xFFEDE8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Image
            if (snapshotUrl != null && snapshotUrl.isNotEmpty)
              Positioned.fill(
                child: Image.network(
                  snapshotUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    size: 60,
                    color: AppColors.primaryLight,
                  ),
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.style_rounded,
                  size: 90,
                  color: AppColors.muted,
                ),
              ),
            // Strong gradient overlay at bottom
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      AppColors.primary.withOpacity(0.85),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),
            // "NỔI BẬT" label top-left with shimmer
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFF0C040)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.white, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'NỔI BẬT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info bottom
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 12,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Nhấn để xem chi tiết',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.75),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outfitCollageCard(Map<String, dynamic> outfit) {
    final String title =
        outfit['Title']?.toString() ??
        outfit['title']?.toString() ??
        'Bộ phối đồ';
    final String? snapshotUrl =
        outfit['CanvasSnapshotUrl']?.toString() ??
        outfit['canvasSnapshotUrl']?.toString() ??
        outfit['snapshotUrl']?.toString();
    final String createdAt =
        outfit['CreatedAt']?.toString() ??
        outfit['createdAt']?.toString() ??
        '';
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel = '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {}
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF8F4FF), Color(0xFFEDE8FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Outfit image
            if (snapshotUrl == null || snapshotUrl.isEmpty)
              const Center(
                child: Icon(
                  Icons.style_rounded,
                  color: AppColors.primaryLight,
                  size: 44,
                ),
              )
            else
              Positioned.fill(
                child: Image.network(
                  snapshotUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.primaryLight,
                      size: 34,
                    ),
                  ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                  progress.expectedTotalBytes!
                            : null,
                        strokeWidth: 2,
                        color: AppColors.primaryLight,
                      ),
                    );
                  },
                ),
              ),
            // Bottom gradient + title
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 24, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.primary.withOpacity(0.82),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: 13,
                        shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                      ),
                    ),
                    if (dateLabel.isNotEmpty)
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOutfitDetails(Map<String, dynamic> outfit) {
    final String title =
        outfit['Title']?.toString() ??
        outfit['title']?.toString() ??
        'Bộ phối đồ';
    final String? snapshotUrl =
        outfit['CanvasSnapshotUrl']?.toString() ??
        outfit['canvasSnapshotUrl']?.toString() ??
        outfit['snapshotUrl']?.toString();
    final String createdAt =
        outfit['CreatedAt']?.toString() ??
        outfit['createdAt']?.toString() ??
        '';
    String dateLabel = '';
    if (createdAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAt).toLocal();
        dateLabel =
            '${dt.day}/${dt.month}/${dt.year} lúc ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    // Extract items from outfit (support both PascalCase and camelCase from .NET API)
    final dynamic rawItems = outfit['Items'] ?? outfit['items'];
    List<Map<String, dynamic>> items = [];
    if (rawItems is List) {
      items = rawItems
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
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
                    const SizedBox(height: 24),

                    // Header row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Chi tiết bộ phối',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Snapshot Image Frame
                    if (snapshotUrl != null && snapshotUrl.isNotEmpty)
                      Container(
                        height: 320,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.muted.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.4),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            children: [
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Image.network(
                                    snapshotUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.broken_image_outlined,
                                              size: 64,
                                              color: AppColors.primaryLight,
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
                                  shadowColor: Colors.black.withOpacity(0.1),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: () =>
                                        _downloadOutfitImage(snapshotUrl),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(
                                          color: AppColors.secondary
                                              .withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.download_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Tải ảnh',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
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
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Metadata Cards (matching _showItemDetails)
                    _detailRow('Tên bộ phối', title, Icons.style_rounded),
                    _detailRow(
                      'Ngày tạo',
                      dateLabel.isNotEmpty ? dateLabel : 'Không rõ',
                      Icons.calendar_today_rounded,
                    ),

                    // Items in outfit
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Các món trong bộ phối',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 104,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: items.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            final String? imgUrl =
                                item['imageUrl']?.toString() ??
                                item['image_url']?.toString();
                            final String itemName =
                                item['name']?.toString() ?? 'Món đồ';
                            return Column(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: AppColors.muted.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.secondary.withOpacity(
                                        0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(6),
                                        child:
                                            imgUrl != null && imgUrl.isNotEmpty
                                            ? Image.network(
                                                imgUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      Icons.checkroom_rounded,
                                                      size: 24,
                                                      color: AppColors
                                                          .primaryLight,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.checkroom_rounded,
                                                size: 24,
                                                color: AppColors.primaryLight,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                SizedBox(
                                  width: 72,
                                  child: Text(
                                    itemName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
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
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                        label: const Text(
                          'Thử đồ bộ phối',
                          style: TextStyle(
                            height: 1.25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          OutfitPage.pendingTryOnOutfitSnapshotUrl =
                              snapshotUrl;
                          OutfitPage.pendingTryOnOutfitTitle = title;
                          widget.onNavigateTo?.call(4);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded, size: 18),
                            label: const Text(
                              'Đổi tên',
                              style: TextStyle(
                                height: 1.25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                              backgroundColor: const Color(0xFFFFECEB),
                              foregroundColor: const Color(0xFFE53935),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(
                              Icons.delete_forever_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Xóa',
                              style: TextStyle(
                                height: 1.25,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
    final String title =
        outfit['Title']?.toString() ?? outfit['title']?.toString() ?? '';
    final String outfitId =
        outfit['Id']?.toString() ?? outfit['id']?.toString() ?? '';
    if (outfitId.isEmpty) return;

    final TextEditingController textController = TextEditingController(
      text: title,
    );

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: Đổi tên thất bại. $e')));
      }
    }
  }

  Future<void> _confirmDeleteOutfit(Map<String, dynamic> outfit) async {
    final String title =
        outfit['Title']?.toString() ??
        outfit['title']?.toString() ??
        'Bộ phối đồ';
    final String outfitId =
        outfit['Id']?.toString() ?? outfit['id']?.toString() ?? '';
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: Xóa thất bại. $e')));
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
              content: Text(
                'Lưu thành công! Đã lưu ảnh bộ phối vào Thư viện. 📲',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          throw Exception(
            result?['errorMessage'] ?? 'Không thể lưu ảnh vào thư viện.',
          );
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
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
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
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 24),

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
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.primary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 240,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.muted.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.secondary.withOpacity(0.4),
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: item.imageUrl.isEmpty
                                    ? const Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 64,
                                        color: AppColors.primaryLight,
                                      )
                                    : Image.network(
                                        item.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(
                                                  Icons.broken_image_outlined,
                                                  size: 64,
                                                  color: AppColors.primaryLight,
                                                ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _detailRow(
                        'Tên món đồ',
                        item.name.isEmpty ? 'Chưa đặt tên' : item.name,
                        Icons.label_rounded,
                      ),
                      _detailRow(
                        'Thương hiệu',
                        item.brand?.isNotEmpty == true
                            ? item.brand!
                            : 'Chưa có thương hiệu',
                        Icons.stars_rounded,
                      ),
                      _detailRow(
                        'Phân loại',
                        _categoryLabel[item.category] ?? item.category,
                        Icons.category_rounded,
                      ),
                      _closetSelectorRow(item),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary
                                    .withOpacity(0.4),
                                foregroundColor: AppColors.primary,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.style_rounded, size: 18),
                              label: const Text(
                                'Phối đồ',
                                style: TextStyle(
                                  height: 1.25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CanvasOutfitPage(initialItem: item),
                                        fullscreenDialog: true,
                                      ),
                                    )
                                    .then((saved) {
                                      if (saved == true && mounted) {
                                        _fetchOutfits();
                                      }
                                    });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Thử đồ AI',
                                style: TextStyle(
                                  height: 1.25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                OutfitPage.pendingTryOnGarment = item;
                                widget.onNavigateTo?.call(4);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text(
                                'Chỉnh sửa',
                                style: TextStyle(
                                  height: 1.25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                backgroundColor: const Color(0xFFFFECEB),
                                foregroundColor: const Color(0xFFE53935),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(
                                Icons.delete_forever_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Xóa',
                                style: TextStyle(
                                  height: 1.25,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _confirmDelete(item);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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

  Widget _closetSelectorRow(ClothingItem item) {
    String currentClosetName = 'Chưa xếp vào tủ đồ';
    if (item.closetId != null) {
      final matchingCloset = _userClosets.firstWhere(
        (c) => (c['id'] ?? c['Id'])?.toString() == item.closetId,
        orElse: () => {},
      );
      if (matchingCloset.isNotEmpty) {
        currentClosetName =
            (matchingCloset['name'] ?? matchingCloset['Name'])?.toString() ??
            'Chưa xếp vào tủ đồ';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.folder_open_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tủ đồ chứa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  currentClosetName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String?>(
            icon: const Icon(
              Icons.swap_horiz_rounded,
              color: AppColors.primaryLight,
            ),
            onSelected: (String? newClosetId) async {
              Navigator.pop(context); // Close the bottom sheet
              _showLoadingDialog('Đang chuyển tủ đồ...');
              final success = await _closetApiService.assignItemToCloset(
                item.id,
                newClosetId,
              );
              if (mounted) {
                Navigator.pop(context); // Close loading dialog
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã cập nhật tủ đồ của món đồ!'),
                    ),
                  );
                  _fetchItems();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chuyển tủ đồ thất bại.')),
                  );
                }
              }
            },
            itemBuilder: (BuildContext context) {
              final List<PopupMenuEntry<String?>> entries = [];
              entries.add(
                const PopupMenuItem<String?>(
                  value: null,
                  child: Text('Không xếp vào tủ đồ (Tất cả món đồ)'),
                ),
              );
              for (var closet in _userClosets) {
                final id = (closet['id'] ?? closet['Id'])?.toString();
                final name =
                    (closet['name'] ?? closet['Name'])?.toString() ?? 'Tủ đồ';
                entries.add(
                  PopupMenuItem<String?>(value: id, child: Text(name)),
                );
              }
              return entries;
            },
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
          content: Text(
            'Bạn có chắc chắn muốn xóa "${item.name}" khỏi tủ đồ không?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
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
        await localStorage.saveWardrobeItemCount(
          currentCount > 0 ? currentCount - 1 : 0,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa món đồ khỏi tủ đồ thành công!')),
        );
        _fetchItems();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lỗi: Xóa thất bại.')));
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
      'Khác': 'Other',
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
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
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
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Chỉnh sửa thông tin',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.primary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        initialValue: name,
                        decoration: InputDecoration(
                          labelText: 'Tên món đồ',
                          labelStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.label_outline_rounded,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: AppColors.primary.withOpacity(0.03),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) => name = val,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: brand,
                        decoration: InputDecoration(
                          labelText: 'Thương hiệu',
                          labelStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.stars_outlined,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: AppColors.primary.withOpacity(0.03),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (val) => brand = val,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: currentCatName,
                        decoration: InputDecoration(
                          labelText: 'Loại trang phục',
                          labelStyle: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: const Icon(
                            Icons.category_outlined,
                            color: AppColors.primaryLight,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: AppColors.primary.withOpacity(0.03),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: AppColors.primary.withOpacity(0.15),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
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
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context, {
                                  'name': name,
                                  'brand': brand,
                                  'category': category,
                                });
                              },
                              child: const Text(
                                'Lưu',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cập nhật thành công!')));
        _fetchItems();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Cập nhật thất bại.')),
        );
      }
    }
  }

  Future<Map<String, String>?> _showDetailsDialog(File imageFile) async {
    String name = 'Đang nhận dạng...';
    String category = 'Top';
    String currentCatName = 'Áo';
    String detectedColor = '';
    bool isAnalyzing = true;

    final TextEditingController nameController = TextEditingController(
      text: name,
    );

    final Map<String, String> categoryOptions = {
      'Áo': 'Top',
      'Quần/Váy': 'Bottom',
      'Đầm': 'Dress',
      'Áo khoác': 'Outerwear',
      'Giày': 'Shoes',
      'Túi': 'Bag',
      'Phụ kiện': 'Accessory',
      'Khác': 'Other',
    };

    final Map<String, String> reverseCategoryMap = {
      'Top': 'Áo',
      'Bottom': 'Quần/Váy',
      'Dress': 'Đầm',
      'Outerwear': 'Áo khoác',
      'Shoes': 'Giày',
      'Bag': 'Túi',
      'Accessory': 'Phụ kiện',
      'Other': 'Khác',
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
              GetIt.I<GeminiApiService>().analyzeClothingImage(imageFile).then((
                result,
              ) {
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
                    const Text(
                      'Phân loại đồ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Image.file(
                              imageFile,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                            if (isAiRunning)
                              const Positioned.fill(
                                child: _AiScannerOverlay(height: 120),
                              ),
                          ],
                        ),
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
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primaryLight,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const _AiStatusText(),
                          ],
                        ),
                      )
                    else if (detectedColor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.palette_rounded,
                              size: 14,
                              color: AppColors.primaryLight,
                            ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context, {
                            'name': name,
                            'category': category,
                          });
                        },
                        child: const Text(
                          'Lưu & Tách nền',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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

  Future<void> _pickAndAddClothes({String? closetId}) async {
    _showBgRemovalGuidelines(closetId: closetId);
  }

  void _showBgRemovalGuidelines({String? closetId}) {
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
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
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
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.primary,
                  ),
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
                      border: Border.all(
                        color: Colors.green.shade200,
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.checkroom_rounded,
                                size: 36,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Ảnh phẳng / Treo',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nền trơn, rõ nét',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 18,
                          ),
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
                              Icon(
                                Icons.photo_filter_rounded,
                                size: 36,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Không nên chọn',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Nền rối, nhiều đồ vật',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 8,
                          right: 8,
                          child: Icon(
                            Icons.cancel_rounded,
                            color: Colors.red,
                            size: 18,
                          ),
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
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: 'Nên: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'Trải phẳng quần áo trên sàn đơn sắc hoặc treo trên móc trước tường trơn. Chụp thẳng từ trên xuống hoặc chính diện, đủ ánh sáng.',
                              ),
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
                      const Icon(
                        Icons.cancel_rounded,
                        color: Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: 'Tránh: ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              TextSpan(
                                text:
                                    'Chụp quần áo bị nhăn nheo, gấp nếp. Tránh hậu cảnh có quá nhiều đồ đạc xung quanh hoặc có màu nền trùng với màu quần áo.',
                              ),
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
                      side: const BorderSide(
                        color: AppColors.primaryLight,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickAndAddClothesSource(
                        ImageSource.camera,
                        closetId: closetId,
                      );
                    },
                    icon: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primaryLight,
                      size: 18,
                    ),
                    label: const Text(
                      'Chụp ảnh mới',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _pickAndAddClothesSource(
                        ImageSource.gallery,
                        closetId: closetId,
                      );
                    },
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Chọn từ thư viện',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 13,
                      ),
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

  Future<void> _pickAndAddClothesSource(
    ImageSource source, {
    String? closetId,
  }) async {
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
                  Text(
                    'Đang tách nền & lưu vào tủ đồ...',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).then((_) => isDialogOpen = false);

      final bgRemovalService = GetIt.I<BgRemovalService>();
      final Uint8List? resultBytes = await bgRemovalService.removeBackground(
        File(image.path),
      );

      // Trừ 1 credit xóa nền
      await localStorage.updateCredits(bgCredits: bgCredits - 1);

      File fileToUpload = File(image.path);
      if (resultBytes != null) {
        final tempFile = File(
          '${Directory.systemTemp.path}/transparent_${DateTime.now().millisecondsSinceEpoch}.png',
        );
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
        final targetClosetId = closetId ?? _selectedClosetId;
        if (targetClosetId != null) {
          await _closetApiService.assignItemToCloset(
            newItem.id,
            targetClosetId,
          );
        }
        // Tăng số lượng tủ đồ cục bộ
        final currentCount = localStorage.getWardrobeItemCount();
        await localStorage.saveWardrobeItemCount(currentCount + 1);

        _fetchItems();

        if (mounted) {
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
                        color: AppColors.primary,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
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
                          color: AppColors.primary,
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
            errorMsg =
                'Ảnh tải lên quá lớn (giới hạn 30MB). Vui lòng chọn hoặc chụp ảnh nhẹ hơn.';
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
              if (dataStr.contains('<html') ||
                  dataStr.contains('<!DOCTYPE html>')) {
                errorMsg =
                    'Không thể kết nối đến hệ thống. Vui lòng thử lại sau.';
              } else {
                errorMsg = dataStr;
                if (errorMsg.length > 250) {
                  errorMsg = '${errorMsg.substring(0, 250)}...';
                }
              }
            }
          }
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
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
}

class _InteractiveClothingItemCard extends StatefulWidget {
  final ClothingItem item;
  final Map<String, String> categoryLabel;
  const _InteractiveClothingItemCard({
    required this.item,
    required this.categoryLabel,
  });

  @override
  State<_InteractiveClothingItemCard> createState() =>
      _InteractiveClothingItemCardState();
}

class _InteractiveClothingItemCardState
    extends State<_InteractiveClothingItemCard> {
  bool _isPressed = false;

  Color? _parseColor(String colorTag) {
    final clean = colorTag.trim().toLowerCase();
    switch (clean) {
      case 'black':
        return Colors.black;
      case 'white':
        return Colors.white;
      case 'gray':
      case 'grey':
        return Colors.grey;
      case 'red':
        return Colors.red;
      case 'blue':
        return Colors.blue;
      case 'green':
        return Colors.green;
      case 'yellow':
        return Colors.amber;
      case 'pink':
        return Colors.pink;
      case 'purple':
        return Colors.purple;
      case 'orange':
        return Colors.orange;
      case 'brown':
        return Colors.brown;
      case 'beige':
        return const Color(0xFFF5F5DC);
      case 'navy':
        return const Color(0xFF000080);
      case 'cream':
        return const Color(0xFFFFFDD0);
      case 'khaki':
        return const Color(0xFFF0E68C);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final imageUrl = item.imageUrl;
    final categoryText = widget.categoryLabel[item.category] ?? item.category;

    // Parse up to 3 colors to show
    List<Color> colorsToShow = [];
    for (var tag in item.colorTags) {
      final c = _parseColor(tag);
      if (c != null) {
        colorsToShow.add(c);
      }
      if (colorsToShow.length >= 3) break;
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_isPressed ? 1.03 : 1.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(_isPressed ? 0.12 : 0.06),
              blurRadius: _isPressed ? 24 : 18,
              offset: Offset(0, _isPressed ? 12 : 8),
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
                        padding: const EdgeInsets.all(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
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
                          categoryText,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
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
                      fontSize: 13,
                    ),
                  ),
                  if (colorsToShow.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: colorsToShow.map((c) {
                        final isLight =
                            c == Colors.white ||
                            c == const Color(0xFFFFFDD0) ||
                            c == const Color(0xFFF5F5DC);
                        return Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: isLight
                                ? Border.all(
                                    color: Colors.grey.shade300,
                                    width: 0.8,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 2,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiScannerOverlay extends StatefulWidget {
  final double height;
  const _AiScannerOverlay({required this.height});

  @override
  State<_AiScannerOverlay> createState() => _AiScannerOverlayState();
}

class _AiScannerOverlayState extends State<_AiScannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _controller.forward();
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned(
              top: _animation.value * widget.height,
              left: 0,
              right: 0,
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryLight.withOpacity(0.8),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AiStatusText extends StatefulWidget {
  const _AiStatusText();

  @override
  State<_AiStatusText> createState() => _AiStatusTextState();
}

class _AiStatusTextState extends State<_AiStatusText> {
  int _textIndex = 0;
  Timer? _timer;
  final List<String> _statuses = [
    '🤖 AI đang nhận diện kiểu dáng...',
    '🎨 AI đang phân tích tông màu sắc...',
    '👕 AI đang nhận diện loại cổ áo & tay áo...',
    '🔍 AI đang tối ưu hóa các chi tiết...',
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (mounted) {
        setState(() {
          _textIndex = (_textIndex + 1) % _statuses.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _statuses[_textIndex],
      style: TextStyle(
        fontSize: 12,
        color: AppColors.primary.withOpacity(0.7),
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class HangerHookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0xFFD4AF37) // Golden hook
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Draw hook curve at the top
    path.moveTo(cx + 5, cy - 6);
    path.arcToPoint(
      Offset(cx - 5, cy - 6),
      radius: const Radius.circular(5),
      clockwise: false,
    );
    // Draw hook neck
    path.quadraticBezierTo(cx, cy, cx, cy + 8);
    // Draw shoulder triangle (hanger base)
    path.moveTo(cx, cy + 8);
    path.lineTo(cx - 16, cy + 16);
    path.lineTo(cx + 16, cy + 16);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 4.0,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashPath = _buildDashedPath(path, gap);
    canvas.drawPath(dashPath, paint);
  }

  Path _buildDashedPath(Path source, double gap) {
    final Path path = Path();
    for (final ui.PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? gap : gap;
        if (draw) {
          path.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return path;
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}
