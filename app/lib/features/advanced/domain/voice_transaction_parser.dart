class VoiceTransactionDraft {
  const VoiceTransactionDraft({
    required this.description,
    required this.amount,
    required this.isIncome,
  });
  final String description;
  final double amount;
  final bool isIncome;
}

abstract final class VoiceTransactionParser {
  static VoiceTransactionDraft? parse(String phrase) {
    final normalized = phrase.toLowerCase().replaceAll(',', ' ').trim();
    final amountMatch = RegExp(r'\b(\d+(?:\.\d+)?)\b').firstMatch(normalized);
    final amount = amountMatch == null
        ? null
        : double.tryParse(amountMatch.group(1)!);
    if (amount == null || amount <= 0) return null;
    final income = RegExp(
      r'\b(income|salary|received|earned|آمدنی|تنخواہ|ملے)\b',
    ).hasMatch(normalized);
    final cleaned = normalized
        .replaceFirst(amountMatch!.group(0)!, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return VoiceTransactionDraft(
      description: cleaned.isEmpty
          ? (income ? 'Voice income' : 'Voice expense')
          : cleaned,
      amount: amount,
      isIncome: income,
    );
  }
}
