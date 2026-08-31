import 'package:flutter_test/flutter_test.dart';
import 'package:pakpocket/core/database/app_database.dart';
import 'package:pakpocket/features/analytics/domain/financial_analytics.dart';
import 'package:pakpocket/features/expenses/domain/budget_analytics.dart';
import 'package:pakpocket/features/intelligence/data/ai_conversation_repository.dart';
import 'package:pakpocket/features/intelligence/data/intelligence_provider.dart';
import 'package:pakpocket/features/intelligence/domain/financial_intelligence.dart';
import 'package:pakpocket/features/intelligence/domain/markaz_ai.dart';
import 'package:pakpocket/features/savings/domain/savings_goal.dart';
import 'package:pakpocket/features/udhaar/domain/ledger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pakpocket/core/pakistan_data/pakistan_data_point.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  IntelligenceSnapshot snapshot({
    double income = 100000,
    double expenses = 70000,
    double previousExpenses = 70000,
    LedgerSummary ledger = const LedgerSummary(toReceive: 0, toPay: 0),
    List<CategorySpending> categories = const [],
    List<CategoryBudgetStatus> budgets = const [],
    List<SavingsGoal> goals = const [],
    double safeToSpend = 0,
    double upcomingCommitments = 0,
    double reserve = 0,
    List<PakistanDataPoint> indicators = const [],
    List<LedgerPerson> ledgerPeople = const [],
    List<CategorySpending> previousCategories = const [],
  }) => IntelligenceSnapshot(
    period: FinancialPeriodSummary(
      start: DateTime(2026, 8),
      end: DateTime(2026, 9),
      income: income,
      expenses: expenses,
      previousIncome: income,
      previousExpenses: previousExpenses,
    ),
    categories: categories,
    categoryBudgets: budgets,
    ledger: ledger,
    goals: goals,
    safeToSpend: safeToSpend,
    upcomingCommitments: upcomingCommitments,
    reserve: reserve,
    pakistanIndicators: indicators,
    ledgerPeople: ledgerPeople,
    previousCategories: previousCategories,
  );

  test('Markaz Score reaches 100 only from explainable healthy factors', () {
    final input = snapshot(
      budgets: const [
        CategoryBudgetStatus(
          budgetId: 1,
          categoryId: 1,
          category: 'Food',
          budget: 20000,
          spent: 15000,
        ),
      ],
      goals: [
        SavingsGoal(
          id: 1,
          name: 'Emergency Fund',
          targetAmount: 300000,
          savedAmount: 210000,
          status: SavingsGoalStatus.active,
          createdAt: DateTime(2026, 1),
          updatedAt: DateTime(2026, 8),
        ),
      ],
    );
    final score = const FinancialIntelligenceEngine().score(input);
    expect(score.value, 100);
    expect(score.factors.fold<int>(0, (sum, item) => sum + item.maximum), 100);
    expect(score.improvements, isEmpty);
  });

  test('score exposes weaknesses and stays in the 0 to 100 range', () {
    final score = const FinancialIntelligenceEngine().score(
      snapshot(
        income: 50000,
        expenses: 80000,
        previousExpenses: 30000,
        ledger: const LedgerSummary(toReceive: 0, toPay: 60000),
        budgets: const [
          CategoryBudgetStatus(
            budgetId: 1,
            categoryId: 1,
            category: 'Shopping',
            budget: 10000,
            spent: 25000,
          ),
        ],
      ),
    );
    expect(score.value, inInclusiveRange(0, 100));
    expect(score.improvements, isNotEmpty);
    expect(score.factors.any((item) => !item.positive), isTrue);
  });

  test('insights do not fabricate data when history is empty', () {
    final values = const FinancialIntelligenceEngine().insights(
      snapshot(income: 0, expenses: 0, previousExpenses: 0),
    );
    expect(values, isEmpty);
    final score = const FinancialIntelligenceEngine().score(
      snapshot(income: 0, expenses: 0, previousExpenses: 0),
    );
    expect(score.status, 'Not enough data');
    expect(score.factors, isEmpty);
  });

  test('local query engine answers deterministic fuel totals', () {
    final answer = const LocalMarkazQueryEngine().answer(
      'How much did I spend on fuel?',
      snapshot(
        categories: const [
          CategorySpending(categoryId: 1, categoryName: 'Fuel', amount: 12500),
        ],
      ),
      urdu: false,
    );
    expect(answer, contains('Rs. 12500'));
  });

  test('local query engine explains affordability without AI', () {
    final answer = const LocalMarkazQueryEngine().answer(
      'Can I afford Rs. 50,000 this month?',
      snapshot(safeToSpend: 42000, upcomingCommitments: 18000, reserve: 10000),
      urdu: false,
    );
    expect(answer, contains('exceeds'));
    expect(answer, contains('Rs. 42000'));
  });

  test('local engine answers person-specific Udhaar without cloud sharing', () {
    final answer = const LocalMarkazQueryEngine().answer(
      'How much does Ahmed owe me in Udhaar?',
      snapshot(
        ledgerPeople: const [
          LedgerPerson(id: 1, name: 'Ahmed', toReceive: 25000, toPay: 0),
        ],
      ),
      urdu: false,
    );
    expect(answer, contains('Ahmed'));
    expect(answer, contains('Rs. 25000'));
    expect(safeAiSummary(snapshot()).keys, isNot(contains('ledgerPeople')));
  });

  test('local engine compares category increases deterministically', () {
    final answer = const LocalMarkazQueryEngine().answer(
      'Which category increased most?',
      snapshot(
        categories: const [
          CategorySpending(categoryId: 1, categoryName: 'Food', amount: 30000),
          CategorySpending(categoryId: 2, categoryName: 'Fuel', amount: 15000),
        ],
        previousCategories: const [
          CategorySpending(categoryId: 1, categoryName: 'Food', amount: 10000),
          CategorySpending(categoryId: 2, categoryName: 'Fuel', amount: 12000),
        ],
      ),
      urdu: false,
    );
    expect(answer, contains('Food'));
    expect(answer, contains('Rs. 20000'));
  });

  test('local Pakistan answer includes source and freshness', () {
    final answer = const LocalMarkazQueryEngine().answer(
      'What is the USD rate?',
      snapshot(
        indicators: [
          PakistanDataPoint(
            seriesKey: 'usd_pkr',
            value: 281.5,
            unit: 'PKR',
            sourceName: 'State Bank of Pakistan',
            sourceReference: 'SBP',
            effectiveAt: DateTime(2026, 8, 30),
            retrievedAt: DateTime(2026, 8, 30),
            freshness: DataFreshness.cached,
            configVersion: 'test',
          ),
        ],
      ),
      urdu: false,
    );
    expect(answer, contains('281.50'));
    expect(answer, contains('State Bank of Pakistan'));
    expect(answer, contains('cached'));
  });

  test('safe online summary includes aggregates but no raw indicator URLs', () {
    final summary = safeAiSummary(
      snapshot(safeToSpend: 25000, upcomingCommitments: 10000),
    );
    expect(summary['safeToSpend'], 25000);
    expect(summary['upcomingCommitments'], 10000);
    expect('$summary', isNot(contains('sourceReference')));
  });

  test('online AI summary contains aggregates and excludes identity data', () {
    final summary = safeAiSummary(
      snapshot(
        categories: const [
          CategorySpending(categoryId: 1, categoryName: 'Fuel', amount: 12500),
        ],
      ),
    );
    expect(summary['currency'], 'PKR');
    expect(summary['monthlyIncome'], 100000);
    expect(summary['spendingByCategory'], isNotEmpty);
    expect(
      summary.keys,
      isNot(containsAll(['email', 'userId', 'phone', 'transactions', 'notes'])),
    );
  });

  group('AI privacy and conversation persistence', () {
    late AppDatabase database;
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      database = AppDatabase();
      await database.open(databasePath: inMemoryDatabasePath);
      await database.startGuestSession('intelligence-stage-5');
    });
    tearDown(() => database.close());

    test('external AI consent defaults off and persists explicitly', () async {
      final consent = AiPrivacyConsent();
      expect(await consent.granted(), isFalse);
      await consent.setGranted(true);
      expect(await consent.granted(), isTrue);
      expect(const DisabledExternalAiGateway().configured, isFalse);
    });

    test('local conversation messages remain owner scoped', () async {
      final repository = AiConversationRepository(database);
      final id = await repository.currentConversation();
      await repository.addMessage(id, 'user', 'Check my budget');
      await repository.addMessage(id, 'assistant', 'No budget is exceeded.');
      final messages = await repository.messages(id);
      expect(messages.map((item) => item.role), ['user', 'assistant']);
    });

    test(
      'multiple conversations can be created, titled, searched and deleted',
      () async {
        final repository = AiConversationRepository(database);
        final first = await repository.createConversation();
        await repository.addMessage(first, 'user', 'How much did I spend?');
        await repository.titleFromFirstMessage(first, 'How much did I spend?');
        final second = await repository.createConversation(
          title: 'Budget plan',
        );

        expect(await repository.conversations(), hasLength(2));
        expect(
          (await repository.conversations(query: 'spend')).single.id,
          first,
        );
        expect(
          (await repository.conversations(query: 'budget')).single.id,
          second,
        );

        await repository.renameConversation(second, 'Savings plan');
        expect(
          (await repository.conversations(query: 'savings')).single.id,
          second,
        );

        await repository.deleteConversation(first);
        expect(await repository.conversations(), hasLength(1));
        expect(await repository.messages(first), isEmpty);
      },
    );
  });
}
