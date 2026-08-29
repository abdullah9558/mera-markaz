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
    semanticLabel: 'MeraMarkaz',
  );
}

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: dark
                  ? const [
                      Color(0xFF061713),
                      Color(0xFF082923),
                      Color(0xFF061713),
                    ]
                  : const [
                      Color(0xFFF1FAF7),
                      Color(0xFFE6F7F3),
                      Color(0xFFFFFAED),
                    ],
            ),
          ),
        ),
        PositionedDirectional(
          top: -130,
          end: -100,
          child: _GlowOrb(
            size: 310,
            color: AppColors.teal.withValues(alpha: dark ? .22 : .12),
          ),
        ),
        PositionedDirectional(
          bottom: 70,
          start: -120,
          child: _GlowOrb(
            size: 280,
            color: AppColors.saffron.withValues(alpha: dark ? .11 : .09),
          ),
        ),
        child,
      ],
    );
  }
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
