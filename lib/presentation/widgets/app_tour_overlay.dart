import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum AppTourCoachAction { next, finish }

class AppTourOverlay {
  static Future<AppTourCoachAction?> showCoachStep(
    BuildContext context, {
    required GlobalKey targetKey,
    required int stepNumber,
    required int totalSteps,
    required IconData icon,
    required String title,
    required String description,
    required String primaryLabel,
    String secondaryLabel = 'Kết thúc',
  }) {
    final targetRect = _findTargetRect(targetKey);

    return showGeneralDialog<AppTourCoachAction>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _CoachMarkOverlay(
          targetRect: targetRect,
          stepNumber: stepNumber,
          totalSteps: totalSteps,
          icon: icon,
          title: title,
          description: description,
          primaryLabel: primaryLabel,
          secondaryLabel: secondaryLabel,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  static Rect? _findTargetRect(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return null;

    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }
}

class _CoachMarkOverlay extends StatelessWidget {
  final Rect? targetRect;
  final int stepNumber;
  final int totalSteps;
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;

  const _CoachMarkOverlay({
    required this.targetRect,
    required this.stepNumber,
    required this.totalSteps,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final safeTop = media.padding.top;
    final safeBottom = media.padding.bottom;
    final rect = targetRect?.inflate(10);

    const horizontalMargin = 18.0;
    const maxCardWidth = 430.0;
    const estimatedCardHeight = 250.0;
    final cardWidth = (size.width - horizontalMargin * 2)
        .clamp(0.0, maxCardWidth)
        .toDouble();
    final cardLeft = ((size.width - cardWidth) / 2)
        .clamp(horizontalMargin, size.width)
        .toDouble();

    final targetIsLow = rect != null && rect.center.dy > size.height * 0.58;
    final minTop = safeTop + 16;
    final maxTop = size.height - safeBottom - estimatedCardHeight - 16;
    final boundedMaxTop = maxTop < minTop ? minTop : maxTop;
    final fallbackTop = (size.height - estimatedCardHeight - safeBottom - 24)
        .clamp(minTop, boundedMaxTop)
        .toDouble();
    final cardBottom = rect != null && targetIsLow
        ? (size.height - rect.top + 30)
              .clamp(safeBottom + 18, size.height - safeTop - 96)
              .toDouble()
        : null;
    final cardTop = cardBottom != null
        ? null
        : rect == null
        ? fallbackTop
        : (rect.bottom + 18).clamp(minTop, boundedMaxTop).toDouble();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CoachDimPainter(targetRect: rect),
            ),
          ),
          if (rect != null) ...[
            Positioned.fromRect(
              rect: rect,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context, AppTourCoachAction.next);
                },
                child: const _TargetHighlight(),
              ),
            ),
            _CoachPointer(targetRect: rect, targetIsLow: targetIsLow),
          ],
          Positioned(
            left: cardLeft,
            top: cardTop,
            bottom: cardBottom,
            width: cardWidth,
            child: _CoachCard(
              stepNumber: stepNumber,
              totalSteps: totalSteps,
              icon: icon,
              title: title,
              description: description,
              primaryLabel: primaryLabel,
              secondaryLabel: secondaryLabel,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetHighlight extends StatelessWidget {
  const _TargetHighlight();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.20),
            blurRadius: 18,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.34),
            blurRadius: 28,
            spreadRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _CoachPointer extends StatelessWidget {
  final Rect targetRect;
  final bool targetIsLow;

  const _CoachPointer({
    required this.targetRect,
    required this.targetIsLow,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: targetRect.center.dx - 9,
      top: targetIsLow ? targetRect.top - 13 : targetRect.bottom + 3,
      child: Transform.rotate(
        angle: targetIsLow ? 0.78 : -2.36,
        child: Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(3)),
          ),
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final IconData icon;
  final String title;
  final String description;
  final String primaryLabel;
  final String secondaryLabel;

  const _CoachCard({
    required this.stepNumber,
    required this.totalSteps,
    required this.icon,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.secondaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Thiết lập tủ đồ',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '$stepNumber/$totalSteps',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: AppColors.primary.withOpacity(0.70),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.42,
            ),
          ),
          const SizedBox(height: 16),
          _StepProgress(stepNumber: stepNumber, totalSteps: totalSteps),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          primaryLabel,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 104,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary.withOpacity(0.20),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context, AppTourCoachAction.finish);
                  },
                  child: Text(
                    secondaryLabel,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;

  const _StepProgress({
    required this.stepNumber,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps, (index) {
        final active = index < stepNumber;
        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 4,
            margin: EdgeInsets.only(right: index == totalSteps - 1 ? 0 : 5),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }
}

class _CoachDimPainter extends CustomPainter {
  final Rect? targetRect;

  const _CoachDimPainter({required this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.62);
    final fullPath = Path()..addRect(Offset.zero & size);

    if (targetRect == null) {
      canvas.drawPath(fullPath, overlayPaint);
      return;
    }

    final targetPath = Path()
      ..addRRect(
        RRect.fromRectAndRadius(targetRect!, const Radius.circular(24)),
      );
    final dimPath = Path.combine(PathOperation.difference, fullPath, targetPath);
    canvas.drawPath(dimPath, overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _CoachDimPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
