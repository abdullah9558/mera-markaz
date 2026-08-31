import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/entitlements/feature_flags.dart';

void main() {
  test('all features are available in the free release', () {
    const access = Entitlements();
    expect(access.canUse(AppFeature.expenseTracking), isTrue);
    expect(access.canUse(AppFeature.basicBudgets), isTrue);
    expect(access.canUse(AppFeature.basicUdhaar), isTrue);
    expect(access.canUse(AppFeature.pdfReports), isTrue);
    expect(access.canUse(AppFeature.advancedAnalytics), isTrue);
    expect(access.vehicleLimit, greaterThan(1000));
  });
}
