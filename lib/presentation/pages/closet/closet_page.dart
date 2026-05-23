import 'dart:io';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/datasources/bg_removal_service.dart';
import '../../../../data/datasources/wardrobe_api_service.dart';
import '../../../../domain/entities/clothing_item.dart';

class ClosetPage extends StatefulWidget {
  const ClosetPage({super.key});

  @override
  State<ClosetPage> createState() => _ClosetPageState();
}

class _ClosetPageState extends State<ClosetPage> {
  final WardrobeApiService _apiService = GetIt.I<WardrobeApiService>();
  final ImagePicker _picker = ImagePicker();
  List<ClothingItem> _items = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tất cả';

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
    _fetchItems();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tủ đồ của tôi',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Kho lưu trữ thời trang hằng ngày',
                          style: TextStyle(color: Color(0x994A3728)),
                        ),
                      ],
                    ),
                  ),
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
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: FadeInDown(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tổng số món đồ',
                              style: TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isLoading ? '--' : '${_items.length}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.checkroom_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        ),
      ),
    );
  }

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
                      label: const Text('Chỉnh sửa'),
                      onPressed: () {
                        Navigator.pop(context); // Close details sheet
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
                      label: const Text('Xóa'),
                      onPressed: () {
                        Navigator.pop(context); // Close details sheet
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
      Navigator.pop(context); // Close loading dialog

      if (deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa món đồ khỏi tủ đồ thành công!')),
        );
        _fetchItems(); // Reload
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

    // Tìm key tương ứng của category
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
      Navigator.pop(context); // Close loading dialog

      if (updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật thành công!')),
        );
        _fetchItems(); // Reload
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
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Hiển thị dialog để nhập thông tin
      final details = await _showDetailsDialog(File(image.path));
      if (details == null) return;

      // Hiển thị loading overlay
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

      // 1. Tách nền ảnh
      final bgRemovalService = GetIt.I<BgRemovalService>();
      final Uint8List? resultBytes = await bgRemovalService.removeBackground(File(image.path));

      File fileToUpload = File(image.path);
      if (resultBytes != null) {
        final tempFile = File('${Directory.systemTemp.path}/transparent_${DateTime.now().millisecondsSinceEpoch}.png');
        await tempFile.writeAsBytes(resultBytes);
        fileToUpload = tempFile;
      }

      // 2. Upload và tạo món đồ mới
      final newItem = await _apiService.uploadAndCreateItem(
        imageFile: fileToUpload,
        category: details['category']!,
        name: details['name']!,
      );

      // Đóng loading dialog
      if (mounted && isDialogOpen) {
        Navigator.pop(context);
      }

      if (newItem != null) {
        _fetchItems(); // Tải lại danh sách
        
        // Show success alert
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
      // Đóng loading dialog nếu xảy ra lỗi
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xảy ra lỗi: $e')),
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
            color: AppColors.primary.withValues(alpha: 0.25),
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
            style: TextStyle(color: AppColors.primary.withValues(alpha: 0.6)),
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
            color: AppColors.primary.withValues(alpha: 0.06),
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
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.secondary,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.primary,
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
                        color: Colors.white.withValues(alpha: 0.92),
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
                const SizedBox(height: 2),
                Text(
                  item.brand?.isNotEmpty == true
                      ? item.brand!
                      : 'Chưa có thương hiệu',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary.withValues(alpha: 0.55),
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
