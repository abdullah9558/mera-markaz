import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../domain/search_result.dart';

final searchRepositoryProvider = Provider<SearchRepository>(
  (ref) => SearchRepository(ref.watch(appDatabaseProvider)),
);

class SearchRepository {
  const SearchRepository(this.database);
  final AppDatabase database;
  Future<List<SearchResult>> search(String query) async {
    final value = query.trim();
    if (value.isEmpty) return const [];
    final pattern = '%${value.toLowerCase()}%';
    final transactions = await database.database.rawQuery(
      '''SELECT t.description title, c.name subtitle, t.amount, t.occurred_at date FROM transactions t JOIN categories c ON c.id = t.category_id WHERE t.owner_id = ? AND (LOWER(t.description) LIKE ? OR LOWER(COALESCE(t.note, '')) LIKE ? OR LOWER(c.name) LIKE ?) ORDER BY t.occurred_at DESC LIMIT 50''',
      [database.ownerId, pattern, pattern, pattern],
    );
    final people = await database.database.rawQuery(
      '''SELECT p.name title, COALESCE(p.phone, 'Udhaar person') subtitle, p.created_at date FROM ledger_people p WHERE p.owner_id = ? AND (LOWER(p.name) LIKE ? OR LOWER(COALESCE(p.phone, '')) LIKE ?) ORDER BY p.name LIMIT 30''',
      [database.ownerId, pattern, pattern],
    );
    final entries = await database.database.rawQuery(
      '''SELECT t.description title, p.name subtitle, t.amount, t.occurred_at date FROM ledger_transactions t JOIN ledger_people p ON p.id = t.person_id WHERE p.owner_id = ? AND (LOWER(t.description) LIKE ? OR LOWER(COALESCE(t.notes, '')) LIKE ? OR LOWER(p.name) LIKE ?) ORDER BY t.occurred_at DESC LIMIT 50''',
      [database.ownerId, pattern, pattern, pattern],
    );
    final goals = await database.database.rawQuery(
      '''SELECT name title, COALESCE(notes, 'Savings goal') subtitle, target_amount amount, updated_at date FROM savings_goals WHERE owner_id = ? AND (LOWER(name) LIKE ? OR LOWER(COALESCE(notes, '')) LIKE ?) ORDER BY updated_at DESC LIMIT 30''',
      [database.ownerId, pattern, pattern],
    );
    final vehicles = await database.database.rawQuery(
      '''SELECT name title, COALESCE(make_model, fuel_type) subtitle FROM vehicles WHERE owner_id = ? AND (LOWER(name) LIKE ? OR LOWER(COALESCE(make_model, '')) LIKE ? OR LOWER(fuel_type) LIKE ?) ORDER BY name LIMIT 30''',
      [database.ownerId, pattern, pattern, pattern],
    );
    final results = <SearchResult>[
      ...transactions.map(
        (row) => SearchResult(
          type: SearchResultType.transaction,
          title: row['title'] as String,
          subtitle: row['subtitle'] as String,
          amount: (row['amount'] as num).toDouble(),
          date: DateTime.parse(row['date'] as String),
        ),
      ),
      ...people.map(
        (row) => SearchResult(
          type: SearchResultType.person,
          title: row['title'] as String,
          subtitle: row['subtitle'] as String,
          date: DateTime.parse(row['date'] as String),
        ),
      ),
      ...entries.map(
        (row) => SearchResult(
          type: SearchResultType.ledgerEntry,
          title: row['title'] as String,
          subtitle: 'Udhaar • ${row['subtitle']}',
          amount: (row['amount'] as num).toDouble(),
          date: DateTime.parse(row['date'] as String),
        ),
      ),
      ...goals.map(
        (row) => SearchResult(
          type: SearchResultType.savingsGoal,
          title: row['title'] as String,
          subtitle: row['subtitle'] as String,
          amount: (row['amount'] as num).toDouble(),
          date: DateTime.parse(row['date'] as String),
        ),
      ),
      ...vehicles.map(
        (row) => SearchResult(
          type: SearchResultType.vehicle,
          title: row['title'] as String,
          subtitle: row['subtitle'] as String,
        ),
      ),
    ];
    results.sort((a, b) {
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return results;
  }
}
