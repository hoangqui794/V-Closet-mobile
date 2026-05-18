import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../../../domain/entities/clothing_item.dart';

class ClosetPage extends StatelessWidget {
  const ClosetPage({super.key});

  // Dữ liệu giả (Mock Data) để làm demo UI/UX
  static final List<ClothingItem> mockItems = [
    ClothingItem(
      id: '1',
      name: 'Áo Hoodie Oversize',
      imageUrl: 'https://images.unsplash.com/photo-1556821840-3a63f95609a7?q=80&w=400',
      category: 'Áo',
      price: 450000,
    ),
    ClothingItem(
      id: '2',
      name: 'Quần Jean ống rộng',
      imageUrl: 'https://images.unsplash.com/photo-1541099649105-f69ad21f3246?q=80&w=400',
      category: 'Quần',
      price: 590000,
    ),
    ClothingItem(
      id: '3',
      name: 'Giày Sneaker White',
      imageUrl: 'https://images.unsplash.com/photo-1549298916-b41d501d3772?q=80&w=400',
      category: 'Giày',
      price: 1200000,
    ),
    ClothingItem(
      id: '4',
      name: 'Áo Khoác Da Biker',
      imageUrl: 'https://images.unsplash.com/photo-1551028719-00167b16eac5?q=80&w=400',
      category: 'Áo khoác',
      price: 2500000,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: const Text('Tủ Đồ Cá Nhân', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Filter Chips Demo
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Tất cả', 'Áo', 'Quần', 'Giày', 'Phụ kiện'].map((cat) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Chip(
                      label: Text(cat),
                      backgroundColor: cat == 'Tất cả' ? Colors.purpleAccent : Colors.white10,
                      labelStyle: TextStyle(color: cat == 'Tất cả' ? Colors.white : Colors.white70),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
            // Items Grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: mockItems.length,
                itemBuilder: (context, index) {
                  final item = mockItems[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: 100 * index),
                    child: _buildItemCard(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(ClothingItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  item.category,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.price.toInt()}đ',
                  style: const TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
