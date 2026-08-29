import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'urdu_phrases.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;
  static const supportedLocales = [Locale('en'), Locale('ur')];
  static const delegate = _AppLocalizationsDelegate();
  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  static const _values = <String, Map<String, String>>{
    'en': {
      'home': 'Home',
      'expenses': 'Expenses',
      'udhaar': 'Udhaar',
      'tools': 'Tools',
      'profile': 'Profile',
      'greeting': 'Assalam-o-Alaikum 👋',
      'monthExpenses': 'This month',
      'budgetRemaining': 'Monthly balance',
      'toReceive': 'To receive',
      'toPay': 'To pay',
      'quickActions': 'Quick actions',
      'popularTools': 'Popular tools',
      'addExpense': 'Add expense',
      'addUdhaar': 'Add udhaar',
      'tax': 'Salary tax',
      'electricity': 'Electricity',
      'solar': 'Solar',
      'property': 'Plot',
      'fuel': 'Fuel',
      'zakat': 'Zakat',
      'smartFinance': 'Smart finance',
      'comingSoon': 'This feature is scheduled for the next phase.',
      'settings': 'Settings',
      'language': 'Language',
      'appearance': 'Appearance',
      'system': 'System',
      'light': 'Light',
      'dark': 'Dark',
      'noTransactions': 'No transactions yet',
      'noTransactionsHint':
          'Add your first income or expense to see monthly insights.',
      'calculate': 'Calculate',
      'monthlySalary': 'Monthly salary',
      'otherAnnualIncome': 'Other annual taxable income',
      'estimatedTax': 'Estimated tax',
      'taxDisclaimer':
          'This is an estimate, not official tax advice. Confirm your circumstances with current FBR guidance or a qualified adviser.',
      'unitsOptional': 'Units consumed (or use readings below)',
      'previousReading': 'Previous meter reading',
      'currentReading': 'Current meter reading',
      'taxAdjustments': 'Estimated taxes and adjustments',
      'estimatedBill': 'Estimated bill',
      'billDisclaimer':
          'This is not an official utility bill. FCA, QTA, duties, protected status and provider-specific charges can change the final amount.',
      'monthlyUnits': 'Monthly electricity consumption',
      'roofArea': 'Available roof area',
      'solarEstimate': 'Solar estimate',
      'solarDisclaimer':
          'Output, savings and payback depend on weather, shading, installation, equipment, tariffs and location.',
      'length': 'Plot length',
      'width': 'Plot width',
      'marlaStandard': 'Marla standard',
      'pricePerMarla': 'Price per Marla (optional)',
      'plotResult': 'Plot result',
      'marlaDisclaimer':
          'Marla size varies by locality. Confirm the selected standard before relying on this result.',
      'distance': 'Distance travelled',
      'fuelConsumed': 'Fuel consumed',
      'fuelPrice': 'Fuel price',
      'fuelResult': 'Fuel result',
      'eligibleAssets': 'Total eligible assets',
      'liabilities': 'Eligible short-term liabilities',
      'nisab': 'Current Nisab threshold',
      'zakatResult': 'Zakat estimate',
      'zakatDisclaimer':
          'This uses the standard annual 2.5% calculation when net assets meet Nisab. Individual religious and financial circumstances may differ.',
    },
    'ur': {
      'home': 'ہوم',
      'expenses': 'خرچے',
      'udhaar': 'ادھار',
      'tools': 'اوزار',
      'profile': 'پروفائل',
      'greeting': 'السلام علیکم 👋',
      'monthExpenses': 'اس ماہ',
      'budgetRemaining': 'ماہانہ بیلنس',
      'toReceive': 'وصول کرنا ہے',
      'toPay': 'ادا کرنا ہے',
      'quickActions': 'فوری کام',
      'popularTools': 'مقبول اوزار',
      'addExpense': 'خرچہ شامل کریں',
      'addUdhaar': 'ادھار شامل کریں',
      'tax': 'تنخواہ ٹیکس',
      'electricity': 'بجلی کا بل',
      'solar': 'سولر',
      'property': 'پلاٹ',
      'fuel': 'ایندھن',
      'zakat': 'زکوٰۃ',
      'smartFinance': 'سمارٹ فنانس',
      'comingSoon': 'یہ سہولت اگلے مرحلے میں شامل کی جائے گی۔',
      'settings': 'ترتیبات',
      'language': 'زبان',
      'appearance': 'ظاہری شکل',
      'system': 'سسٹم',
      'light': 'روشن',
      'dark': 'تاریک',
      'noTransactions': 'ابھی کوئی لین دین نہیں',
      'noTransactionsHint':
          'ماہانہ معلومات کے لیے پہلی آمدنی یا خرچہ شامل کریں۔',
      'calculate': 'حساب کریں',
      'monthlySalary': 'ماہانہ تنخواہ',
      'otherAnnualIncome': 'دیگر سالانہ قابل ٹیکس آمدنی',
      'estimatedTax': 'تخمینی ٹیکس',
      'taxDisclaimer':
          'یہ صرف تخمینہ ہے، سرکاری ٹیکس مشورہ نہیں۔ موجودہ ایف بی آر رہنمائی یا ماہر سے تصدیق کریں۔',
      'unitsOptional': 'استعمال شدہ یونٹس (یا نیچے ریڈنگ دیں)',
      'previousReading': 'پچھلی میٹر ریڈنگ',
      'currentReading': 'موجودہ میٹر ریڈنگ',
      'taxAdjustments': 'تخمینی ٹیکس اور ایڈجسٹمنٹ',
      'estimatedBill': 'تخمینی بل',
      'billDisclaimer':
          'یہ سرکاری یوٹیلٹی بل نہیں۔ ایف سی اے، کیو ٹی اے، ڈیوٹیز اور فراہم کنندہ کے چارجز حتمی رقم بدل سکتے ہیں۔',
      'monthlyUnits': 'ماہانہ بجلی کا استعمال',
      'roofArea': 'دستیاب چھت کا رقبہ',
      'solarEstimate': 'سولر تخمینہ',
      'solarDisclaimer':
          'پیداوار، بچت اور واپسی موسم، سایہ، تنصیب، آلات، نرخ اور مقام پر منحصر ہیں۔',
      'length': 'پلاٹ کی لمبائی',
      'width': 'پلاٹ کی چوڑائی',
      'marlaStandard': 'مرلہ معیار',
      'pricePerMarla': 'فی مرلہ قیمت (اختیاری)',
      'plotResult': 'پلاٹ کا نتیجہ',
      'marlaDisclaimer':
          'مرلہ کا سائز علاقے کے لحاظ سے مختلف ہے۔ نتیجے سے پہلے منتخب معیار کی تصدیق کریں۔',
      'distance': 'طے شدہ فاصلہ',
      'fuelConsumed': 'استعمال شدہ ایندھن',
      'fuelPrice': 'ایندھن کی قیمت',
      'fuelResult': 'ایندھن کا نتیجہ',
      'eligibleAssets': 'کل قابل زکوٰۃ اثاثے',
      'liabilities': 'قابل کٹوتی قلیل مدتی واجبات',
      'nisab': 'موجودہ نصاب',
      'zakatResult': 'زکوٰۃ کا تخمینہ',
      'zakatDisclaimer':
          'نصاب پورا ہونے پر یہ معیاری سالانہ 2.5 فیصد حساب استعمال کرتا ہے۔ انفرادی حالات مختلف ہو سکتے ہیں۔',
    },
  };
  String text(String key) =>
      _values[locale.languageCode]?[key] ?? _values['en']![key] ?? key;
  String phrase(String english) =>
      locale.languageCode == 'ur' ? (urduPhrases[english] ?? english) : english;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) => ['en', 'ur'].contains(locale.languageCode);
  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));
  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension LocalizationContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
