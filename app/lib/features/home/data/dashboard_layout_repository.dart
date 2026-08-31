import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';

enum DashboardSection {
  balance,
  safeToSpend,
  budget,
  udhaar,
  quickActions,
  insight,
  pakistanToday,
  upcoming,
  savings,
  recentActivity,
  tools,
}

class DashboardSectionPreference {
  const DashboardSectionPreference({
    required this.section,
    required this.position,
    required this.visible,
  });
  final DashboardSection section;
  final int position;
  final bool visible;
}

final dashboardLayoutRepositoryProvider = Provider(
  (ref) => DashboardLayoutRepository(ref.watch(appDatabaseProvider)),
);
final dashboardLayoutProvider = FutureProvider(
  (ref) => ref.watch(dashboardLayoutRepositoryProvider).load(),
);

class DashboardLayoutRepository {
  const DashboardLayoutRepository(this.database);
  final AppDatabase database;

  Future<List<DashboardSectionPreference>> load() async {
    final rows = await database.database.query(
      'dashboard_sections',
      where: 'owner_id = ?',
      whereArgs: [database.ownerId],
      orderBy: 'position ASC',
    );
    final stored = <DashboardSection, DashboardSectionPreference>{};
    for (final row in rows) {
      final section = DashboardSection.values
          .where((value) => value.name == row['section_key'])
          .firstOrNull;
      if (section != null) {
        stored[section] = DashboardSectionPreference(
          section: section,
          position: row['position'] as int,
          visible: row['visible'] == 1,
        );
      }
    }
    return [
      for (var index = 0; index < DashboardSection.values.length; index++)
        stored[DashboardSection.values[index]] ??
            DashboardSectionPreference(
              section: DashboardSection.values[index],
              position: index,
              visible: true,
            ),
    ]..sort((a, b) => a.position.compareTo(b.position));
  }

  Future<void> save(List<DashboardSectionPreference> preferences) async {
    await database.database.transaction((txn) async {
      for (var index = 0; index < preferences.length; index++) {
        final item = preferences[index];
        await txn.insert('dashboard_sections', {
          'section_key': item.section.name,
          'position': index,
          'visible': item.visible ? 1 : 0,
          'updated_at': DateTime.now().toIso8601String(),
          'owner_id': database.ownerId,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> reset() => database.database.delete(
    'dashboard_sections',
    where: 'owner_id = ?',
    whereArgs: [database.ownerId],
  );
}
