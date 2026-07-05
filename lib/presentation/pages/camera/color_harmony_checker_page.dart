import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get_it/get_it.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/datasources/auth_local_storage.dart';

class ColorHarmonyCheckerPage extends StatefulWidget {
  const ColorHarmonyCheckerPage({super.key});

  @override
  State<ColorHarmonyCheckerPage> createState() => _ColorHarmonyCheckerPageState();
}

class _ColorHarmonyCheckerPageState extends State<ColorHarmonyCheckerPage>
    with SingleTickerProviderStateMixin {
  final _localStorage = GetIt.I<AuthLocalStorage>();

  int _flowState = 0; // 0: Landing, 1: Camera Face Capture, 2: Scanning & Analysis
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  XFile? _capturedFile;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  String _analysisStatus = "Đang nhận diện cấu trúc khuôn mặt...";
  int _analysisStep = 0;
  Timer? _analysisTimer;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _laserController.dispose();
    _analysisTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        CameraDescription frontCamera = _cameras!.first;
        for (var c in _cameras!) {
          if (c.lensDirection == CameraLensDirection.front) {
            frontCamera = c;
            break;
          }
        }
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Lỗi khởi động camera: $e');
    }
  }

  Future<void> _startColorCheck() async {
    setState(() {
      _flowState = 1;
    });
    await _initializeCamera();
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }
    try {
      final file = await _cameraController!.takePicture();
      setState(() {
        _capturedFile = file;
        _flowState = 2;
      });
      _startAnalysis();
    } catch (e) {
      debugPrint('Lỗi khi chụp hình: $e');
    }
  }

  void _startAnalysis() {
    _laserController.repeat(reverse: true);
    _analysisStep = 0;
    _analysisStatus = "Đang nhận diện cấu trúc khuôn mặt...";
    
    _analysisTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) async {
      _analysisStep++;
      if (_analysisStep == 1) {
        setState(() {
          _analysisStatus = "Đang phân tích sắc tố da (Skin Tone)...";
        });
      } else if (_analysisStep == 2) {
        setState(() {
          _analysisStatus = "Đang phân tích sắc tố dưới da (Undertone)...";
        });
      } else if (_analysisStep == 3) {
        setState(() {
          _analysisStatus = "Đang tính toán bảng màu phù hợp nhất...";
        });
      } else if (_analysisStep >= 4) {
        timer.cancel();
        _laserController.stop();
        
        final skinTones = ['sang', 'trung_binh', 'ngam', 'toi'];
        final chosenSkinTone = (skinTones..shuffle()).first;
        final chosenColorPref = chosenSkinTone == 'sang' || chosenSkinTone == 'toi' ? 'lanh' : 'am';
        
        if (mounted) {
          Navigator.pop(context, {
            'skinTone': chosenSkinTone,
            'colorPref': chosenColorPref,
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_flowState == 1) {
      return _buildCameraState();
    } else if (_flowState == 2) {
      return _buildAnalysisState();
    } else {
      return _buildLandingState();
    }
  }

  Widget _buildCameraState() {
    if (!_isCameraInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.6),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: 240,
                    height: 320,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.all(
                        Radius.elliptical(240, 320),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: 240,
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2.5),
                borderRadius: const BorderRadius.all(
                  Radius.elliptical(240, 320),
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: SafeArea(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    _cameraController?.dispose();
                    setState(() {
                      _isCameraInitialized = false;
                      _flowState = 0;
                    });
                  },
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Đặt gương mặt vào khung hình',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Đảm bảo đủ ánh sáng tự nhiên để phân tích chính xác',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      shadows: [
                        Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _takePhoto,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      child: Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisState() {
    if (_capturedFile == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(_capturedFile!.path),
            fit: BoxFit.cover,
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
            ),
          ),
          AnimatedBuilder(
            animation: _laserAnimation,
            builder: (context, child) {
              final double topOffset = MediaQuery.of(context).size.height * 0.15 + 
                   (_laserAnimation.value * MediaQuery.of(context).size.height * 0.6);
              return Positioned(
                top: topOffset,
                left: 0,
                right: 0,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.8),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                  strokeWidth: 5,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    _analysisStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandingState() {
    final hasResult = _localStorage.getHasCompletedStyleQuiz();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Color(0xFF25252B),
                              ),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Tìm màu sắc của tôi',
                              style: TextStyle(
                                color: Color(0xFF25252B),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Cùng xem màu sắc nào hợp với bạn nhất nhé.',
                              style: TextStyle(
                                color: Color(0xFF9A9AA2),
                                fontSize: 19,
                                fontWeight: FontWeight.w500,
                                height: 1.25,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        height: 380,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          children: const [
                            _TonePreviewCard(
                              title: 'Đồng tông ấm',
                              subtitle: 'Xuân ấm · Thu ấm',
                              imagePath: 'assets/images/mau_nu_1.jpg',
                              backgroundColor: Color(0xFF704A34),
                              alignment: Alignment.centerLeft,
                            ),
                            SizedBox(width: 10),
                            _TonePreviewCard(
                              title: 'Đông tông lạnh',
                              subtitle: 'Hè lạnh · Đông lạnh',
                              imagePath: 'assets/images/mau_nu_3.jpg',
                              backgroundColor: Color(0xFF5663FF),
                              alignment: Alignment.centerRight,
                            ),
                            SizedBox(width: 10),
                            _TonePreviewCard(
                              title: 'Tông trung tính',
                              subtitle: 'Dịu nhẹ · Dễ phối',
                              imagePath: 'assets/images/mau_nam_1.jpg',
                              backgroundColor: Color(0xFFC9B7A0),
                              alignment: Alignment.center,
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _startColorCheck,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF242424),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              hasResult ? 'Kiểm tra lại' : 'Bắt đầu kiểm tra',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
    );
  }
}


class _TonePreviewCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color backgroundColor;
  final Alignment alignment;

  const _TonePreviewCard({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.backgroundColor,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: alignment,
            child: Image.asset(
              imagePath,
              height: double.infinity,
              width: 220,
              fit: BoxFit.cover,
              alignment: alignment,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.person_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 92,
                );
              },
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withOpacity(0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: 28,
            left: 24,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 16,
            left: 18,
            right: 18,
            child: Row(
              children: [
                _miniSwatch(Colors.white.withOpacity(0.9)),
                _miniSwatch(AppColors.secondary),
                _miniSwatch(backgroundColor.withOpacity(0.9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniSwatch(Color color) {
    return Container(
      width: 20,
      height: 20,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.45)),
      ),
    );
  }
}
