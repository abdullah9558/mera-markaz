import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/theme/app_theme.dart';
import 'package:pakpocket/shared/presentation/brand_widgets.dart';

double _contrast(Color first, Color second) {
  final light = first.computeLuminance();
  final dark = second.computeLuminance();
  final high = light > dark ? light : dark;
  final low = light > dark ? dark : light;
  return (high + .05) / (low + .05);
}

void main() {
  test('light and dark themes retain readable body contrast', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      expect(
        _contrast(theme.colorScheme.onSurface, theme.colorScheme.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    }
  });

  testWidgets('interactive cards respect reduced-motion preference', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: InteractiveTap(onTap: _noop, child: Text('Accessible card')),
          ),
        ),
      ),
    );
    final scale = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(scale.duration, Duration.zero);
    expect(find.text('Accessible card'), findsOneWidget);
  });
}

void _noop() {}
