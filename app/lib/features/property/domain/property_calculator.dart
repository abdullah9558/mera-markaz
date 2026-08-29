import '../../../core/calculators/calculator.dart';

enum AreaUnit { squareFeet, squareYards, squareMeters, marla, kanal, acres }

class PropertyInput {
  const PropertyInput({
    required this.length,
    required this.width,
    this.dimensionUnit = AreaUnit.squareFeet,
    this.marlaSquareFeet = 272.25,
    this.pricePerMarla = 0,
  });
  final double length;
  final double width;
  final AreaUnit dimensionUnit;
  final double marlaSquareFeet;
  final double pricePerMarla;
}

class PropertyResult {
  const PropertyResult({
    required this.squareFeet,
    required this.marla,
    required this.price,
  });
  final double squareFeet;
  final double marla;
  final double price;
  double get kanal => marla / 20;
  double get squareYards => squareFeet / 9;
  double get squareMeters => squareFeet / 10.7639104167;
  double get acres => squareFeet / 43560;
}

class PropertyCalculator implements Calculator<PropertyInput, PropertyResult> {
  const PropertyCalculator();
  @override
  PropertyResult calculate(PropertyInput input) {
    if (input.length <= 0 || input.width <= 0) {
      throw const CalculationException(
        'Length and width must be greater than zero.',
      );
    }
    if (input.marlaSquareFeet <= 0 || input.pricePerMarla < 0) {
      throw const CalculationException(
        'Marla standard must be positive and price cannot be negative.',
      );
    }
    final factor = switch (input.dimensionUnit) {
      AreaUnit.squareFeet => 1.0,
      AreaUnit.squareYards => 9.0,
      AreaUnit.squareMeters => 10.7639104167,
      AreaUnit.marla => input.marlaSquareFeet,
      AreaUnit.kanal => input.marlaSquareFeet * 20,
      AreaUnit.acres => 43560.0,
    };
    final squareFeet = input.length * input.width * factor;
    final marla = squareFeet / input.marlaSquareFeet;
    return PropertyResult(
      squareFeet: squareFeet,
      marla: marla,
      price: marla * input.pricePerMarla,
    );
  }
}
