enum RecordPrivacy { onlyMe, sharedHousehold }

class Committee {
  const Committee({
    this.id,
    required this.name,
    required this.monthlyContribution,
    required this.memberCount,
    required this.monthCount,
    required this.startDate,
    this.userTurn,
    this.reminderDay,
    this.notes,
  });
  final int? id, userTurn, reminderDay;
  final String name;
  final double monthlyContribution;
  final int memberCount, monthCount;
  final DateTime startDate;
  final String? notes;
  double get totalPot => monthlyContribution * memberCount;
}

class CommitteePayment {
  const CommitteePayment({
    required this.id,
    required this.committeeId,
    required this.cycle,
    required this.dueDate,
    required this.amount,
    required this.status,
    this.paidAt,
    this.receivedAt,
  });
  final int id, committeeId, cycle;
  final DateTime dueDate;
  final double amount;
  final String status;
  final DateTime? paidAt, receivedAt;
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.members,
  });
  final int id;
  final String name;
  final List<HouseholdMember> members;
}

class HouseholdMember {
  const HouseholdMember({
    required this.id,
    required this.name,
    this.email,
    required this.role,
    required this.status,
  });
  final int id;
  final String name, role, status;
  final String? email;
}
