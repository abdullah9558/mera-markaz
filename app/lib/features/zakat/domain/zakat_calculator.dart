import '../../../core/calculators/calculator.dart';

class ZakatInput {
  const ZakatInput({
    required this.assets,
    required this.liabilities,
    required this.nisab,
  });
  final double assets;
  final double liabilities;
  final double nisab;
}

class ZakatResult {
  const ZakatResult({
    required this.netZakatable,
    required this.nisab,
    required this.zakatDue,
  });
  final double netZakatable;
  final double nisab;
  final double zakatDue;
  bool get isDue => netZakatable >= nisab;
}

class ZakatCalculator implements Calculator<ZakatInput, ZakatResult> {
  const ZakatCalculator();
  @override
  ZakatResult calculate(ZakatInput input) {
    if (input.assets < 0 || input.liabilities < 0 || input.nisab < 0) {
      throw const CalculationException(
        'Assets, liabilities and Nisab cannot be negative.',
      );
    }
    final net = input.assets - input.liabilities;
    final eligible = net < 0 ? 0.0 : net;
    return ZakatResult(
      netZakatable: eligible,
      nisab: input.nisab,
      zakatDue: eligible >= input.nisab ? eligible * .025 : 0,
    );
  }
}
