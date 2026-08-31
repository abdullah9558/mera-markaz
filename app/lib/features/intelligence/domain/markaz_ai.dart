import 'financial_intelligence.dart';
import '../../../core/pakistan_data/pakistan_data_point.dart';

class AiConversation {
  const AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
  final int id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
}

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
    if (_containsAny(normalized, const [
      'can i afford',
      'afford',
      'safe to spend',
      'kharch kar sakta',
      'خرچ کر سکتا',
      'محفوظ خرچ',
    ])) {
      final requested = _amountFrom(normalized);
      final safe = snapshot.safeToSpend;
      if (requested == null) {
        return urdu
            ? 'آپ کی موجودہ محفوظ خرچ کی رقم ${money(safe)} ہے۔ اس میں آنے والی ضروری ادائیگیاں اور ${money(snapshot.reserve)} کا محفوظ ذخیرہ منہا ہے۔'
            : 'Your current Safe to Spend amount is ${money(safe)} after upcoming essential payments and your ${money(snapshot.reserve)} reserve.';
      }
      final possible = requested <= safe;
      return urdu
          ? possible
                ? 'ریکارڈ شدہ معلومات کے مطابق ${money(requested)} موجودہ محفوظ خرچ ${money(safe)} کے اندر ہے۔ یہ رہنمائی ہے، ضمانت نہیں۔'
                : '${money(requested)} موجودہ محفوظ خرچ ${money(safe)} سے زیادہ ہے۔ پہلے آنے والی ادائیگیوں اور محفوظ ذخیرے کا جائزہ لیں۔'
          : possible
          ? '${money(requested)} is within your current Safe to Spend amount of ${money(safe)}. This is guidance, not a guarantee.'
          : '${money(requested)} exceeds your current Safe to Spend amount of ${money(safe)}. Review upcoming payments and your reserve first.';
    }
    if (_containsAny(normalized, const [
      'upcoming',
      'coming bills',
      'payments are coming',
      'due this month',
      'آنے والی',
      'واجب الادا',
    ])) {
      return urdu
          ? 'اس ماہ آنے والی ریکارڈ شدہ ضروری ادائیگیاں ${money(snapshot.upcomingCommitments)} ہیں۔'
          : 'Recorded upcoming essential payments this month total ${money(snapshot.upcomingCommitments)}.';
    }
    if (_containsAny(normalized, const [
      'income',
      'salary this month',
      'آمدنی',
      'تنخواہ',
    ])) {
      return urdu
          ? 'اس ماہ ریکارڈ شدہ آمدنی ${money(snapshot.period.income)} ہے۔'
          : 'Recorded income this month is ${money(snapshot.period.income)}.';
    }
    if (_containsAny(normalized, const [
      'spent this month',
      'spend this month',
      'spending this month',
      'monthly spending',
      'اس ماہ خرچ',
      'کتنا خرچ',
    ])) {
      return urdu
          ? 'اس ماہ ریکارڈ شدہ کل خرچ ${money(snapshot.period.expenses)} ہے۔'
          : 'Your recorded spending this month is ${money(snapshot.period.expenses)}.';
    }
    final indicator = _indicatorFor(normalized, snapshot.pakistanIndicators);
    if (indicator != null) {
      final freshness = indicator.freshness.name.replaceAllMapped(
        RegExp(r'([A-Z])'),
        (match) => ' ${match.group(1)!.toLowerCase()}',
      );
      return urdu
          ? '${_indicatorLabel(indicator.seriesKey)} کی محفوظ شدہ قدر ${indicator.value.toStringAsFixed(2)} ${indicator.unit} ہے۔ ماخذ: ${indicator.sourceName}، حالت: $freshness۔'
          : '${_indicatorLabel(indicator.seriesKey)} is ${indicator.value.toStringAsFixed(2)} ${indicator.unit}. Source: ${indicator.sourceName}; freshness: $freshness.';
    }
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
      for (final person in snapshot.ledgerPeople) {
        if (normalized.contains(person.name.toLowerCase())) {
          return urdu
              ? '${person.name} سے ${money(person.toReceive)} وصول کرنے ہیں اور ${money(person.toPay)} ادا کرنے ہیں۔'
              : '${person.name} owes you ${money(person.toReceive)}, and you owe them ${money(person.toPay)}.';
        }
      }
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
      if (_containsAny(normalized, const [
        'increase',
        'increased',
        'rose',
        'بڑھا',
        'اضافہ',
      ])) {
        final changes =
            snapshot.categories
                .map((current) {
                  final prior = snapshot.previousCategories
                      .where(
                        (item) => item.categoryName == current.categoryName,
                      )
                      .firstOrNull;
                  return (
                    category: current.categoryName,
                    change: current.amount - (prior?.amount ?? 0),
                  );
                })
                .where((item) => item.change > 0)
                .toList()
              ..sort((a, b) => b.change.compareTo(a.change));
        if (changes.isEmpty) return _insufficient(urdu);
        final top = changes.first;
        return urdu
            ? '${top.category} میں پچھلے ماہ کے مقابلے میں سب سے زیادہ اضافہ ہوا: ${money(top.change)}۔'
            : '${top.category} increased the most versus last month, by ${money(top.change)}.';
      }
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
      if (normalized.contains('goal') || normalized.contains('ہدف')) {
        if (snapshot.goals.isEmpty) return _insufficient(urdu);
        final goal = snapshot.goals.first;
        final progress = goal.targetAmount <= 0
            ? 0
            : goal.savedAmount / goal.targetAmount * 100;
        return urdu
            ? '${goal.name} کے لیے ${money(goal.savedAmount)} جمع ہیں، ہدف ${money(goal.targetAmount)} ہے (${progress.toStringAsFixed(0)}%)۔'
            : '${goal.name} has ${money(goal.savedAmount)} saved toward ${money(goal.targetAmount)} (${progress.toStringAsFixed(0)}%).';
      }
      return urdu
          ? 'اس ماہ ریکارڈ شدہ بچت ${money(snapshot.period.savings)} ہے، یعنی آمدنی کا ${(snapshot.period.savingsRate * 100).toStringAsFixed(0)}%۔'
          : 'Recorded savings this month are ${money(snapshot.period.savings)}, or ${(snapshot.period.savingsRate * 100).toStringAsFixed(0)}% of income.';
    }
    if (snapshot.period.income == 0 && snapshot.period.expenses == 0) {
      return _insufficient(urdu);
    }
    return urdu
        ? 'میں خرچ، بجٹ، ایندھن، ادھار اور بچت کے بارے میں مقامی طور پر جواب دے سکتا ہوں۔'
        : 'I can answer local questions about spending, income, budgets, affordability, upcoming payments, fuel, Udhaar, savings and Pakistan indicators.';
  }

  bool _containsAny(String value, List<String> terms) =>
      terms.any(value.contains);

  double? _amountFrom(String value) {
    final matches = RegExp(r'(\d[\d,]*(?:\.\d+)?)').allMatches(value);
    if (matches.isEmpty) return null;
    return double.tryParse(matches.last.group(1)!.replaceAll(',', ''));
  }

  PakistanDataPoint? _indicatorFor(
    String question,
    List<PakistanDataPoint> points,
  ) {
    const aliases = <String, List<String>>{
      'usd_pkr': ['usd', 'dollar', 'ڈالر'],
      'aed_pkr': ['aed', 'dirham', 'درہم'],
      'sar_pkr': ['sar', 'riyal', 'ریال'],
      'gold_24k_tola': ['gold', 'sona', 'سونا'],
      'petrol': ['petrol price', 'fuel price', 'پیٹرول'],
      'sbp_policy_rate': ['policy rate', 'شرح سود'],
      'kibor_3m': ['kibor', 'کائبور'],
      'inflation_cpi': ['inflation', 'mehngai', 'مہنگائی'],
    };
    for (final entry in aliases.entries) {
      if (entry.value.any(question.contains)) {
        for (final point in points) {
          if (point.seriesKey == entry.key) return point;
        }
      }
    }
    return null;
  }

  String _indicatorLabel(String key) => switch (key) {
    'usd_pkr' => 'USD/PKR',
    'aed_pkr' => 'AED/PKR',
    'sar_pkr' => 'SAR/PKR',
    'gold_24k_tola' => '24K gold per tola',
    'petrol' => 'Petrol',
    'sbp_policy_rate' => 'SBP policy rate',
    'kibor_3m' => '3-month KIBOR',
    'inflation_cpi' => 'Pakistan CPI inflation',
    _ => key,
  };

  String _insufficient(bool urdu) => urdu
      ? 'درست جواب کے لیے ابھی کافی مالی تاریخ موجود نہیں ہے۔'
      : 'There is not enough financial history for a reliable answer yet.';
}
