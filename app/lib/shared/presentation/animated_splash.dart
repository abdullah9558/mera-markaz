import 'package:flutter/material.dart';

class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key, required this.child, this.complete = true});

  final Widget child;
  final bool complete;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 820),
  )..forward();
  bool _visible = true;
  bool _animationFinished = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationFinished = true;
        _hideWhenReady();
      }
    });
  }

  @override
  void didUpdateWidget(covariant AnimatedSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.complete && widget.complete) _hideWhenReady();
  }

  void _hideWhenReady() {
    if (!_animationFinished || !widget.complete || !_visible || !mounted) return;
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted && _visible && widget.complete) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion && _visible && widget.complete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _visible = false);
      });
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          ignoring: !_visible,
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            child: ExcludeSemantics(
              excluding: !_visible,
              child: _SplashContent(
                animation: _controller,
                reduceMotion: reduceMotion,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent({required this.animation, required this.reduceMotion});

  final Animation<double> animation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final nameStyle = Theme.of(context).textTheme.headlineMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w800,
      letterSpacing: -.8,
    );
    final mottoStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w500,
    );

    return ColoredBox(
      color: scheme.surface,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final progress = reduceMotion ? 1.0 : animation.value;
              final logoProgress = Curves.easeOutCubic.transform(
                _interval(progress, 0, .45),
              );
              final nameOpacity = Curves.easeOut.transform(
                _interval(progress, .28, .55),
              );
              final mottoOpacity = Curves.easeOut.transform(
                _interval(progress, .42, .68),
              );
              final startingOffset = 0.0;
              final endingOffset = -constraints.maxHeight * .10;
              final logoOffset =
                  startingOffset + (endingOffset - startingOffset) * logoProgress;

              return Center(
                child: Transform.translate(
                  offset: Offset(0, logoOffset),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Mera Markaz',
                        image: true,
                        child: Image.asset(
                          'assets/branding/meramarkaz-logo.png',
                          width: 132,
                          height: 132,
                          cacheWidth: 264,
                          cacheHeight: 264,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: nameOpacity,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - nameOpacity)),
                          child: Text('Mera Markaz', style: nameStyle),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Opacity(
                        opacity: mottoOpacity,
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - mottoOpacity)),
                          child: Text('Your money. Your markaz.', style: mottoStyle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

double _interval(double value, double begin, double end) {
  return ((value - begin) / (end - begin)).clamp(0.0, 1.0).toDouble();
}
