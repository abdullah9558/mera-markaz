abstract final class ReleaseConfig {
  static const bool isPlayStoreV1 = true;
  static const enabledTools = <String>{'tax', 'electricity', 'fuel', 'zakat'};
  static const disabledFeatures = <String>{
    'income',
    'notifications',
    'widgets',
    'markaz-ai',
    'pakistan-live',
    'watchlists',
    'receipts',
    'voice',
    'family',
    'committee',
    'net-worth',
    'financial-health',
    'safe-to-spend',
    'freelancer',
    'financing',
    'inflation-intelligence',
    'solar',
    'property',
    'recurring',
  };
}
