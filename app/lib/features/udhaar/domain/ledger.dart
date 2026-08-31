enum LedgerDirection { gave, took }

enum LedgerStatus { pending, partiallyPaid, paid, overdue }

class LedgerPerson {
  const LedgerPerson({
    required this.id,
    required this.name,
    this.phone,
    required this.toReceive,
    required this.toPay,
  });
  final int id;
  final String name;
  final String? phone;
  final double toReceive;
  final double toPay;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.personId,
    required this.direction,
    required this.amount,
    required this.paidAmount,
    required this.occurredAt,
    this.dueAt,
    required this.description,
    this.notes,
  });
  final int id;
  final int personId;
  final LedgerDirection direction;
  final double amount;
  final double paidAmount;
  final DateTime occurredAt;
  final DateTime? dueAt;
  final String description;
  final String? notes;
  double get remaining => (amount - paidAmount).clamp(0, double.infinity);
  LedgerStatus statusAt(DateTime now) {
    if (remaining <= 0) return LedgerStatus.paid;
    if (paidAmount > 0) return LedgerStatus.partiallyPaid;
    if (dueAt != null &&
        dueAt!.isBefore(DateTime(now.year, now.month, now.day))) {
      return LedgerStatus.overdue;
    }
    return LedgerStatus.pending;
  }
}

class LedgerSummary {
  const LedgerSummary({required this.toReceive, required this.toPay});
  final double toReceive;
  final double toPay;
}

class LedgerPayment {
  const LedgerPayment({
    required this.id,
    required this.amount,
    required this.paidAt,
    this.notes,
  });
  final int id;
  final double amount;
  final DateTime paidAt;
  final String? notes;
}

class LedgerInstallment {
  const LedgerInstallment({
    required this.id,
    required this.number,
    required this.amount,
    required this.dueAt,
    required this.status,
    this.paidAt,
  });
  final int id, number;
  final double amount;
  final DateTime dueAt;
  final String status;
  final DateTime? paidAt;
}
