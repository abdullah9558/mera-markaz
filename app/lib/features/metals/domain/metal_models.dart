enum MetalType { gold, silver }

enum MetalUnit { gram, tola, tenGrams }

class MetalHolding {
  const MetalHolding({
    this.id,
    required this.metal,
    required this.quantity,
    required this.unit,
    required this.purity,
    this.purchasePrice,
    this.purchaseDate,
    this.notes,
    this.linkedNetWorthAccountId,
  });
  final int? id, linkedNetWorthAccountId;
  final MetalType metal;
  final double quantity, purity;
  final MetalUnit unit;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? notes;
  double get grams => switch (unit) {
    MetalUnit.gram => quantity,
    MetalUnit.tola => quantity * 11.6638038,
    MetalUnit.tenGrams => quantity * 10,
  };
  double valueFromTolaRate(double rate) => grams / 11.6638038 * rate * purity;
}

class ZakatRecord {
  const ZakatRecord({
    this.id,
    required this.cash,
    required this.bank,
    required this.gold,
    required this.silver,
    required this.businessAssets,
    required this.receivables,
    required this.otherAssets,
    required this.liabilities,
    required this.nisabMethod,
    required this.nisabValue,
    required this.calculatedAt,
    this.reminderAt,
    this.sourceReference,
  });
  final int? id;
  final double cash,
      bank,
      gold,
      silver,
      businessAssets,
      receivables,
      otherAssets;
  final double liabilities, nisabValue;
  final String nisabMethod;
  final DateTime calculatedAt;
  final DateTime? reminderAt;
  final String? sourceReference;
  double get totalAssets =>
      cash + bank + gold + silver + businessAssets + receivables + otherAssets;
  double get eligibleTotal =>
      (totalAssets - liabilities).clamp(0, double.infinity).toDouble();
  double get zakatDue => eligibleTotal >= nisabValue ? eligibleTotal * .025 : 0;
}
