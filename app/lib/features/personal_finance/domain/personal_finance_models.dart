enum FreelancerPaymentStatus { expected, received, delayed, cancelled }

class SalaryBreakdown {
  const SalaryBreakdown({
    this.id,
    required this.basicSalary,
    this.houseAllowance = 0,
    this.medicalAllowance = 0,
    this.transportAllowance = 0,
    this.bonus = 0,
    this.commission = 0,
    this.otherAllowances = 0,
    this.tax = 0,
    this.otherDeductions = 0,
    required this.receivedAt,
    this.notes,
  });
  final int? id;
  final double basicSalary,
      houseAllowance,
      medicalAllowance,
      transportAllowance,
      bonus,
      commission,
      otherAllowances,
      tax,
      otherDeductions;
  final DateTime receivedAt;
  final String? notes;
  double get gross =>
      basicSalary +
      houseAllowance +
      medicalAllowance +
      transportAllowance +
      bonus +
      commission +
      otherAllowances;
  double get deductions => tax + otherDeductions;
  double get net => (gross - deductions).clamp(0, double.infinity).toDouble();
  double get annualizedNet => net * 12;
  double get effectiveTaxRate => gross <= 0 ? 0 : tax / gross;
}

class FreelancerIncomeRecord {
  const FreelancerIncomeRecord({
    this.id,
    required this.client,
    required this.grossAmount,
    required this.currency,
    required this.exchangeRate,
    this.fees = 0,
    this.paymentMethod,
    required this.status,
    required this.expectedAt,
    this.receivedAt,
    this.notes,
  });
  final int? id;
  final String client, currency;
  final double grossAmount, exchangeRate, fees;
  final String? paymentMethod, notes;
  final FreelancerPaymentStatus status;
  final DateTime expectedAt;
  final DateTime? receivedAt;
  double get pkrGross => grossAmount * exchangeRate;
  double get pkrNet => (pkrGross - fees).clamp(0, double.infinity).toDouble();
}

enum BillStatus { unpaid, paid, overdue, cancelled }

class HouseholdBill {
  const HouseholdBill({
    this.id,
    required this.type,
    required this.provider,
    this.accountReference,
    required this.amount,
    this.issueDate,
    required this.dueDate,
    required this.status,
    this.recurringFrequency,
    this.notes,
    this.attachmentPath,
  });
  final int? id;
  final String type, provider;
  final String? accountReference, recurringFrequency, notes, attachmentPath;
  final double amount;
  final DateTime? issueDate;
  final DateTime dueDate;
  final BillStatus status;
  BillStatus statusAt(DateTime now) =>
      status == BillStatus.unpaid &&
          dueDate.isBefore(DateTime(now.year, now.month, now.day))
      ? BillStatus.overdue
      : status;
}

class EmergencyFundStatus {
  const EmergencyFundStatus({
    required this.saved,
    required this.monthlyEssential,
    required this.targetMonths,
  });
  final double saved, monthlyEssential, targetMonths;
  double get monthsCovered =>
      monthlyEssential <= 0 ? 0 : saved / monthlyEssential;
  double get targetAmount => monthlyEssential * targetMonths;
  double get progress =>
      targetAmount <= 0 ? 0 : (saved / targetAmount).clamp(0, 1);
}
