import 'financial_intelligence.dart';

class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });
  final int id;
  final String role;
  final String content;
  final DateTime createdAt;
}

abstract interface class ExternalAiGateway {
  bool get configured;
  Future<String> send({
    required String prompt,
    required Map<String, Object?> data,
  });
}

class DisabledExternalAiGateway implements ExternalAiGateway {
  const DisabledExternalAiGateway();
  @override
  bool get configured => false;
  @override
  Future<String> send({
    required String prompt,
    required Map<String, Object?> data,
  }) => throw StateError('External AI backend is not configured.');
}

class LocalMarkazQueryEngine {
  const LocalMarkazQueryEngine();

  String answer(
    String question,
    IntelligenceSnapshot snapshot, {
    required bool urdu,
  }) {
    final normalized = question.toLowerCase();
    String money(double value) => 'Rs. ${value.toStringAsFixed(0)}';
    if (normalized.contains('fuel') || normalized.contains('ایندھن')) {
      final fuel = snapshot.categories
          .where((item) => item.categoryName.toLowerCase() == 'fuel')
          .firstOrNull;
      if (fuel == null) {
        return urdu
            ? 'اس ماہ ایندھن کا کوئی خرچ ریکارڈ نہیں ہوا۔'
            : 'No fuel expenses are recorded for this month.';
      }
      return urdu
          ? 'اس ماہ ایندھن پر ${money(fuel.amount)} خرچ ہوئے۔'
          : 'You spent ${money(fuel.amount)} on fuel this month.';
    }
    if (normalized.contains('udhaar') || normalized.contains('ادھار')) {
      return urdu
          ? 'آپ نے ${money(snapshot.ledger.toReceive)} وصول کرنے ہیں اور ${money(snapshot.ledger.toPay)} ادا کرنے ہیں۔'
          : 'You have ${money(snapshot.ledger.toReceive)} to receive and ${money(snapshot.ledger.toPay)} to pay.';
    }
    if (normalized.contains('budget') || normalized.contains('بجٹ')) {
      final exceeded = snapshot.categoryBudgets
          .where((item) => item.exceeded)
          .toList();
      if (exceeded.isEmpty) {
        return urdu
            ? 'کوئی ترتیب دیا گیا زمرہ بجٹ حد سے زیادہ نہیں ہے۔'
            : 'No configured category budget is currently exceeded.';
      }
      final names = exceeded.map((item) => item.category).join(', ');
      return urdu
          ? 'یہ بجٹ حد سے زیادہ ہیں: $names۔'
          : 'These budgets are exceeded: $names.';
    }
    if (normalized.contains('biggest') ||
        normalized.contains('most') ||
        normalized.contains('سب سے')) {
      if (snapshot.categories.isEmpty) return _insufficient(urdu);
      final largest = snapshot.categories.first;
      return urdu
          ? 'اس ماہ سب سے زیادہ خرچ ${largest.categoryName} پر ہوا: ${money(largest.amount)}۔'
          : '${largest.categoryName} is your largest expense this month at ${money(largest.amount)}.';
    }
    if (normalized.contains('compare') || normalized.contains('موازنہ')) {
      final change = snapshot.period.expenseChange;
      if (change == null) return _insufficient(urdu);
      final direction = change >= 0
          ? (urdu ? 'زیادہ' : 'more')
          : (urdu ? 'کم' : 'less');
      return urdu
          ? 'آپ نے پچھلے ماہ کے مقابلے میں ${(change.abs() * 100).toStringAsFixed(0)}% $direction خرچ کیا۔'
          : 'You spent ${(change.abs() * 100).toStringAsFixed(0)}% $direction than last month.';
    }
    if (normalized.contains('save') || normalized.contains('بچ')) {
      return urdu
          ? 'اس ماہ ریکارڈ شدہ بچت ${money(snapshot.period.savings)} ہے، یعنی آمدنی کا ${(snapshot.period.savingsRate * 100).toStringAsFixed(0)}%۔'
          : 'Recorded savings this month are ${money(snapshot.period.savings)}, or ${(snapshot.period.savingsRate * 100).toStringAsFixed(0)}% of income.';
    }
    if (snapshot.period.income == 0 && snapshot.period.expenses == 0) {
      return _insufficient(urdu);
    }
    return urdu
        ? 'میں خرچ، بجٹ، ایندھن، ادھار اور بچت کے بارے میں مقامی طور پر جواب دے سکتا ہوں۔'
        : 'I can answer local questions about spending, budgets, fuel, Udhaar and savings.';
  }

  String _insufficient(bool urdu) => urdu
      ? 'درست جواب کے لیے ابھی کافی مالی تاریخ موجود نہیں ہے۔'
      : 'There is not enough financial history for a reliable answer yet.';
}
