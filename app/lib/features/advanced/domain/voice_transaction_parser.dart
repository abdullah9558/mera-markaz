enum VoiceEntryKind { expense, income, udhaarReceivable, udhaarPayable }

class VoiceTransactionDraft {
  const VoiceTransactionDraft({
    required this.description,
    required this.amount,
    required this.kind,
  });
  final String description;
  final double amount;
  final VoiceEntryKind kind;
  bool get isIncome => kind == VoiceEntryKind.income;
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
      r'\b(income|salary|received|receive|earned|kamai|tankhwa|تنخواہ|آمدنی|ملے|ملی)\b',
    ).hasMatch(normalized);
    final receivable = RegExp(
      r'\b(lene hain|lena hai|owe me|receivable|سے لینے|لینے ہیں)\b',
    ).hasMatch(normalized);
    final payable = RegExp(
      r'\b(dene hain|dena hai|i owe|payable|کو دینے|دینے ہیں)\b',
    ).hasMatch(normalized);
    final kind = receivable
        ? VoiceEntryKind.udhaarReceivable
        : payable
        ? VoiceEntryKind.udhaarPayable
        : income
        ? VoiceEntryKind.income
        : VoiceEntryKind.expense;
    final cleaned = normalized
        .replaceFirst(amountMatch!.group(0)!, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return VoiceTransactionDraft(
      description: cleaned.isEmpty
          ? (income ? 'Voice income' : 'Voice expense')
          : cleaned,
      amount: amount,
      kind: kind,
    );
  }
}
