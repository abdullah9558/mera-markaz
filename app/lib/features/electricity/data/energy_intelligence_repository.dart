import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/energy_intelligence.dart';

final energyIntelligenceRepositoryProvider = Provider(
  (ref) => EnergyIntelligenceRepository(ref.watch(appDatabaseProvider)),
);

class EnergyIntelligenceRepository {
  const EnergyIntelligenceRepository(this.database);
  final AppDatabase database;

  Future<int> saveReading(ElectricityReading reading) async {
    if (reading.provider.trim().isEmpty ||
        reading.units < 0 ||
        (reading.previousReading != null &&
            reading.currentReading != null &&
            reading.currentReading! < reading.previousReading!)) {
      throw const FormatException('Electricity reading is invalid.');
    }
    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      'provider': reading.provider.trim(),
      'billing_month': DateTime(
        reading.billingMonth.year,
        reading.billingMonth.month,
      ).toIso8601String(),
      'previous_reading': reading.previousReading,
      'current_reading': reading.currentReading,
      'units': reading.units,
      'actual_bill': reading.actualBill,
      'estimated_bill': reading.estimatedBill,
      'record_type': reading.isActual ? 'actual' : 'estimate',
      'notes': reading.notes,
      'created_at': now,
      'updated_at': now,
      'owner_id': database.ownerId,
    };
    if (reading.id == null) {
      return database.database.insert('electricity_readings', data);
    }
    data.remove('created_at');
    await database.database.update(
      'electricity_readings',
      data,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [reading.id, database.ownerId],
    );
    return reading.id!;
  }

  Future<List<ElectricityReading>> readings() async {
    final rows = await database.database.query(
      'electricity_readings',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'billing_month ASC',
    );
    return rows
        .map(
          (row) => ElectricityReading(
            id: row['id'] as int,
            provider: row['provider'] as String,
            billingMonth: DateTime.parse(row['billing_month'] as String),
            previousReading: (row['previous_reading'] as num?)?.toDouble(),
            currentReading: (row['current_reading'] as num?)?.toDouble(),
            units: (row['units'] as num).toDouble(),
            actualBill: (row['actual_bill'] as num?)?.toDouble(),
            estimatedBill: (row['estimated_bill'] as num?)?.toDouble(),
            isActual: row['record_type'] == 'actual',
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<int> saveAppliance(ApplianceUsage item) async {
    if (item.name.trim().isEmpty ||
        item.quantity <= 0 ||
        item.wattage <= 0 ||
        item.hoursPerDay < 0 ||
        item.hoursPerDay > 24 ||
        item.daysPerMonth <= 0 ||
        item.daysPerMonth > 31 ||
        item.tariffPerKwh < 0) {
      throw const FormatException('Appliance scenario is invalid.');
    }
    final now = DateTime.now().toIso8601String();
    return database.database.insert('appliance_scenarios', {
      'name': item.name.trim(),
      'quantity': item.quantity,
      'wattage': item.wattage,
      'hours_per_day': item.hoursPerDay,
      'days_per_month': item.daysPerMonth,
      'tariff_per_kwh': item.tariffPerKwh,
      'created_at': now,
      'updated_at': now,
      'owner_id': database.ownerId,
    });
  }

  Future<List<ApplianceUsage>> appliances() async {
    final rows = await database.database.query(
      'appliance_scenarios',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'name',
    );
    return rows
        .map(
          (row) => ApplianceUsage(
            name: row['name'] as String,
            quantity: row['quantity'] as int,
            wattage: (row['wattage'] as num).toDouble(),
            hoursPerDay: (row['hours_per_day'] as num).toDouble(),
            daysPerMonth: row['days_per_month'] as int,
            tariffPerKwh: (row['tariff_per_kwh'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<int> saveSolarSystem({
    required String name,
    required DateTime installed,
    required double systemKw,
    required int panelCount,
    required double panelWattage,
    String? inverter,
    String? battery,
    required double installationCost,
    double maintenanceCost = 0,
  }) async {
    if (name.trim().isEmpty ||
        systemKw <= 0 ||
        panelCount <= 0 ||
        panelWattage <= 0 ||
        installationCost < 0 ||
        maintenanceCost < 0) {
      throw const FormatException('Solar system values are invalid.');
    }
    final now = DateTime.now().toIso8601String();
    return database.database.insert('solar_systems', {
      'name': name.trim(),
      'installation_date': installed.toIso8601String(),
      'system_kw': systemKw,
      'panel_count': panelCount,
      'panel_wattage': panelWattage,
      'inverter': inverter,
      'battery': battery,
      'installation_cost': installationCost,
      'maintenance_cost': maintenanceCost,
      'created_at': now,
      'updated_at': now,
      'owner_id': database.ownerId,
    });
  }

  Future<List<SolarSystemProfile>> solarSystems() async {
    final rows = await database.database.query(
      'solar_systems',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'installation_date DESC',
    );
    return rows
        .map(
          (row) => SolarSystemProfile(
            id: row['id'] as int,
            name: row['name'] as String,
            installed: DateTime.parse(row['installation_date'] as String),
            systemKw: (row['system_kw'] as num).toDouble(),
            panelCount: row['panel_count'] as int,
            panelWattage: (row['panel_wattage'] as num).toDouble(),
            inverter: row['inverter'] as String?,
            battery: row['battery'] as String?,
            installationCost: (row['installation_cost'] as num).toDouble(),
            maintenanceCost: (row['maintenance_cost'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<void> saveSolarPerformance({
    required int systemId,
    required DateTime month,
    required double generation,
    double gridImport = 0,
    double gridExport = 0,
    double electricityBill = 0,
    required double estimatedSavings,
  }) async {
    if ([
      generation,
      gridImport,
      gridExport,
      electricityBill,
      estimatedSavings,
    ].any((value) => value < 0)) {
      throw const FormatException('Solar performance cannot be negative.');
    }
    await database.database.insert('solar_performance', {
      'solar_system_id': systemId,
      'month': DateTime(month.year, month.month).toIso8601String(),
      'generation_kwh': generation,
      'grid_import_kwh': gridImport,
      'grid_export_kwh': gridExport,
      'electricity_bill': electricityBill,
      'estimated_savings': estimatedSavings,
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<SolarRoiSummary?> solarRoi(int systemId) async {
    final systems = await database.database.query(
      'solar_systems',
      where: 'id = ? AND owner_id = ?',
      whereArgs: [systemId, database.ownerId],
      limit: 1,
    );
    if (systems.isEmpty) return null;
    final totals = await database.database.rawQuery(
      'SELECT COALESCE(SUM(estimated_savings), 0) saved, COUNT(*) months FROM solar_performance WHERE solar_system_id = ? AND owner_id = ?',
      [systemId, database.ownerId],
    );
    final saved = (totals.single['saved'] as num).toDouble();
    final months = (totals.single['months'] as num).toInt();
    final system = systems.single;
    return SolarRoiSummary(
      investment:
          (system['installation_cost'] as num).toDouble() +
          (system['maintenance_cost'] as num).toDouble(),
      accumulatedSavings: saved,
      monthlyAverageSavings: months == 0 ? 0 : saved / months,
    );
  }
}
