class CurrencyConverter {
  const CurrencyConverter();
  double convert({
    required double amount,
    required String from,
    required String to,
    required Map<String, double> pkrPerUnit,
  }) {
    if (!amount.isFinite || amount < 0) {
      throw const FormatException('Enter a valid amount.');
    }
    final fromRate = from == 'PKR' ? 1.0 : pkrPerUnit[from];
    final toRate = to == 'PKR' ? 1.0 : pkrPerUnit[to];
    if (fromRate == null || toRate == null || fromRate <= 0 || toRate <= 0) {
      throw StateError('A verified rate is unavailable.');
    }
    return amount * fromRate / toRate;
  }
}
