import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;
  final List<String> _tabs = const [
    'Khám phá',
    'Xu hướng',
    'Theo dõi',
    'Thử thách',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 20),
                    _searchBar(),
                    const SizedBox(height: 20),
                    _tabsBar(),
                    const SizedBox(height: 24),
                    _heroCard(),
                    const SizedBox(height: 24),
                    _topStylists(),
                    const SizedBox(height: 24),
                    _sectionTitle('Bảng tin cảm hứng'),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: _posts.length,
                itemBuilder: (context, index) {
                  final post = _posts[index];
                  return FadeInUp(
                    delay: Duration(milliseconds: 90 * index),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundImage: AssetImage(post.avatar),
                                  radius: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.user,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      Text(
                                        post.time,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.primary.withValues(
                                            alpha: 0.55,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.more_horiz_rounded,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(22),
                            child: Image.asset(
                              post.image,
                              width: double.infinity,
                              height: 340,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    _iconText(
                                      Icons.favorite_rounded,
                                      '${post.likes}',
                                      color: const Color(0xFFE45B62),
                                    ),
                                    const SizedBox(width: 18),
                                    _iconText(
                                      Icons.chat_bubble_rounded,
                                      '${post.comments}',
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.bookmark_outline_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  post.caption,
                                  style: const TextStyle(
                                    height: 1.4,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chào buổi sáng',
                style: TextStyle(
                  color: Color(0x994A3728),
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Lan Anh',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications_outlined,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Tìm outfit, stylist, món đồ',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
        ),
      ),
    );
  }

  Widget _tabsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final active = _activeTab == index;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              selected: active,
              label: Text(_tabs[index]),
              onSelected: (_) => setState(() => _activeTab = index),
              labelStyle: TextStyle(
                color: active ? Colors.white : AppColors.primary,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _heroCard() {
    return FadeInDown(
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          image: const DecorationImage(
            image: AssetImage('assets/images/banner.png'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFF1D130D).withValues(alpha: 0.92),
                const Color(0xFF1D130D).withValues(alpha: 0.2),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4A373),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text(
                  'THỬ THÁCH NỔI BẬT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tuần Lớp Phối Mùa Thu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Đăng outfit của bạn để lên bảng nổi bật tuần này.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topStylists() {
    return FadeInUp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Top Stylist'),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stylists.length,
              itemBuilder: (context, index) {
                final stylist = _stylists[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFD4A373),
                              Color(0xFFE9C46A),
                              Color(0xFFF4A261),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 28,
                          backgroundImage: AssetImage(stylist.avatar),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stylist.name,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
        const Spacer(),
        TextButton(onPressed: () {}, child: const Text('Xem tất cả')),
      ],
    );
  }

  Widget _iconText(
    IconData icon,
    String value, {
    Color color = AppColors.primary,
  }) {
    return Row(
      children: [
        Icon(icon, size: 21, color: color),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _Stylist {
  final String name;
  final String avatar;

  const _Stylist({required this.name, required this.avatar});
}

class _FeedPost {
  final String user;
  final String avatar;
  final String image;
  final String time;
  final String caption;
  final int likes;
  final int comments;

  const _FeedPost({
    required this.user,
    required this.avatar,
    required this.image,
    required this.time,
    required this.caption,
    required this.likes,
    required this.comments,
  });
}

const _stylists = [
  _Stylist(name: 'Lan Anh', avatar: 'assets/images/avatar1.png'),
  _Stylist(name: 'Hoàng Nam', avatar: 'assets/images/avatar2.png'),
  _Stylist(name: 'Thanh Lam', avatar: 'assets/images/avatar3.png'),
  _Stylist(name: 'Minh Khôi', avatar: 'assets/images/avatar1.png'),
];

const _posts = [
  _FeedPost(
    user: 'Minh Khôi',
    avatar: 'assets/images/avatar2.png',
    image: 'assets/images/feed2.png',
    time: '2 giờ trước',
    caption:
        'Phối lớp màu trung tính và phom dáng gọn cho buổi sáng dạo phố. #minimal #fall',
    likes: 1240,
    comments: 42,
  ),
  _FeedPost(
    user: 'Lan Anh',
    avatar: 'assets/images/avatar1.png',
    image: 'assets/images/feed1.png',
    time: '4 giờ trước',
    caption: 'Set knit đơn sắc đi cùng phụ kiện ấm áp cho cuối tuần.',
    likes: 856,
    comments: 18,
  ),
];
