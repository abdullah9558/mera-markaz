enum AppDestination {
  home('/'),
  addTransaction('/expenses?action=add'),
  budget('/expenses?view=budget'),
  bills('/bills'),
  udhaar('/udhaar'),
  savings('/savings'),
  pakistanLive('/pakistan-live'),
  watchlists('/watchlists'),
  netWorth('/advanced?view=net-worth'),
  zakat('/tool/zakat'),
  solar('/tool/solar');

  const AppDestination(this.location);
  final String location;
  static AppDestination? fromLocation(String? value) {
    if (value == null) return null;
    for (final destination in values) {
      if (destination.location == value) return destination;
    }
    return null;
  }
}
