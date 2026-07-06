import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:get_it/get_it.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/affiliate_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../../widgets/app_tour_overlay.dart';
import 'product_detail_page.dart';

class StorePage extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const StorePage({super.key, this.onMenuPressed});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final AffiliateApiService _affiliateApiService =
      GetIt.I<AffiliateApiService>();
  final AuthLocalStorage _localStorage = GetIt.I<AuthLocalStorage>();
  final GlobalKey _storeCategoryGuideKey = GlobalKey();
  final GlobalKey _firstProductGuideKey = GlobalKey();

  String _selectedCategory = 'Tất cả';
  List<String> get _categories {
    final base = ['Tất cả', 'Áo', 'Quần', 'Váy đầm', 'Phụ kiện'];
    if (_localStorage.getHasCompletedStyleQuiz()) {
      return ['Dành cho bạn ✨', ...base];
    }
    return base;
  }

  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _isShowingStoreGuide = false;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await _affiliateApiService.getProducts(
        page: 1,
        pageSize: 100,
      );
      final List<dynamic> items = result['items'] ?? result['Items'] ?? [];
      if (mounted) {
        setState(() {
          _products = items
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
          _isLoading = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeShowStoreGuide();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải danh sách sản phẩm: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredProducts {
    // Tab “Dành cho bạn” — filter theo phong cách từ Style DNA
    if (_selectedCategory == 'Dành cho bạn ✨') {
      return _getPersonalizedProducts();
    }
    if (_selectedCategory == 'Tất cả') return _products;
    return _products.where((p) {
      final cat =
          (p['Category'] ?? p['category'])?.toString().toLowerCase() ?? '';
      if (_selectedCategory == 'Áo') {
        return cat == 'top' || cat == 'outerwear';
      }
      if (_selectedCategory == 'Quần') {
        return cat == 'bottom';
      }
      if (_selectedCategory == 'Váy đầm') {
        return cat == 'dress';
      }
      if (_selectedCategory == 'Phụ kiện') {
        return cat == 'accessory' ||
            cat == 'bag' ||
            cat == 'shoes' ||
            cat == 'other';
      }
      return false;
    }).toList();
  }

  /// Lọc sản phẩm theo phong cách Style DNA của user
  List<Map<String, dynamic>> _getPersonalizedProducts() {
    final stylePref = _localStorage.getStylePref() ?? 'casual';
    final colorPref = _localStorage.getColorPref() ?? 'trung_tinh';

    return _products.where((p) {
      final name = (p['Name'] ?? p['name'] ?? '').toString().toLowerCase();
      final desc = (p['Description'] ?? p['description'] ?? '')
          .toString()
          .toLowerCase();
      final cat = (p['Category'] ?? p['category'] ?? '')
          .toString()
          .toLowerCase();
      final text = '$name $desc';

      // Filter theo phong cách
      bool matchStyle = true;
      switch (stylePref) {
        case 'casual':
          matchStyle =
              text.contains('casual') ||
              text.contains('thuờời') ||
              cat == 'top' ||
              cat == 'bottom';
          break;
        case 'cong_so':
          matchStyle =
              text.contains('sơ mi') ||
              text.contains('vest') ||
              text.contains('công sở') ||
              text.contains('formal');
          break;
        case 'streetwear':
          matchStyle =
              text.contains('hoodie') ||
              text.contains('oversized') ||
              text.contains('street') ||
              text.contains('bomber');
          break;
        case 'thanh_lich':
          matchStyle =
              cat == 'dress' ||
              text.contains('đầm') ||
              text.contains('chân váy') ||
              text.contains('thanh lịch');
          break;
        case 'sporty':
          matchStyle =
              text.contains('sport') ||
              text.contains('thể thao') ||
              text.contains('jogger') ||
              text.contains('legging');
          break;
      }

      // Filter theo màu sắc (bonus)
      bool matchColor = true;
      switch (colorPref) {
        case 'toi_mau':
          matchColor =
              text.contains('đen') ||
              text.contains('navy') ||
              text.contains('dark');
          break;
        case 'pastel':
          matchColor =
              text.contains('hồng') ||
              text.contains('nhạt') ||
              text.contains('pastel');
          break;
        default:
          matchColor =
              true; // Không filter mạnh theo màu nếu không có dấu hiệu rõ ràng
      }

      return matchStyle || matchColor;
    }).toList();
  }

  String _formatPrice(dynamic priceValue) {
    if (priceValue == null) return '0đ';
    if (priceValue is num) {
      final str = priceValue.round().toString();
      final buffer = StringBuffer();
      int count = 0;
      for (int i = str.length - 1; i >= 0; i--) {
        if (count > 0 && count % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(str[i]);
        count++;
      }
      return '${buffer.toString().split('').reversed.join('')}đ';
    }
    return '$priceValue';
  }

  String _getProductImage(Map<String, dynamic> product) {
    return product['ImageUrl'] as String? ??
        product['imageUrl'] as String? ??
        product['image'] as String? ??
        '';
  }

  String _getProductName(Map<String, dynamic> product) {
    return product['Name'] as String? ??
        product['name'] as String? ??
        'Sản phẩm thời trang';
  }

  Future<void> _maybeShowStoreGuide() async {
    if (_isShowingStoreGuide) return;
    if (_localStorage.getHasSeenStoreGuide()) return;
    if (_isLoading || _errorMessage != null) return;

    _isShowingStoreGuide = true;
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) {
      _isShowingStoreGuide = false;
      return;
    }

    final hasStyleDna = _localStorage.getHasCompletedStyleQuiz();
    final recommendedCategory = hasStyleDna ? 'Dành cho bạn ✨' : 'Tất cả';

    final categoryResult = await AppTourOverlay.showCoachStep(
      context,
      targetKey: _storeCategoryGuideKey,
      stepNumber: 1,
      totalSteps: 2,
      icon: Icons.shopping_bag_rounded,
      title: hasStyleDna ? 'Gợi ý mua sắm theo bạn' : 'Lọc sản phẩm',
      description: hasStyleDna
          ? 'Nhấn chip Dành cho bạn để xem sản phẩm được lọc theo Style DNA, bảng màu và phong cách của bạn.'
          : 'Nhấn chip này để xem toàn bộ sản phẩm, sau đó có thể lọc theo áo, quần, váy đầm hoặc phụ kiện.',
      primaryLabel: 'Nhấn vùng sáng để xem',
    );

    if (!mounted) {
      _isShowingStoreGuide = false;
      return;
    }

    if (categoryResult == AppTourCoachAction.finish) {
      await _localStorage.saveHasSeenStoreGuide(true);
      _isShowingStoreGuide = false;
      return;
    }

    setState(() => _selectedCategory = recommendedCategory);
    await Future.delayed(const Duration(milliseconds: 420));

    if (!mounted) {
      _isShowingStoreGuide = false;
      return;
    }

    if (_filteredProducts.isEmpty && _products.isNotEmpty) {
      setState(() => _selectedCategory = 'Tất cả');
      await Future.delayed(const Duration(milliseconds: 260));
    }

    if (!mounted || _filteredProducts.isEmpty) {
      await _localStorage.saveHasSeenStoreGuide(true);
      _isShowingStoreGuide = false;
      return;
    }

    final productResult = await AppTourOverlay.showCoachStep(
      context,
      targetKey: _firstProductGuideKey,
      stepNumber: 2,
      totalSteps: 2,
      icon: Icons.open_in_new_rounded,
      title: 'Xem chi tiết sản phẩm',
      description:
          'Nhấn vào một sản phẩm để xem ảnh, giá, mô tả và mở link mua hàng nếu phù hợp với tủ đồ của bạn.',
      primaryLabel: 'Nhấn vùng sáng để mở chi tiết',
    );

    await _localStorage.saveHasSeenStoreGuide(true);
    _isShowingStoreGuide = false;

    if (!mounted) return;
    if (productResult == AppTourCoachAction.next) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(product: _filteredProducts.first),
        ),
      );
    }
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
                icon: const Icon(Icons.menu_rounded, color: AppColors.primary),
              ),
            ),
          ),
        ),
        title: const Text(
          'Cửa hàng thời trang',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bộ lọc categories
            SizedBox(
              height: 58,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final active = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      key:
                          cat ==
                              (_localStorage.getHasCompletedStyleQuiz()
                                  ? 'Dành cho bạn ✨'
                                  : 'Tất cả')
                          ? _storeCategoryGuideKey
                          : null,
                      selected: active,
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                      label: Text(cat),
                      labelStyle: TextStyle(
                        color: AppColors.primary,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Danh sách sản phẩm grid
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _fetchProducts,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchProducts,
                      color: AppColors.primary,
                      child: _filteredProducts.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'Không có sản phẩm nào.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                4,
                                20,
                                110,
                              ),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    childAspectRatio: 0.72,
                                  ),
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final imageUrl = _getProductImage(product);
                                final rating =
                                    product['Rating'] ??
                                    product['rating'] ??
                                    5.0;
                                return FadeInUp(
                                  delay: Duration(
                                    milliseconds: 50 * (index % 6),
                                  ),
                                  child: GestureDetector(
                                    key: index == 0
                                        ? _firstProductGuideKey
                                        : null,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => ProductDetailPage(
                                            product: product,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withOpacity(0.05),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Stack(
                                              children: [
                                                Container(
                                                  width: double.infinity,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFFF8F9FA),
                                                    borderRadius:
                                                        BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            22,
                                                          ),
                                                        ),
                                                  ),
                                                  child:
                                                      (imageUrl.startsWith(
                                                            'http://',
                                                          ) ||
                                                          imageUrl.startsWith(
                                                            'https://',
                                                          ))
                                                      ? ClipRRect(
                                                          borderRadius:
                                                              const BorderRadius.vertical(
                                                                top:
                                                                    Radius.circular(
                                                                      22,
                                                                    ),
                                                              ),
                                                          child: Image.network(
                                                            imageUrl,
                                                            width:
                                                                double.infinity,
                                                            height:
                                                                double.infinity,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (
                                                                  context,
                                                                  error,
                                                                  stackTrace,
                                                                ) {
                                                                  return const Center(
                                                                    child: Icon(
                                                                      Icons
                                                                          .broken_image_rounded,
                                                                      color: Colors
                                                                          .grey,
                                                                    ),
                                                                  );
                                                                },
                                                          ),
                                                        )
                                                      : const Center(
                                                          child: Icon(
                                                            Icons
                                                                .image_not_supported_rounded,
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.9),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.star,
                                                          color: Colors.amber,
                                                          size: 12,
                                                        ),
                                                        const SizedBox(
                                                          width: 2,
                                                        ),
                                                        Text(
                                                          '$rating',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _getProductName(product),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 13,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  _formatPrice(
                                                    product['Price'] ??
                                                        product['price'],
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w900,
                                                    color:
                                                        AppColors.primaryLight,
                                                  ),
                                                ),
                                              ],
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
            ),
          ],
        ),
      ),
    );
  }
}
