import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:animate_do/animate_do.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/affiliate_api_service.dart';
import '../../../data/datasources/tryon_api_service.dart';
import '../../../data/datasources/user_api_service.dart';
import '../../../data/datasources/auth_local_storage.dart';
import '../profile/subscription_page.dart';
import 'dart:ui' as ui;
import '../../../data/datasources/wardrobe_api_service.dart';
import '../../../domain/entities/clothing_item.dart';

class ProductDetailPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  final AffiliateApiService _affiliateApiService =
      GetIt.I<AffiliateApiService>();
  String? _selectedSize;
  bool _isOpening = false;

  double? _userHeight;
  double? _userWeight;
  String? _userGender;

  @override
  void initState() {
    super.initState();
    _loadUserDna();
  }

  Future<void> _loadUserDna() async {
    try {
      final profile = await GetIt.I<UserApiService>().getMyProfile();
      setState(() {
        _userHeight = (profile['heightCm'] ?? profile['HeightCm'])?.toDouble();
        _userWeight = (profile['weightKg'] ?? profile['WeightKg'])?.toDouble();
        _userGender = profile['gender'] ?? profile['Gender'];

        // Auto select recommended size if available and not already selected
        if (_selectedSize == null) {
          final sizes = List<String>.from(
            widget.product['sizes'] ?? widget.product['Sizes'] ?? [],
          );
          final rec = _getRecommendedSize(sizes);
          if (rec != null) {
            _selectedSize = rec;
          }
        }
      });
    } catch (e) {
      debugPrint('Lỗi tải chiều cao cân nặng để đề xuất size: $e');
    }
  }

  String? _getRecommendedSize(List<String> availableSizes) {
    if (_userHeight == null || _userWeight == null) return null;

    String sizeLetter = 'M';
    final isFemale = _userGender?.toLowerCase() == 'female';

    if (isFemale) {
      if (_userHeight! < 155) {
        if (_userWeight! < 45) {
          sizeLetter = 'S';
        } else if (_userWeight! <= 52) {
          sizeLetter = 'M';
        } else {
          sizeLetter = 'L';
        }
      } else if (_userHeight! <= 162) {
        if (_userWeight! < 50) {
          sizeLetter = 'M';
        } else if (_userWeight! <= 58) {
          sizeLetter = 'L';
        } else {
          sizeLetter = 'XL';
        }
      } else {
        if (_userWeight! < 55) {
          sizeLetter = 'L';
        } else if (_userWeight! <= 65) {
          sizeLetter = 'XL';
        } else {
          sizeLetter = 'XXL';
        }
      }
    } else {
      if (_userHeight! < 165) {
        if (_userWeight! < 55) {
          sizeLetter = 'S';
        } else if (_userWeight! <= 65) {
          sizeLetter = 'M';
        } else {
          sizeLetter = 'L';
        }
      } else if (_userHeight! <= 172) {
        if (_userWeight! < 60) {
          sizeLetter = 'M';
        } else if (_userWeight! <= 70) {
          sizeLetter = 'L';
        } else {
          sizeLetter = 'XL';
        }
      } else {
        if (_userWeight! < 68) {
          sizeLetter = 'L';
        } else if (_userWeight! <= 78) {
          sizeLetter = 'XL';
        } else {
          sizeLetter = 'XXL';
        }
      }
    }

    for (final s in availableSizes) {
      if (s.trim().toUpperCase() == sizeLetter) {
        return s;
      }
    }

    bool isNumeric = availableSizes.any((s) => int.tryParse(s.trim()) != null);
    if (isNumeric) {
      int targetNum = 30;
      switch (sizeLetter) {
        case 'S':
          targetNum = 29;
          break;
        case 'M':
          targetNum = 30;
          break;
        case 'L':
          targetNum = 31;
          break;
        case 'XL':
          targetNum = 32;
          break;
        case 'XXL':
          targetNum = 33;
          break;
      }

      String? closestSize;
      int minDiff = 999;
      for (final s in availableSizes) {
        final val = int.tryParse(s.trim());
        if (val != null) {
          final diff = (val - targetNum).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closestSize = s;
          }
        }
      }
      return closestSize;
    }

    if (availableSizes.isNotEmpty) {
      for (final s in availableSizes) {
        if (s.trim().toUpperCase().contains(sizeLetter)) {
          return s;
        }
      }
      return availableSizes.first;
    }

    return sizeLetter;
  }

  Widget _buildAiSizeRecommendation(String recommendedSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E5F5).withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryLight.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primaryLight,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đề xuất Size V-Closet AI ✨',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary.withOpacity(0.7),
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Dựa trên chiều cao '),
                      TextSpan(
                        text: '${_userHeight!.round()}cm',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' và cân nặng '),
                      TextSpan(
                        text: '${_userWeight!.round()}kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' của bạn, size phù hợp nhất là '),
                      TextSpan(
                        text: 'Size $recommendedSize',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryLight,
                        ),
                      ),
                      const TextSpan(text: ' (độ chuẩn xác 92%).'),
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

  String _getProductCategory(Map<String, dynamic> product) {
    final cat =
        product['Category'] as String? ??
        product['category'] as String? ??
        'Fashion';
    if (cat.toLowerCase() == 'top' || cat.toLowerCase() == 'outerwear')
      return 'Áo';
    if (cat.toLowerCase() == 'bottom') return 'Quần';
    if (cat.toLowerCase() == 'dress') return 'Váy đầm';
    if (cat.toLowerCase() == 'accessory' ||
        cat.toLowerCase() == 'bag' ||
        cat.toLowerCase() == 'shoes' ||
        cat.toLowerCase() == 'other')
      return 'Phụ kiện';
    return cat;
  }

  String _getProductDescription(Map<String, dynamic> product) {
    return product['Description'] as String? ??
        product['description'] as String? ??
        'Sản phẩm chất lượng cao, thiết kế hiện đại và thời thượng. '
            'Phù hợp với nhiều dịp khác nhau, từ công sở đến đi chơi. '
            'Chất liệu thoáng mát, dễ chịu khi mặc. '
            'Bảo quản bằng cách giặt tay hoặc giặt máy ở chế độ nhẹ.';
  }

  String _getProductId(Map<String, dynamic> product) {
    return product['Id'] as String? ?? product['id'] as String? ?? '';
  }

  double _getProductRating(Map<String, dynamic> product) {
    final rating = product['Rating'] ?? product['rating'];
    if (rating is num) return rating.toDouble();
    return 5.0;
  }

  String _getProductShopeeUrl(Map<String, dynamic> product) {
    return product['AffiliateLink'] as String? ??
        product['affiliateLink'] as String? ??
        product['shopeeUrl'] as String? ??
        'https://shopee.vn';
  }

  Future<void> _openShopee() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);

    String? targetUrl;
    final productId = _getProductId(widget.product);

    if (productId.isNotEmpty) {
      try {
        final result = await _affiliateApiService.recordClick(
          productId: productId,
          clickSource: 'Store_Detail',
        );
        if (result != null) {
          targetUrl =
              result['TargetAffiliateLink'] as String? ??
              result['targetAffiliateLink'] as String?;
        }
      } catch (e) {
        debugPrint('Error recording click: $e');
      }
    }

    targetUrl ??= _getProductShopeeUrl(widget.product);

    final url = Uri.parse(targetUrl);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể mở Shopee. Vui lòng thử lại! Lỗi: $e'),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  void _openTryOnBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductTryOnSheet(product: widget.product),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sizes = List<String>.from(
      widget.product['sizes'] ?? widget.product['Sizes'] ?? [],
    );
    final recommendedSize = _getRecommendedSize(sizes);
    final imageUrl = _getProductImage(widget.product);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ảnh sản phẩm full top
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.48,
            width: double.infinity,
            child:
                (imageUrl.isNotEmpty &&
                    (imageUrl.startsWith('http://') ||
                        imageUrl.startsWith('https://')))
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: const Color(0xFFF0F0F5),
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : Container(
                    color: const Color(0xFFF0F0F5),
                    child: const Icon(
                      Icons.image_not_supported_rounded,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
          ),

          // AppBar trong suốt
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    _CircleButton(
                      icon: Icons.favorite_border_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom sheet chi tiết
          Align(
            alignment: Alignment.bottomCenter,
            child: FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.58,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Tên + rating
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getProductName(widget.product),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF9E6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${_getProductRating(widget.product)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            // Danh mục
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _getProductCategory(widget.product),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Giá
                            Text(
                              _formatPrice(
                                widget.product['Price'] ??
                                    widget.product['price'],
                              ),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryLight,
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Mô tả
                            const Text(
                              'Mô tả sản phẩm',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getProductDescription(widget.product),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                height: 1.6,
                              ),
                            ),

                            // Kích cỡ (chỉ hiện nếu có)
                            if (sizes.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              if (recommendedSize != null)
                                _buildAiSizeRecommendation(recommendedSize),
                              const Text(
                                'Kích cỡ có sẵn',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: sizes.map((size) {
                                  final isSelected = _selectedSize == size;
                                  final isRecommended = size == recommendedSize;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedSize = size),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : (isRecommended
                                                  ? const Color(0xFFF3E5F5)
                                                  : const Color(0xFFF5F5F8)),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : (isRecommended
                                                    ? AppColors.primaryLight
                                                    : Colors.transparent),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            size,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: isSelected
                                                  ? Colors.white
                                                  : AppColors.primary,
                                            ),
                                          ),
                                          if (isRecommended) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '✨',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.primaryLight,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Hàng nút Mặc thử AI và Mua ngay cố định ở dưới (Sticky)
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: _openTryOnBottomSheet,
                                icon: const Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 22,
                                ),
                                label: const Text(
                                  'Mặc thử AI',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                    width: 1.5,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isOpening ? null : _openShopee,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(
                                    0xFFEE4D2D,
                                  ), // màu cam Shopee
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFFEE4D2D,
                                  ).withOpacity(0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isOpening
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.network(
                                            'https://upload.wikimedia.org/wikipedia/commons/thumb/f/fe/Shopee.svg/32px-Shopee.svg.png',
                                            width: 22,
                                            height: 22,
                                            errorBuilder:
                                                (
                                                  context,
                                                  error,
                                                  stack,
                                                ) => const Icon(
                                                  Icons.shopping_bag_rounded,
                                                  size: 22,
                                                  color: Colors.white,
                                                ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Mua ngay',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTryOnSheet extends StatefulWidget {
  final Map<String, dynamic> product;

  const _ProductTryOnSheet({required this.product});

  @override
  State<_ProductTryOnSheet> createState() => _ProductTryOnSheetState();
}

class _ProductTryOnSheetState extends State<_ProductTryOnSheet>
    with SingleTickerProviderStateMixin {
  final TryOnApiService _tryOnApiService = GetIt.I<TryOnApiService>();
  final UserApiService _userApiService = GetIt.I<UserApiService>();
  final AuthLocalStorage _localStorage = GetIt.I<AuthLocalStorage>();

  final List<Map<String, String>> _sampleModels = [
    {
      'name': 'Mẫu Nữ 1',
      'url': 'assets/images/mau_nu_1.jpg',
      'gender': 'female',
    },
    {
      'name': 'Mẫu Nữ 2',
      'url': 'assets/images/mau_nu_2.jpg',
      'gender': 'female',
    },
    {
      'name': 'Mẫu Nữ 3',
      'url': 'assets/images/mau_nu_3.jpg',
      'gender': 'female',
    },
    {
      'name': 'Mẫu Nam 1',
      'url': 'assets/images/mau_nam_1.jpg',
      'gender': 'male',
    },
    {
      'name': 'Mẫu Nam 2',
      'url': 'assets/images/mau_nam_2.jpg',
      'gender': 'male',
    },
  ];

  late AnimationController _scanController;
  late Animation<double> _scanAnimation;

  bool _isLoadingProfile = true;
  bool _isGenerating = false;
  bool _isSavingImage = false;

  String? _selectedModelUrl;
  String? _personalMannequinUrl;
  File? _customModelFile;
  List<ClothingItem> _wardrobeItems = [];
  bool _isLoadingWardrobe = false;
  ClothingItem? _selectedWardrobeItem;
  String? _predictionId;
  String? _resultUrl;
  String? _errorMessage;
  String _loadingMessage = 'Đang khởi tạo AI...';
  bool _restoreBackground = true;

  Timer? _timer;
  int _elapsedSeconds = 0;

  @override
  void initState() {
    super.initState();
    _selectedModelUrl = _sampleModels[0]['url'];

    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanController, curve: Curves.easeInOut),
    );

    _loadUserProfile();
    _loadWardrobe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _userApiService.getMyProfile();
      final mannequinUrl =
          profile['mannequinImageUrl'] as String? ??
          profile['MannequinImageUrl'] as String?;
      if (mounted) {
        setState(() {
          _personalMannequinUrl = mannequinUrl;
          if (mannequinUrl != null && mannequinUrl.isNotEmpty) {
            _selectedModelUrl = mannequinUrl;
          }
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
        });
      }
    }
  }

  void _showImageSourceDialog() {
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
                                Icons.accessibility_new_rounded,
                                size: 36,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Chuẩn chính diện',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Đứng thẳng, rõ thân',
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
                                Icons.person_off_rounded,
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
                                'Nghiêng, bị che khuất',
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
                                    'Chọn ảnh chụp chính diện, đứng thẳng, rõ thân người. Mặc quần áo ôm sát sườn hoặc thon gọn (áo phông mỏng, quần/váy ôm).',
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
                                    'Ảnh đứng nghiêng/chụp xéo góc, tay khoanh trước ngực, tay che người hoặc tay đút túi. Không mặc quần áo quá phồng, quá rộng hoặc áo khoác phao dày.',
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
                      _pickModelImage(ImageSource.camera);
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
                      _pickModelImage(ImageSource.gallery);
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

  Future<void> _pickModelImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile == null) return;

      setState(() {
        _customModelFile = File(pickedFile.path);
        _selectedModelUrl = null; // Clear sample selection
      });
    } catch (e) {
      debugPrint('Error picking model image: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể chọn ảnh: $e')));
      }
    }
  }

  Future<void> _loadWardrobe() async {
    setState(() => _isLoadingWardrobe = true);
    try {
      final apiService = GetIt.I<WardrobeApiService>();
      final items = await apiService.getItems();
      if (mounted) {
        setState(() {
          _wardrobeItems = items;
          _isLoadingWardrobe = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading wardrobe: $e');
      if (mounted) {
        setState(() => _isLoadingWardrobe = false);
      }
    }
  }

  Future<Uint8List> _generateShopAndWardrobeCollageBytes(
    String shopImageUrl,
    String shopCategory,
    ClothingItem wardrobeItem,
  ) async {
    final dio = dio_pkg.Dio();
    ui.Image? shopImg;
    ui.Image? wardrobeImg;

    try {
      final response = await dio.get(
        shopImageUrl,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(response.data as List<int>),
      );
      final frame = await codec.getNextFrame();
      shopImg = frame.image;
    } catch (e) {
      debugPrint('Error downloading shop image: $e');
    }

    try {
      final url = wardrobeItem.originalImageUrl ?? wardrobeItem.imageUrl;
      final response = await dio.get(
        url,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(response.data as List<int>),
      );
      final frame = await codec.getNextFrame();
      wardrobeImg = frame.image;
    } catch (e) {
      debugPrint('Error downloading wardrobe image: $e');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const canvasWidth = 600.0;
    const canvasHeight = 800.0;

    final paintBg = Paint()..color = const Color(0xFFF3F3F3);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, canvasWidth, canvasHeight),
      paintBg,
    );

    Rect getRect(String category) {
      category = category.toLowerCase();
      if (category == 'top' || category == 'tops' || category == 'outerwear') {
        return const Rect.fromLTWH(50, 50, 220, 280);
      }
      if (category == 'bottom' || category == 'bottoms') {
        return const Rect.fromLTWH(50, 380, 220, 380);
      }
      if (category == 'dress' || category == 'one-pieces') {
        return const Rect.fromLTWH(50, 80, 220, 550);
      }
      if (category == 'shoes') {
        return const Rect.fromLTWH(330, 600, 220, 160);
      }
      return const Rect.fromLTWH(330, 200, 220, 220);
    }

    if (shopImg != null) {
      _paintImageFit(canvas, shopImg, getRect(shopCategory));
    }

    if (wardrobeImg != null) {
      _paintImageFit(canvas, wardrobeImg, getRect(wardrobeItem.category));
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      canvasWidth.toInt(),
      canvasHeight.toInt(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
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

  void _startTimer() {
    _elapsedSeconds = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
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
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _getProductImage(Map<String, dynamic> product) {
    return product['ImageUrl'] as String? ??
        product['imageUrl'] as String? ??
        product['image'] as String? ??
        '';
  }

  String _mapCategoryForApi(Map<String, dynamic> product) {
    final cat =
        (product['Category'] as String? ??
                product['category'] as String? ??
                'auto')
            .toLowerCase();
    if (cat == 'top' || cat == 'outerwear') return 'tops';
    if (cat == 'bottom') return 'bottoms';
    if (cat == 'dress') return 'one-pieces';
    return 'auto';
  }

  Future<void> _startTryOn() async {
    final tryonCredits = _localStorage.getTryOnCredits();
    if (tryonCredits < 1) {
      Navigator.pop(context);
      SubscriptionPage.showOutOfCreditsSheet(context, isBgRemoval: false);
      return;
    }

    setState(() {
      _isGenerating = true;
      _errorMessage = null;
      _resultUrl = null;
      _loadingMessage = 'Đang gửi yêu cầu phối đồ...';
    });

    _startTimer();

    try {
      final garmentUrl = _getProductImage(widget.product);
      if (garmentUrl.isEmpty) {
        throw Exception('Sản phẩm không có ảnh để thử đồ.');
      }

      final category = _mapCategoryForApi(widget.product);
      final bool isCustomModel =
          _customModelFile != null && _selectedModelUrl == null;
      final bool isMultiGarment = _selectedWardrobeItem != null;
      final String? selectedModelUrlLocal = _selectedModelUrl;
      final bool isLocalModel =
          selectedModelUrlLocal != null &&
          selectedModelUrlLocal.startsWith('assets/');

      if (isCustomModel || isMultiGarment || isLocalModel) {
        setState(() => _loadingMessage = 'Đang chuẩn bị ảnh người mẫu...');
        List<int> modelBytes;
        String modelFilename;

        if (isCustomModel) {
          modelBytes = await _customModelFile!.readAsBytes();
          final pathLower = _customModelFile!.path.toLowerCase();
          final ext = pathLower.endsWith('.png') ? '.png' : '.jpg';
          modelFilename = 'model$ext';
        } else if (isLocalModel) {
          setState(() => _loadingMessage = 'Đang tải người mẫu từ ứng dụng...');
          final ByteData data = await rootBundle.load(selectedModelUrlLocal);
          modelBytes = data.buffer.asUint8List();
          modelFilename = selectedModelUrlLocal.split('/').last;
        } else {
          final dioClient = dio_pkg.Dio();
          final modelResponse = await dioClient.get(
            _selectedModelUrl!,
            options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
          );
          modelBytes = modelResponse.data as List<int>;
          modelFilename = 'model.png';
        }

        List<int> garmentBytes;
        if (isMultiGarment) {
          setState(
            () => _loadingMessage = 'Đang ghép ảnh phối đồ (Flat Lay)...',
          );
          garmentBytes = await _generateShopAndWardrobeCollageBytes(
            garmentUrl,
            category,
            _selectedWardrobeItem!,
          );
        } else {
          setState(() => _loadingMessage = 'Đang tải thông tin trang phục...');
          final dioClient = dio_pkg.Dio();
          final garmentResponse = await dioClient.get(
            garmentUrl,
            options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
          );
          garmentBytes = garmentResponse.data as List<int>;
        }

        setState(() => _loadingMessage = 'Đang gửi dữ liệu phối đồ lên AI...');

        final dioClient = GetIt.I<dio_pkg.Dio>();
        final uploadFormData = dio_pkg.FormData.fromMap({
          "modelFile": dio_pkg.MultipartFile.fromBytes(
            modelBytes,
            filename: modelFilename,
          ),
          "garmentFile": dio_pkg.MultipartFile.fromBytes(
            garmentBytes,
            filename: 'garment.png',
          ),
          "category": isMultiGarment ? 'auto' : category,
          "restoreBackground": _restoreBackground.toString(),
        });

        final response = await dioClient.post(
          '/api/tryon/run-files',
          data: uploadFormData,
        );

        if (response.statusCode == 200 && response.data != null) {
          _predictionId = response.data['predictionId'] as String?;
        } else {
          throw Exception('Lỗi khởi tạo tiến trình thử đồ phối.');
        }
      } else {
        _predictionId = await _tryOnApiService.runTryOnWithUrls(
          modelUrl: _selectedModelUrl ?? '',
          garmentUrl: garmentUrl,
          category: category,
          restoreBackground: _restoreBackground,
        );
      }

      if (_predictionId == null) {
        throw Exception('Không nhận được ID tiến trình từ máy chủ AI.');
      }

      // Trừ 1 credit thử đồ AI
      await _localStorage.updateCredits(tryonCredits: tryonCredits - 1);

      // Bắt đầu poll status
      _pollStatus();
    } catch (e) {
      _stopTimer();
      String msg = e.toString();
      if (e is dio_pkg.DioException) {
        if (e.response?.statusCode == 413) {
          msg =
              'Dung lượng ảnh quá lớn (giới hạn 30MB). Vui lòng chọn hoặc chụp ảnh nhẹ hơn.';
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
            if (errorStr.contains('<html') ||
                errorStr.contains('<!DOCTYPE html>')) {
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

  Future<void> _pollStatus() async {
    if (_predictionId == null) return;

    int pollCount = 0;
    const maxPolls = 30; // 30 * 3s = 90s timeout

    Timer.periodic(const Duration(seconds: 3), (timer) async {
      pollCount++;
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }

      if (pollCount > maxPolls) {
        timer.cancel();
        _stopTimer();
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
          setState(() {
            _isGenerating = false;
            _resultUrl = outputUrl;
          });
        } else if (status == 'failed' || error != null) {
          timer.cancel();
          _stopTimer();
          debugPrint('Try-on failed error: $error');
          setState(() {
            _isGenerating = false;
            _errorMessage =
                'Thử đồ thất bại do lỗi xử lý AI. Vui lòng thử lại sau.';
          });
        }
      } catch (e) {
        debugPrint('Lỗi kiểm tra trạng thái: $e');
      }
    });
  }

  Future<void> _saveImageToGallery(String imageUrl) async {
    setState(() => _isSavingImage = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang tải hình ảnh xuống...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    try {
      final dioClient = dio_pkg.Dio();
      final response = await dioClient.get(
        imageUrl,
        options: dio_pkg.Options(responseType: dio_pkg.ResponseType.bytes),
      );

      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data as List<int>),
        quality: 100,
        name: "vcloset_tryon_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result != null && result['isSuccess'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã lưu ảnh thử đồ vào Thư viện thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception(result?['errorMessage'] ?? 'Lưu thất bại.');
      }
    } catch (e) {
      debugPrint('Save image exception: $e');
      if (mounted) {
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

  Widget _buildWardrobeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Phối thêm đồ từ Tủ đồ của bạn (Tùy chọn):',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingWardrobe)
          const SizedBox(
            height: 90,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_wardrobeItems.isEmpty)
          Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              'Tủ đồ của bạn chưa có sản phẩm nào.',
              style: TextStyle(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _wardrobeItems.length,
              itemBuilder: (context, index) {
                final item = _wardrobeItems[index];
                final isSelected = _selectedWardrobeItem == item;
                final imgUrl = item.originalImageUrl ?? item.imageUrl;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedWardrobeItem = isSelected ? null : item;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.grey[300]!,
                                  width: isSelected ? 3 : 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  imgUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) =>
                                      const Icon(Icons.image),
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: AppColors.primary,
                                  child: Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildUploadModelItem() {
    final isCustomSelected =
        _customModelFile != null && _selectedModelUrl == null;
    return GestureDetector(
      onTap: _showImageSourceDialog,
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCustomSelected
                        ? AppColors.primary
                        : Colors.grey[300]!,
                    width: isCustomSelected ? 3 : 1.5,
                  ),
                ),
                child: ClipOval(
                  child: _customModelFile != null
                      ? Image.file(_customModelFile!, fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[100],
                          child: const Icon(
                            Icons.add_photo_alternate_rounded,
                            color: Colors.grey,
                            size: 26,
                          ),
                        ),
                ),
              ),
              if (isCustomSelected)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _customModelFile != null ? 'Ảnh đã chọn' : 'Tự tải ảnh',
            style: TextStyle(
              fontSize: 11,
              fontWeight: isCustomSelected
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: isCustomSelected ? AppColors.primary : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelItem({
    required String name,
    required String url,
    bool isPersonal = false,
  }) {
    final isSelected = _selectedModelUrl == url && _customModelFile == null;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedModelUrl = url;
          _customModelFile = null;
        });
      },
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.grey[300]!,
                    width: isSelected ? 3 : 1.5,
                  ),
                ),
                child: ClipOval(
                  child: url.startsWith('assets/')
                      ? Image.asset(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.person),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) =>
                              const Icon(Icons.person),
                        ),
                ),
              ),
              if (isSelected)
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                ),
              if (isPersonal)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Mannequin',
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppColors.primary : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String garmentUrl) {
    if (_isLoadingProfile) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Đang tải cấu hình...',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_isGenerating) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 220,
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_selectedModelUrl != null)
                      _selectedModelUrl!.startsWith('assets/')
                          ? Image.asset(_selectedModelUrl!, fit: BoxFit.cover)
                          : Image.network(_selectedModelUrl!, fit: BoxFit.cover)
                    else if (_customModelFile != null)
                      Image.file(_customModelFile!, fit: BoxFit.cover)
                    else
                      Container(color: Colors.grey[200]),
                    Container(color: Colors.black26),
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * 280 + 10,
                          left: 10,
                          right: 10,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.greenAccent.withOpacity(0.8),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _loadingMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quá trình này có thể mất tới 15-30 giây. Vui lòng không đóng ứng dụng.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã trôi qua: ${_elapsedSeconds}s',
              style: const TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ],
        ),
      );
    }

    if (_resultUrl != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.network(
                    _resultUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '✨ Thử đồ ảo thành công! ✨',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _resultUrl = null;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isSavingImage
                          ? null
                          : () => _saveImageToGallery(_resultUrl!),
                      icon: _isSavingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: const Text('Tải về máy'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Không thể hoàn tất mặc thử',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Quay lại chọn mẫu'),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(garmentUrl, fit: BoxFit.cover),
                        ),
                      ),
                      if (_selectedWardrobeItem != null) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.link_rounded,
                            size: 24,
                            color: Colors.grey,
                          ),
                        ),
                        Container(
                          width: 90,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _selectedWardrobeItem!.originalImageUrl ??
                                  _selectedWardrobeItem!.imageUrl,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Icon(
                          Icons.add_rounded,
                          size: 28,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        width: 90,
                        height: 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: _selectedModelUrl != null
                              ? (_selectedModelUrl!.startsWith('assets/')
                                    ? Image.asset(
                                        _selectedModelUrl!,
                                        fit: BoxFit.cover,
                                      )
                                    : Image.network(
                                        _selectedModelUrl!,
                                        fit: BoxFit.cover,
                                      ))
                              : (_customModelFile != null
                                    ? Image.file(
                                        _customModelFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(color: Colors.grey[200])),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chọn người mẫu thử đồ:',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildUploadModelItem(),
                        const SizedBox(width: 12),
                        if (_personalMannequinUrl != null &&
                            _personalMannequinUrl!.isNotEmpty) ...[
                          _buildModelItem(
                            name: 'Cá nhân',
                            url: _personalMannequinUrl!,
                            isPersonal: true,
                          ),
                          const SizedBox(width: 12),
                        ],
                        ..._sampleModels.map(
                          (model) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _buildModelItem(
                              name: model['name']!,
                              url: model['url']!,
                              isPersonal: false,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_personalMannequinUrl == null ||
                      _personalMannequinUrl!.isEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          size: 16,
                          color: Colors.amber[700],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mẹo: Tạo Mannequin riêng bằng cách cập nhật chiều cao/cân nặng tại trang Cá nhân.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildWardrobeSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: const [
                    Icon(Icons.landscape_rounded, color: Colors.grey, size: 20),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Giữ nguyên phông nền ảnh mẫu',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Switch(
                value: _restoreBackground,
                onChanged: (val) {
                  setState(() {
                    _restoreBackground = val;
                  });
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.amber[800],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lượt thử AI còn lại: ${_localStorage.getTryOnCredits()} lượt. Thử đồ sẽ tốn 1 lượt.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber[900],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _startTryOn,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text(
                'Bắt đầu mặc thử',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garmentUrl = _getProductImage(widget.product);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Mặc thử AI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
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
              ),
              const Divider(height: 1),
              Expanded(child: _buildBody(garmentUrl)),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget nút tròn back/favorite
class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
    );
  }
}
