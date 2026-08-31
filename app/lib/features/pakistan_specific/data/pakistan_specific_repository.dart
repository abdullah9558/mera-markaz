import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/database/app_database.dart';
import '../domain/pakistan_specific_models.dart';

final pakistanSpecificRepositoryProvider = Provider(
  (ref) => PakistanSpecificRepository(ref.watch(appDatabaseProvider)),
);

class PakistanSpecificRepository {
  const PakistanSpecificRepository(this.database);
  final AppDatabase database;

  Future<int> createCommittee(
    Committee value, {
    List<String> members = const [],
  }) async {
    if (value.name.trim().isEmpty ||
        value.monthlyContribution <= 0 ||
        value.memberCount < 2 ||
        value.monthCount < 2 ||
        (value.userTurn != null &&
            (value.userTurn! < 1 || value.userTurn! > value.monthCount))) {
      throw const FormatException('Enter valid committee details.');
    }
    return database.database.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final id = await txn.insert('committees', {
        'name': value.name.trim(),
        'monthly_contribution': value.monthlyContribution,
        'member_count': value.memberCount,
        'month_count': value.monthCount,
        'start_date': value.startDate.toIso8601String(),
        'user_turn': value.userTurn,
        'reminder_day': value.reminderDay,
        'notes': value.notes,
        'created_at': now,
        'updated_at': now,
        'owner_id': database.ownerId,
      });
      for (var index = 0; index < members.length; index++) {
        if (members[index].trim().isEmpty) continue;
        await txn.insert('committee_members', {
          'committee_id': id,
          'name': members[index].trim(),
          'turn_number': index + 1,
          'is_user': value.userTurn == index + 1 ? 1 : 0,
          'owner_id': database.ownerId,
        });
      }
      for (var cycle = 1; cycle <= value.monthCount; cycle++) {
        final date = DateTime(
          value.startDate.year,
          value.startDate.month + cycle - 1,
          (value.reminderDay ?? value.startDate.day).clamp(1, 28),
        );
        await txn.insert('committee_payments', {
          'committee_id': id,
          'cycle_number': cycle,
          'due_date': date.toIso8601String(),
          'amount': value.monthlyContribution,
          'status': 'due',
          'owner_id': database.ownerId,
        });
      }
      return id;
    });
  }

  Future<List<Committee>> committees() async {
    final rows = await database.database.query(
      'committees',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'start_date DESC',
    );
    return rows
        .map(
          (row) => Committee(
            id: row['id'] as int,
            name: row['name'] as String,
            monthlyContribution: (row['monthly_contribution'] as num)
                .toDouble(),
            memberCount: row['member_count'] as int,
            monthCount: row['month_count'] as int,
            startDate: DateTime.parse(row['start_date'] as String),
            userTurn: row['user_turn'] as int?,
            reminderDay: row['reminder_day'] as int?,
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<List<CommitteePayment>> committeePayments(int id) async {
    final rows = await database.database.query(
      'committee_payments',
      where: 'committee_id = ? AND owner_id = ?',
      whereArgs: [id, database.ownerId],
      orderBy: 'cycle_number',
    );
    return rows
        .map(
          (row) => CommitteePayment(
            id: row['id'] as int,
            committeeId: id,
            cycle: row['cycle_number'] as int,
            dueDate: DateTime.parse(row['due_date'] as String),
            amount: (row['amount'] as num).toDouble(),
            status: row['status'] as String,
            paidAt: row['paid_at'] == null
                ? null
                : DateTime.parse(row['paid_at'] as String),
            receivedAt: row['received_at'] == null
                ? null
                : DateTime.parse(row['received_at'] as String),
          ),
        )
        .toList();
  }

  Future<void> markCommitteePayment(
    int id, {
    required bool paid,
    bool received = false,
  }) async {
    await database.database.update(
      'committee_payments',
      {
        'paid_at': paid ? DateTime.now().toIso8601String() : null,
        'received_at': received ? DateTime.now().toIso8601String() : null,
        'status': received
            ? 'received'
            : paid
            ? 'paid'
            : 'due',
      },
      where: 'id = ? AND owner_id = ?',
      whereArgs: [id, database.ownerId],
    );
  }

  Future<int> createHousehold(String name) {
    if (name.trim().isEmpty) {
      throw const FormatException('Household name is required.');
    }
    final now = DateTime.now().toIso8601String();
    return database.database.insert('households', {
      'name': name.trim(),
      'created_at': now,
      'updated_at': now,
      'owner_id': database.ownerId,
    });
  }

  Future<void> addMember(
    int householdId, {
    required String name,
    String? email,
    String role = 'member',
  }) async {
    if (name.trim().isEmpty) {
      throw const FormatException('Member name is required.');
    }
    await database.database.insert('household_members', {
      'household_id': householdId,
      'display_name': name.trim(),
      'email': email?.trim(),
      'role': role,
      'status': 'local',
      'created_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    });
  }

  Future<List<Household>> households() async {
    final rows = await database.database.query(
      'households',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'updated_at DESC',
    );
    final result = <Household>[];
    for (final row in rows) {
      final id = row['id'] as int;
      final memberRows = await database.database.query(
        'household_members',
        where: 'household_id = ? AND owner_id = ?',
        whereArgs: [id, database.ownerId],
      );
      result.add(
        Household(
          id: id,
          name: row['name'] as String,
          members: memberRows
              .map(
                (m) => HouseholdMember(
                  id: m['id'] as int,
                  name: m['display_name'] as String,
                  email: m['email'] as String?,
                  role: m['role'] as String,
                  status: m['status'] as String,
                ),
              )
              .toList(),
        ),
      );
    }
    return result;
  }

  Future<void> setPrivacy({
    required String recordType,
    required int recordId,
    required RecordPrivacy privacy,
    int? householdId,
  }) async {
    if (privacy == RecordPrivacy.sharedHousehold && householdId == null) {
      throw const FormatException('Choose a household before sharing.');
    }
    await database.database.insert('household_record_scopes', {
      'record_type': recordType,
      'record_id': recordId,
      'privacy_scope': privacy.name,
      'household_id': householdId,
      'updated_at': DateTime.now().toIso8601String(),
      'owner_id': database.ownerId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<RecordPrivacy> privacyFor(String recordType, int recordId) async {
    final rows = await database.database.query(
      'household_record_scopes',
      where: 'record_type = ? AND record_id = ? AND owner_id = ?',
      whereArgs: [recordType, recordId, database.ownerId],
      limit: 1,
    );
    return rows.isEmpty
        ? RecordPrivacy.onlyMe
        : RecordPrivacy.values.byName(rows.single['privacy_scope'] as String);
  }
}
