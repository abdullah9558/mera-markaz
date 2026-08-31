import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/core/notifications/notification_inbox_repository.dart';
import 'package:pakpocket/core/pakistan_data/pakistan_data_point.dart';
import 'package:pakpocket/core/pakistan_data/pakistan_data_repository.dart';
import 'package:pakpocket/features/home/data/dashboard_layout_repository.dart';
import 'package:pakpocket/features/pakistan_live/data/watchlist_repository.dart';
import 'package:pakpocket/features/pakistan_live/domain/currency_converter.dart';
import 'package:pakpocket/features/pakistan_live/domain/watch_condition.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = AppDatabase();
    await database.open(databasePath: inMemoryDatabasePath);
    await database.startGuestSession('phase-one');
  });

  tearDown(() => database.close());

  test(
    'Pakistan data retains source metadata and computes staleness',
    () async {
      final repository = PakistanDataRepository(database);
      final retrieved = DateTime.utc(2026, 8, 1);
      await repository.cache(
        PakistanDataPoint(
          seriesKey: 'usd_pkr',
          value: 281.5,
          unit: 'PKR',
          sourceName: 'State Bank of Pakistan',
          sourceReference: 'https://www.sbp.org.pk/ecodata/CRates/index.asp',
          effectiveAt: retrieved,
          retrievedAt: retrieved,
          previousValue: 280,
          freshness: DataFreshness.current,
          configVersion: 'sbp-v1',
        ),
      );

      final latest = await repository.latest(
        'usd_pkr',
        now: DateTime.utc(2026, 8, 12),
      );
      expect(latest!.sourceName, 'State Bank of Pakistan');
      expect(latest.freshness, DataFreshness.stale);
      expect(latest.change, 1.5);
    },
  );

  test('notification inbox deduplicates and remains owner scoped', () async {
    final inbox = NotificationInboxRepository(database);
    expect(
      await inbox.add(
        category: 'budget',
        title: 'Budget needs attention',
        body: 'Open Mera Markaz to review it.',
        deduplicationKey: 'budget:1:80:2026-08',
      ),
      isTrue,
    );
    expect(
      await inbox.add(
        category: 'budget',
        title: 'Duplicate',
        body: 'Duplicate',
        deduplicationKey: 'budget:1:80:2026-08',
      ),
      isFalse,
    );
    expect(await inbox.unreadCount(), 1);
    await inbox.markAllRead();
    expect(await inbox.unreadCount(), 0);

    await database.startGuestSession('another-owner');
    expect(await inbox.list(), isEmpty);
  });

  test('dashboard visibility and order are owner scoped', () async {
    final repository = DashboardLayoutRepository(database);
    final original = await repository.load();
    final customized = [
      DashboardSectionPreference(
        section: DashboardSection.safeToSpend,
        position: 0,
        visible: true,
      ),
      ...original
          .where((item) => item.section != DashboardSection.safeToSpend)
          .map(
            (item) => DashboardSectionPreference(
              section: item.section,
              position: item.position + 1,
              visible: item.section != DashboardSection.tools,
            ),
          ),
    ];
    await repository.save(customized);
    final loaded = await repository.load();
    expect(loaded.first.section, DashboardSection.safeToSpend);
    expect(
      loaded
          .singleWhere((item) => item.section == DashboardSection.tools)
          .visible,
      isFalse,
    );
    await database.startGuestSession('different-layout');
    expect((await repository.load()).every((item) => item.visible), isTrue);
  });

  test('currency conversion supports foreign-to-foreign through PKR', () {
    const converter = CurrencyConverter();
    final result = converter.convert(
      amount: 100,
      from: 'USD',
      to: 'AED',
      pkrPerUnit: const {'USD': 280, 'AED': 76.25},
    );
    expect(result, closeTo(367.213, 0.001));
  });

  test(
    'Pakistan data history supports priority Gulf currency series',
    () async {
      final repository = PakistanDataRepository(database);
      for (var day = 1; day <= 3; day++) {
        final timestamp = DateTime.utc(2026, 8, day);
        await repository.cache(
          PakistanDataPoint(
            seriesKey: 'qar_pkr',
            value: 76 + day.toDouble(),
            unit: 'PKR',
            sourceName: 'State Bank of Pakistan',
            sourceReference: 'https://www.sbp.org.pk/',
            effectiveAt: timestamp,
            retrievedAt: timestamp,
            previousValue: day == 1 ? null : 75 + day.toDouble(),
            freshness: DataFreshness.current,
            configVersion: 'sbp-v1',
          ),
        );
      }

      final history = await repository.history('qar_pkr');
      expect(history.map((point) => point.value), [77, 78, 79]);
      expect(history.last.seriesKey, 'qar_pkr');
    },
  );

  test('watch condition triggers once per threshold crossing', () async {
    final repository = WatchlistRepository(database);
    final id = await repository.save(
      seriesKey: 'usd_pkr',
      comparison: WatchComparison.above,
      targetValue: 285,
      cooldownMinutes: 60,
    );
    var condition = (await repository.all()).single;
    final now = DateTime(2026, 8, 31, 12);
    expect(await repository.evaluate(condition, 286, now), isTrue);
    condition = (await repository.all()).single;
    expect(
      await repository.evaluate(
        condition,
        287,
        now.add(const Duration(minutes: 5)),
      ),
      isFalse,
    );
    condition = (await repository.all()).single;
    expect(
      await repository.evaluate(
        condition,
        280,
        now.add(const Duration(minutes: 10)),
      ),
      isFalse,
    );
    condition = (await repository.all()).single;
    expect(
      await repository.evaluate(
        condition,
        286,
        now.add(const Duration(minutes: 70)),
      ),
      isTrue,
    );
    expect(condition.id, id);
  });
}
