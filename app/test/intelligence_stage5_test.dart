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
  });
}
