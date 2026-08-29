abstract interface class Calculator<I, O> {
  O calculate(I input);
}

class CalculationException implements Exception {
  const CalculationException(this.message);
  final String message;
  @override
  String toString() => message;
}
