class ClothingItem {
  final String id;
  final String name;
  final String imageUrl; // Maps to OriginalImageUrl or RemovedBgUrl
  final String? originalImageUrl;
  final String? removedBgUrl;
  final String category;
  final double? price; // Optional for compatibility with old mock
  final List<String> colorTags;
  final String? brand;
  final String? closetId;

  ClothingItem({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.originalImageUrl,
    this.removedBgUrl,
    required this.category,
    this.price,
    this.colorTags = const [],
    this.brand,
    this.closetId,
  });

  factory ClothingItem.fromJson(Map<String, dynamic> json) {
    return ClothingItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? 'Untitled',
      originalImageUrl: json['originalImageUrl'],
      removedBgUrl: json['removedBgUrl'],
      // Ưu tiên dùng ảnh đã tách nền, nếu chưa có thì dùng ảnh gốc
      imageUrl: json['removedBgUrl'] ?? json['originalImageUrl'] ?? '',
      category: json['category']?.toString() ?? 'Uncategorized',
      colorTags:
          (json['colorTags'] as List?)?.map((e) => e.toString()).toList() ?? [],
      brand: json['brand'],
      price: json['price'] != null
          ? double.tryParse(json['price'].toString())
          : null,
      closetId: json['closetId']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'originalImageUrl': originalImageUrl,
      'removedBgUrl': removedBgUrl,
      'category': category,
      'colorTags': colorTags,
      'brand': brand,
      'price': price,
      'closetId': closetId,
    };
  }
}
