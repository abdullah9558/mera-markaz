import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../expenses/data/module_finance_repository.dart';

final vehicleRepositoryProvider = Provider<VehicleRepository>(
  (ref) => VehicleRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(moduleFinanceRepositoryProvider),
  ),
);

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    this.makeModel,
    required this.fuelType,
    required this.odometer,
  });
  final int id;
  final String name;
  final String? makeModel;
  final String fuelType;
  final double odometer;
}

class FuelEntry {
  const FuelEntry({
    required this.id,
    required this.liters,
    required this.cost,
    required this.odometer,
    required this.filledAt,
  });
  final int id;
  final double liters;
  final double cost;
  final double odometer;
  final DateTime filledAt;
}

class MaintenanceEntry {
  const MaintenanceEntry({
    required this.id,
    required this.kind,
    required this.cost,
    required this.servicedAt,
    this.odometer,
    this.nextDueAt,
    this.nextDueOdometer,
    this.notes,
  });
  final int id;
  final String kind;
  final double cost;
  final DateTime servicedAt;
  final double? odometer;
  final DateTime? nextDueAt;
  final double? nextDueOdometer;
  final String? notes;
}

class VehicleAnalytics {
  const VehicleAnalytics({
    required this.totalFuelCost,
    required this.totalLiters,
    required this.averageKmPerLiter,
    required this.costPerKm,
    required this.maintenanceCost,
  });
  final double totalFuelCost;
  final double totalLiters;
  final double averageKmPerLiter;
  final double costPerKm;
  final double maintenanceCost;
}

class VehicleRepository {
  const VehicleRepository(this._database, this._finance);
  final AppDatabase _database;
  final ModuleFinanceRepository _finance;

  Future<List<Vehicle>> vehicles() async {
    final rows = await _database.database.query(
      'vehicles',
      where: 'owner_id = ?',
      whereArgs: [_database.ownerId],
      orderBy: 'name',
    );
    return rows
        .map(
          (row) => Vehicle(
            id: row['id'] as int,
            name: row['name'] as String,
            makeModel: row['make_model'] as String?,
            fuelType: row['fuel_type'] as String,
            odometer: (row['odometer'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<int> saveVehicle({
    int? id,
    required String name,
    String? makeModel,
    required String fuelType,
    required double odometer,
  }) async {
    if (name.trim().isEmpty || odometer < 0) {
      throw const FormatException('Enter a vehicle name and valid odometer.');
    }
    final values = {
      'name': name.trim(),
      'make_model': makeModel?.trim().isEmpty == true
          ? null
          : makeModel?.trim(),
      'fuel_type': fuelType,
      'odometer': odometer,
      'owner_id': _database.ownerId,
    };
    if (id == null) return _database.database.insert('vehicles', values);
    await _database.database.update(
      'vehicles',
      values,
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, _database.ownerId],
    );
    return id;
  }

  Future<void> deleteVehicle(int id) =>
      _database.database.transaction((txn) async {
        final fuelRows = await txn.query(
          'fuel_entries',
          columns: ['id'],
          where: 'vehicle_id = ? AND owner_id = ?',
          whereArgs: [id, _database.ownerId],
        );
        for (final row in fuelRows) {
          await txn.delete(
            'transactions',
            where: 'owner_id = ? AND source = ? AND source_record_id = ?',
            whereArgs: [_database.ownerId, 'fuel', '${row['id']}'],
          );
        }
        await txn.delete(
          'vehicles',
          where: 'id = ? AND owner_id = ?',
          whereArgs: [id, _database.ownerId],
        );
      });

  Future<List<FuelEntry>> fuelHistory(int vehicleId) async {
    final rows = await _database.database.query(
      'fuel_entries',
      where: 'vehicle_id = ? AND owner_id = ?',
      whereArgs: [vehicleId, _database.ownerId],
      orderBy: 'filled_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => FuelEntry(
            id: row['id'] as int,
            liters: (row['liters'] as num).toDouble(),
            cost: (row['cost'] as num).toDouble(),
            odometer: (row['odometer'] as num).toDouble(),
            filledAt: DateTime.parse(row['filled_at'] as String),
          ),
        )
        .toList();
  }

  Future<LinkedRecordResult> addFuel({
    required int vehicleId,
    required double liters,
    required double cost,
    required double odometer,
    required DateTime filledAt,
  }) async {
    final result = await _finance.recordFuelExpense(
      vehicleId: vehicleId,
      liters: liters,
      cost: cost,
      odometer: odometer,
      occurredAt: filledAt,
    );
    await _database.database.rawUpdate(
      'UPDATE vehicles SET odometer = MAX(odometer, ?) WHERE id = ? AND owner_id = ?',
      [odometer, vehicleId, _database.ownerId],
    );
    return result;
  }

  Future<List<MaintenanceEntry>> maintenance(int vehicleId) async {
    final rows = await _database.database.query(
      'vehicle_maintenance',
      where: 'vehicle_id = ? AND owner_id = ?',
      whereArgs: [vehicleId, _database.ownerId],
      orderBy: 'serviced_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => MaintenanceEntry(
            id: row['id'] as int,
            kind: row['kind'] as String,
            cost: (row['cost'] as num).toDouble(),
            odometer: (row['odometer'] as num?)?.toDouble(),
            servicedAt: DateTime.parse(row['serviced_at'] as String),
            nextDueAt: row['next_due_at'] == null
                ? null
                : DateTime.parse(row['next_due_at'] as String),
            nextDueOdometer: (row['next_due_odometer'] as num?)?.toDouble(),
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<int> addMaintenance({
    required int vehicleId,
    required String kind,
    required double cost,
    double? odometer,
    DateTime? nextDueAt,
    double? nextDueOdometer,
    String? notes,
  }) async {
    if (kind.trim().isEmpty || cost < 0) {
      throw const FormatException('Enter a maintenance type and valid cost.');
    }
    return _database.database.transaction((txn) async {
      final now = DateTime.now();
      final id = await txn.insert('vehicle_maintenance', {
        'vehicle_id': vehicleId,
        'kind': kind.trim(),
        'cost': cost,
        'odometer': odometer,
        'serviced_at': now.toIso8601String(),
        'next_due_at': nextDueAt?.toIso8601String(),
        'next_due_odometer': nextDueOdometer,
        'notes': notes?.trim(),
        'owner_id': _database.ownerId,
      });
      if (nextDueAt != null) {
        await txn.insert('reminders', {
          'kind': 'vehicle_maintenance',
          'reference_type': 'vehicle_maintenance',
          'reference_id': '$id',
          'title': '${kind.trim()} due',
          'scheduled_at': nextDueAt.toIso8601String(),
          'status': 'pending',
          'created_at': now.toIso8601String(),
          'owner_id': _database.ownerId,
        });
      }
      return id;
    });
  }

  Future<VehicleAnalytics> analytics(int vehicleId) async {
    final fuel = await fuelHistory(vehicleId);
    final service = await maintenance(vehicleId);
    final totalCost = fuel.fold<double>(0, (sum, item) => sum + item.cost);
    final totalLiters = fuel.fold<double>(0, (sum, item) => sum + item.liters);
    final ordered = [...fuel]..sort((a, b) => a.odometer.compareTo(b.odometer));
    final distance = ordered.length < 2
        ? 0.0
        : ordered.last.odometer - ordered.first.odometer;
    return VehicleAnalytics(
      totalFuelCost: totalCost,
      totalLiters: totalLiters,
      averageKmPerLiter: totalLiters <= 0 ? 0 : distance / totalLiters,
      costPerKm: distance <= 0 ? 0 : totalCost / distance,
      maintenanceCost: service.fold(0, (sum, item) => sum + item.cost),
    );
  }
}
