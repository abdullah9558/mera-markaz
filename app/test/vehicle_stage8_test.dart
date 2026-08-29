import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/expenses/data/expense_repository.dart';
import 'package:pakpocket/features/expenses/data/module_finance_repository.dart';
import 'package:pakpocket/features/expenses/domain/finance_transaction.dart';
import 'package:pakpocket/features/fuel/data/vehicle_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;
  late VehicleRepository vehicles;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('stage-8');
    vehicles = VehicleRepository(database, ModuleFinanceRepository(database));
  });

  tearDown(() => database.close());

  test(
    'fuel history produces mileage analytics and one linked expense per fill',
    () async {
      final id = await vehicles.saveVehicle(
        name: 'Family car',
        makeModel: 'Honda City',
        fuelType: 'petrol',
        odometer: 10000,
      );
      await vehicles.addFuel(
        vehicleId: id,
        liters: 20,
        cost: 5600,
        odometer: 10000,
        filledAt: DateTime(2026, 8, 1),
      );
      await vehicles.addFuel(
        vehicleId: id,
        liters: 20,
        cost: 5800,
        odometer: 10400,
        filledAt: DateTime(2026, 8, 20),
      );

      final analytics = await vehicles.analytics(id);
      expect(analytics.totalFuelCost, 11400);
      expect(analytics.averageKmPerLiter, 10);
      final finance = await ExpenseRepository(database).all();
      expect(
        finance.where((item) => item.source == TransactionSource.fuel),
        hasLength(2),
      );
    },
  );

  test(
    'maintenance creates history and a scheduled reminder atomically',
    () async {
      final id = await vehicles.saveVehicle(
        name: 'Bike',
        fuelType: 'petrol',
        odometer: 5000,
      );
      final due = DateTime(2026, 10, 1);
      await vehicles.addMaintenance(
        vehicleId: id,
        kind: 'Oil change',
        cost: 2500,
        nextDueAt: due,
      );

      expect(await vehicles.maintenance(id), hasLength(1));
      final reminders = await database.database.query(
        'reminders',
        where: "kind = 'vehicle_maintenance' AND owner_id = ?",
        whereArgs: [database.ownerId],
      );
      expect(reminders, hasLength(1));
      expect(reminders.single['scheduled_at'], due.toIso8601String());
    },
  );
}
