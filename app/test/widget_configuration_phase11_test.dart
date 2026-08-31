import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/widgets/widget_snapshot_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pk.pakpocket.pakpocket/widgets');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'widget privacy defaults hidden and configuration is explicit',
    () async {
      MethodCall? received;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            received = call;
            return null;
          });
      await const WidgetSnapshotService().configure(
        const WidgetPreferences(
          privacy: WidgetPrivacy.visible,
          theme: WidgetTheme.dark,
          insight: 'udhaar',
          market: 'gold_24k_tola',
          quickActions: ['income', 'fuel', 'scan'],
        ),
      );
      expect(received?.method, 'configure');
      expect((received?.arguments as Map)['privacy'], 'visible');
      expect((received?.arguments as Map)['insight'], 'udhaar');
      expect((received?.arguments as Map)['quickActions'], 'income,fuel,scan');
      expect(const WidgetPreferences().privacy, WidgetPrivacy.hidden);
    },
  );

  test('saved native widget preferences are restored', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (call) async => {
            'privacy': 'hidden',
            'theme': 'light',
            'insight': 'budget',
            'market': 'aed_pkr',
          },
        );
    final value = await const WidgetSnapshotService().load();
    expect(value.privacy, WidgetPrivacy.hidden);
    expect(value.theme, WidgetTheme.light);
    expect(value.insight, 'budget');
    expect(value.market, 'aed_pkr');
  });
}
