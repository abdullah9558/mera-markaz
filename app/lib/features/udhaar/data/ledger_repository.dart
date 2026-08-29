import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../domain/ledger.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(ref.watch(appDatabaseProvider)),
);

class LedgerRepository {
  const LedgerRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  Future<List<LedgerPerson>> people() async {
    final rows = await _appDatabase.database.rawQuery(
      '''
      SELECT p.id, p.name, p.phone,
      COALESCE(SUM(CASE WHEN t.direction = 'gave' THEN t.amount - t.paid_amount ELSE 0 END), 0) to_receive,
      COALESCE(SUM(CASE WHEN t.direction = 'took' THEN t.amount - t.paid_amount ELSE 0 END), 0) to_pay
      FROM ledger_people p LEFT JOIN ledger_transactions t ON t.person_id = p.id
      WHERE p.owner_id = ?
      GROUP BY p.id ORDER BY p.name
    ''',
      [_appDatabase.ownerId],
    );
    return rows
        .map(
          (row) => LedgerPerson(
            id: row['id'] as int,
            name: row['name'] as String,
            phone: row['phone'] as String?,
            toReceive: (row['to_receive'] as num).toDouble(),
            toPay: (row['to_pay'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<LedgerSummary> summary() async {
    final values = await people();
    return LedgerSummary(
      toReceive: values.fold(0, (sum, p) => sum + p.toReceive),
      toPay: values.fold(0, (sum, p) => sum + p.toPay),
    );
  }

  Future<int> create({
    required String name,
    String? phone,
    required LedgerDirection direction,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    required String description,
    String? notes,
  }) async {
    if (name.trim().isEmpty || description.trim().isEmpty) {
      throw const FormatException('Name and description are required.');
    }
    if (amount <= 0) {
      throw const FormatException('Amount must be greater than zero.');
    }
    return _appDatabase.database.transaction((txn) async {
      final personId = await txn.insert('ledger_people', {
        'name': name.trim(),
        'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
        'created_at': DateTime.now().toIso8601String(),
        'owner_id': _appDatabase.ownerId,
      });
      await txn.insert('ledger_transactions', {
        'person_id': personId,
        'direction': direction.name,
        'amount': amount,
        'paid_amount': 0,
        'occurred_at': date.toIso8601String(),
        'due_at': dueDate?.toIso8601String(),
        'description': description.trim(),
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
        'status': LedgerStatus.pending.name,
        'owner_id': _appDatabase.ownerId,
      });
      return personId;
    });
  }

  Future<void> addEntry({
    required int personId,
    required LedgerDirection direction,
    required double amount,
    required DateTime date,
    DateTime? dueDate,
    required String description,
    String? notes,
  }) async {
    if (amount <= 0 || description.trim().isEmpty) {
      throw const FormatException('Enter a positive amount and description.');
    }
    await _appDatabase.database.insert('ledger_transactions', {
      'person_id': personId,
      'direction': direction.name,
      'amount': amount,
      'paid_amount': 0,
      'occurred_at': date.toIso8601String(),
      'due_at': dueDate?.toIso8601String(),
      'description': description.trim(),
      'notes': notes,
      'status': LedgerStatus.pending.name,
      'owner_id': _appDatabase.ownerId,
    });
  }

  Future<List<LedgerEntry>> entries(int personId) async {
    final rows = await _appDatabase.database.query(
      'ledger_transactions',
      where:
          'person_id = ? AND person_id IN (SELECT id FROM ledger_people WHERE owner_id = ?)',
      whereArgs: [personId, _appDatabase.ownerId],
      orderBy: 'occurred_at DESC, id DESC',
    );
    return rows
        .map(
          (row) => LedgerEntry(
            id: row['id'] as int,
            personId: personId,
            direction: LedgerDirection.values.byName(
              row['direction'] as String,
            ),
            amount: (row['amount'] as num).toDouble(),
            paidAmount: (row['paid_amount'] as num).toDouble(),
            occurredAt: DateTime.parse(row['occurred_at'] as String),
            dueAt: row['due_at'] == null
                ? null
                : DateTime.parse(row['due_at'] as String),
            description: row['description'] as String? ?? '',
            notes: row['notes'] as String?,
          ),
        )
        .toList();
  }

  Future<void> recordPayment(LedgerEntry entry, double payment) async {
    if (payment <= 0) {
      throw const FormatException('Payment must be greater than zero.');
    }
    if (payment > entry.remaining) {
      throw const FormatException(
        'Payment cannot exceed the remaining balance.',
      );
    }
    final paid = entry.paidAmount + payment;
    final status = paid >= entry.amount
        ? LedgerStatus.paid
        : LedgerStatus.partiallyPaid;
    await _appDatabase.database.update(
      'ledger_transactions',
      {'paid_amount': paid, 'status': status.name},
      where:
          'id = ? AND person_id IN (SELECT id FROM ledger_people WHERE owner_id = ?)',
      whereArgs: [entry.id, _appDatabase.ownerId],
    );
  }

  Future<void> deletePerson(int id) => _appDatabase.database.delete(
    'ledger_people',
    where: 'id = ? AND owner_id = ?',
    whereArgs: [id, _appDatabase.ownerId],
  );
}
