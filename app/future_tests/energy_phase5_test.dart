import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/electricity/data/energy_intelligence_repository.dart';
import 'package:pakpocket/features/electricity/domain/energy_intelligence.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late EnergyIntelligenceRepository repository;
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-five');
    repository = EnergyIntelligenceRepository(database);
  });
  tearDown(() => database.close());

  test('electricity readings persist actual and estimated labels', () async {
    await repository.saveReading(
      ElectricityReading(
        provider: 'LESCO',
        billingMonth: DateTime(2026, 7),
        units: 420,
        actualBill: 28500,
        isActual: true,
      ),
    );
    await repository.saveReading(
      ElectricityReading(
        provider: 'LESCO',
        billingMonth: DateTime(2026, 8),
        units: 450,
        estimatedBill: 31000,
        isActual: false,
      ),
    );
    final history = await repository.readings();
    expect(history, hasLength(2));
    expect(history.first.isActual, isTrue);
    expect(history.last.isActual, isFalse);
  });

  test('appliance what-if scenario reduces consumption and cost', () {
    const ac = ApplianceUsage(
      name: 'AC',
      quantity: 1,
      wattage: 1800,
      hoursPerDay: 8,
      daysPerMonth: 30,
      tariffPerKwh: 60,
    );
    final reduced = ac.withHours(6);
    expect(ac.monthlyKwh, 432);
    expect(reduced.monthlyKwh, 324);
    expect(reduced.estimatedCost, lessThan(ac.estimatedCost));
  });

  test(
    'solar recommendation uses recorded history and configurable panel size',
    () {
      final history = [300, 400, 500]
          .map(
            (units) => ElectricityReading(
              provider: 'LESCO',
              billingMonth: DateTime(2026, units ~/ 100),
              units: units.toDouble(),
              isActual: true,
            ),
          )
          .toList();
      final result = SolarRecommendation.fromHistory(
        history,
        panelWattage: 600,
        annualKwhPerKw: 1500,
        designCoverage: .8,
      );
      expect(result.averageMonthlyKwh, 400);
      expect(result.panelCount, 5);
      expect(result.systemKw, 3);
      expect(result.gridReductionPercent, closeTo(93.75, .01));
    },
  );

  test(
    'solar ROI persists monthly performance and estimates remaining months',
    () async {
      final id = await repository.saveSolarSystem(
        name: 'Home Solar',
        installed: DateTime(2026, 1),
        systemKw: 5,
        panelCount: 9,
        panelWattage: 585,
        installationCost: 1000000,
      );
      await repository.saveSolarPerformance(
        systemId: id,
        month: DateTime(2026, 7),
        generation: 650,
        estimatedSavings: 30000,
      );
      await repository.saveSolarPerformance(
        systemId: id,
        month: DateTime(2026, 8),
        generation: 620,
        estimatedSavings: 28000,
      );
      final roi = await repository.solarRoi(id);
      expect(roi!.accumulatedSavings, 58000);
      expect(roi.monthlyAverageSavings, 29000);
      expect(roi.remainingMonths, closeTo(32.48, .01));
    },
  );
}
