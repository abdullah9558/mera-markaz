import '../../../core/calculators/calculator.dart';

class FuelInput {
  const FuelInput({
    required this.distanceKm,
    required this.liters,
    this.fuelPrice = 0,
  });
  final double distanceKm;
  final double liters;
  final double fuelPrice;
}

class FuelResult {
  const FuelResult({
    required this.averageKmPerLiter,
    required this.tripCost,
    required this.costPerKm,
  });
  final double averageKmPerLiter;
  final double tripCost;
  final double costPerKm;
}

class FuelCalculator implements Calculator<FuelInput, FuelResult> {
  const FuelCalculator();
  @override
  FuelResult calculate(FuelInput input) {
    if (input.distanceKm < 0 || input.fuelPrice < 0) {
      throw const CalculationException(
        'Distance and fuel price cannot be negative.',
      );
    }
    if (input.liters <= 0) {
      throw const CalculationException(
        'Fuel consumed must be greater than zero.',
      );
    }
    final cost = input.liters * input.fuelPrice;
    return FuelResult(
      averageKmPerLiter: input.distanceKm / input.liters,
      tripCost: cost,
      costPerKm: input.distanceKm == 0 ? 0 : cost / input.distanceKm,
    );
  }
}

class TripCostInput {
  const TripCostInput({
    required this.distanceKm,
    required this.averageKmPerLiter,
    required this.fuelPrice,
  });
  final double distanceKm;
  final double averageKmPerLiter;
  final double fuelPrice;
}

class TripCostResult {
  const TripCostResult({required this.litersRequired, required this.cost});
  final double litersRequired;
  final double cost;
}

class TripCostCalculator implements Calculator<TripCostInput, TripCostResult> {
  const TripCostCalculator();
  @override
  TripCostResult calculate(TripCostInput input) {
    if (input.distanceKm < 0 || input.fuelPrice < 0) {
      throw const CalculationException(
        'Distance and price cannot be negative.',
      );
    }
    if (input.averageKmPerLiter <= 0) {
      throw const CalculationException(
        'Vehicle average must be greater than zero.',
      );
    }
    final liters = input.distanceKm / input.averageKmPerLiter;
    return TripCostResult(
      litersRequired: liters,
      cost: liters * input.fuelPrice,
    );
  }
}
