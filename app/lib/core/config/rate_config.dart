class RateMetadata {
  const RateMetadata({
    required this.version,
    required this.effectiveFrom,
    required this.updatedAt,
    required this.sourceLabel,
  });
  final String version;
  final DateTime effectiveFrom;
  final DateTime updatedAt;
  final String sourceLabel;
}

abstract interface class RateConfigRepository<T> {
  Future<T> current();
  Future<void> replace(T config);
}

class TaxSlab {
  const TaxSlab({
    required this.from,
    this.to,
    required this.baseTax,
    required this.rate,
  });
  final double from;
  final double? to;
  final double baseTax;
  final double rate;
}

class TaxYearConfig {
  const TaxYearConfig({
    required this.year,
    required this.slabs,
    required this.metadata,
  });
  final String year;
  final List<TaxSlab> slabs;
  final RateMetadata metadata;
}

class ElectricityTariffConfig {
  const ElectricityTariffConfig({
    required this.provider,
    required this.category,
    required this.unitRates,
    required this.fixedCharge,
    this.fixedChargesByUnits = const {},
    required this.taxRate,
    required this.metadata,
  });
  final String provider;
  final String category;
  final Map<double, double> unitRates;
  final double fixedCharge;
  final Map<double, double> fixedChargesByUnits;
  final double taxRate;
  final RateMetadata metadata;
}

class SolarAssumptions {
  const SolarAssumptions({
    required this.panelWatts,
    required this.dailyYieldPerKw,
    required this.systemCostPerWatt,
    required this.electricityRate,
    required this.metadata,
  });
  final double panelWatts;
  final double dailyYieldPerKw;
  final double systemCostPerWatt;
  final double electricityRate;
  final RateMetadata metadata;
}
