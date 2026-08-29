enum SearchResultType { transaction, person, ledgerEntry, savingsGoal, vehicle }

class SearchResult {
  const SearchResult({
    required this.type,
    required this.title,
    required this.subtitle,
    this.amount,
    this.date,
  });
  final SearchResultType type;
  final String title;
  final String subtitle;
  final double? amount;
  final DateTime? date;
}
