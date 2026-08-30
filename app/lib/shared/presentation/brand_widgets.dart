import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/branding/meramarkaz-logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    filterQuality: FilterQuality.high,
    color: AppColors.emerald,
    colorBlendMode: BlendMode.srcIn,
    semanticLabel: 'MeraMarkaz',
  );
}

class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final progress = reduceMotion ? .5 : _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + progress * .25, -1),
                  end: Alignment(1, .8 - progress * .25),
                  colors: dark
                      ? const [
                          Color(0xFF050507),
                          Color(0xFF0A1325),
                          Color(0xFF090A11),
                        ]
                      : const [
                          Color(0xFFFFFAF5),
                          Color(0xFFEDF3FF),
                          Color(0xFFF7F4FF),
                        ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _DigitalGridPainter(
                    color: AppColors.cyan.withValues(alpha: dark ? .045 : .03),
                    shift: progress,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              top: -150 + progress * 38,
              end: -115 + progress * 24,
              child: _GlowOrb(
                size: 340,
                color: AppColors.cyan.withValues(alpha: dark ? .18 : .10),
              ),
            ),
            PositionedDirectional(
              top: 260 - progress * 32,
              start: -190 + progress * 40,
              child: _GlowOrb(
                size: 390,
                color: AppColors.emerald.withValues(alpha: dark ? .13 : .08),
              ),
            ),
            PositionedDirectional(
              bottom: -100 + progress * 24,
              end: -170 + progress * 30,
              child: _GlowOrb(
                size: 330,
                color: AppColors.saffron.withValues(alpha: dark ? .075 : .06),
              ),
            ),
            child!,
          ],
        );
      },
    );
  }
}

class InteractiveTap extends StatefulWidget {
  const InteractiveTap({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
  });

  final VoidCallback onTap;
  final Widget child;
  final BorderRadius borderRadius;

  @override
  State<InteractiveTap> createState() => _InteractiveTapState();
}

class _InteractiveTapState extends State<InteractiveTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .965 : 1,
    duration: const Duration(milliseconds: 130),
    curve: Curves.easeOutCubic,
    child: Material(
      color: Colors.transparent,
      borderRadius: widget.borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onHighlightChanged: (value) {
          if (_pressed != value) setState(() => _pressed = value);
        },
        onTap: () {
          Feedback.forTap(context);
          widget.onTap();
        },
        borderRadius: widget.borderRadius,
        child: widget.child,
      ),
    ),
  );
}

class _DigitalGridPainter extends CustomPainter {
  const _DigitalGridPainter({required this.color, required this.shift});

  final Color color;
  final double shift;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .7;
    const spacing = 44.0;
    final offset = shift * spacing;
    for (double x = -spacing + offset; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = -spacing + offset; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_DigitalGridPainter oldDelegate) =>
      oldDelegate.shift != shift || oldDelegate.color != color;
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}
