enum AppFeature {
  incomeTracking,
  expenseTracking,
  basicDashboard,
  basicBudgets,
  basicUdhaar,
  calculators,
  basicHistory,
  localInsights,
  advancedTax,
  savedCalculations,
  pdfReports,
  csvExport,
  advancedBudgets,
  advancedAnalytics,
  recurringTransactions,
  unlimitedLedgers,
  advancedReminders,
  solarRoi,
  billHistory,
  multipleVehicles,
  backup,
  unlimitedAi,
  receiptScanning,
}

enum FeatureTier { free }

abstract final class EntitlementCatalog {
  static FeatureTier tierFor(AppFeature feature) => FeatureTier.free;
}

class Entitlements {
  const Entitlements();
  bool canUse(AppFeature feature) => true;

  int get activeLedgerLimit => 1 << 30;
  int get customCategoryBudgetLimit => 1 << 30;
  int get vehicleLimit => 1 << 30;
}
