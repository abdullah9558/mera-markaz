import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pakistan_data_point.dart';
import 'pakistan_data_repository.dart';

final pakistanDataServiceProvider = Provider(
  (ref) => PakistanDataService(ref.watch(pakistanDataRepositoryProvider)),
);

class PakistanDataService {
  PakistanDataService(this.repository, {HttpClient? client})
    : _client = client ?? HttpClient();
  final PakistanDataRepository repository;
  final HttpClient _client;
  static const endpoint = String.fromEnvironment(
    'PAKISTAN_DATA_ENDPOINT',
    defaultValue: 'https://mera-markaz.vercel.app/api/pakistan-data',
  );
  static final Uri _exchangeEndpoint = Uri.parse(
    'https://open.er-api.com/v6/latest/USD',
  );
  static final Uri _goldEndpoint = Uri.parse(
    'https://api.gold-api.com/price/XAU',
  );
  static final Uri _silverEndpoint = Uri.parse(
    'https://api.gold-api.com/price/XAG',
  );
  static final Uri _psoFuelEndpoint = Uri.parse(
    'https://psopk.com/en/fuels/fuel-prices',
  );
  static final Uri _economyEndpoint = Uri.parse(
    'https://tradingeconomics.com/pakistan/indicators',
  );
  static const _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 15) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';
  static const _gramsPerTola = 11.6638038;
  static const _gramsPerTroyOunce = 31.1034768;
  static const _exchangeCurrencies = <String>[
    'USD',
    'GBP',
    'EUR',
    'AED',
    'SAR',
    'CAD',
    'AUD',
    'QAR',
    'KWD',
    'OMR',
  ];

  Future<List<PakistanDataPoint>> dashboard() async {
    const keys = [
      'usd_pkr',
      'gbp_pkr',
      'eur_pkr',
      'aed_pkr',
      'sar_pkr',
      'cad_pkr',
      'aud_pkr',
      'qar_pkr',
      'kwd_pkr',
      'omr_pkr',
      'gold_24k_tola',
      'silver_tola',
      'petrol',
      'diesel',
      'sbp_policy_rate',
      'kibor_3m',
      'inflation_cpi',
      'forex_reserves',
    ];
    final values = await Future.wait(keys.map(repository.latest));
    return values.whereType<PakistanDataPoint>().toList();
  }

  Future<int> refresh() async {
    if (endpoint.isNotEmpty) {
      try {
        return await _refreshFromAdapter();
      } catch (_) {
        // The public adapter may be unavailable or deployment-protected. The
        // keyless currency feed keeps Pakistan Live useful in that situation.
      }
    }
    return _refreshDirectFeeds();
  }

  Future<int> _refreshFromAdapter() async {
    final uri = Uri.tryParse(endpoint);
    if (uri == null || uri.scheme != 'https') {
      throw const FormatException('Pakistan data endpoint must use HTTPS.');
    }
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Pakistan data refresh failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(await utf8.decoder.bind(response).join());
    if (decoded is! Map || decoded['data'] is! List) {
      throw const FormatException('Pakistan data response is invalid.');
    }
    return _storePayload(decoded['data'] as List);
  }

  Future<int> _refreshDirectFeeds() async {
    final retrievedAt = DateTime.now().toUtc();
    final payload = <Map<String, Object?>>[];

    final exchangeFuture = _exchangePayload(retrievedAt);
    final fuelFuture = _safePayload(() => _fuelPayload(retrievedAt));
    final economyFuture = _safePayload(() => _economyPayload(retrievedAt));

    double? pkrPerUsd;
    try {
      final exchangeResult = await exchangeFuture;
      payload.addAll(exchangeResult.items);
      pkrPerUsd = exchangeResult.pkrPerUsd;
    } catch (_) {
      // Keep refreshing Fuel and Economy even if exchange rates fail.
    }

    final metalsFuture = pkrPerUsd != null
        ? _safePayload(
            () => _metalPayload(
              pkrPerUsd: pkrPerUsd!,
              retrievedAt: retrievedAt,
            ),
          )
        : Future.value(const <Map<String, Object?>>[]);

    final extraPayloads = await Future.wait([
      metalsFuture,
      fuelFuture,
      economyFuture,
    ]);
    for (final batch in extraPayloads) {
      payload.addAll(batch);
    }

    if (payload.isEmpty) {
      throw const HttpException('All Pakistan Live feeds are currently unreachable.');
    }
    return _storePayload(payload);
  }

  Future<List<Map<String, Object?>>> _safePayload(
    Future<List<Map<String, Object?>>> Function() loader,
  ) async {
    try {
      return await loader();
    } catch (_) {
      return const [];
    }
  }

  Future<({double pkrPerUsd, List<Map<String, Object?>> items})>
  _exchangePayload(DateTime retrievedAt) async {
    final request = await _client.getUrl(_exchangeEndpoint);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Exchange-rate refresh failed (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(await utf8.decoder.bind(response).join());
    if (decoded is! Map || decoded['rates'] is! Map) {
      throw const FormatException('Exchange-rate response is invalid.');
    }
    final rates = Map<String, Object?>.from(decoded['rates'] as Map);
    final pkr = rates['PKR'];
    if (pkr is! num || pkr <= 0) {
      throw const FormatException('PKR rate is unavailable.');
    }
    final updateSeconds = decoded['time_last_update_unix'];
    final effectiveAt = updateSeconds is num
        ? DateTime.fromMillisecondsSinceEpoch(
            updateSeconds.toInt() * 1000,
            isUtc: true,
          )
        : retrievedAt;
    final items = <Map<String, Object?>>[];
    for (final currency in _exchangeCurrencies) {
      final currencyRate = rates[currency];
      if (currencyRate is! num || currencyRate <= 0) continue;
      items.add({
        'seriesKey': '${currency.toLowerCase()}_pkr',
        'value': pkr.toDouble() / currencyRate.toDouble(),
        'unit': 'PKR',
        'sourceName': 'ExchangeRate-API open feed',
        'sourceReference': _exchangeEndpoint.toString(),
        'effectiveAt': effectiveAt.toIso8601String(),
        'retrievedAt': retrievedAt.toIso8601String(),
        'configVersion': 'exchange-open-v1',
      });
    }
    return (pkrPerUsd: pkr.toDouble(), items: items);
  }

  Future<List<Map<String, Object?>>> _metalPayload({
    required double pkrPerUsd,
    required DateTime retrievedAt,
  }) async {
    final entries = <({String seriesKey, Uri uri})>[
      (seriesKey: 'gold_24k_tola', uri: _goldEndpoint),
      (seriesKey: 'silver_tola', uri: _silverEndpoint),
    ];
    final results = await Future.wait(
      entries.map((entry) async {
        try {
          final response = await _readJson(entry.uri);
          final price = response['price'];
          if (price is! num || price <= 0) return null;
          final effectiveAt =
              DateTime.tryParse('${response['updatedAt']}') ?? retrievedAt;
          final perTolaPkr =
              price.toDouble() *
              (_gramsPerTola / _gramsPerTroyOunce) *
              pkrPerUsd;
          return <String, Object?>{
            'seriesKey': entry.seriesKey,
            'value': perTolaPkr,
            'unit': 'PKR',
            'sourceName': 'Gold-API international spot estimate',
            'sourceReference': entry.uri.toString(),
            'effectiveAt': effectiveAt.toUtc().toIso8601String(),
            'retrievedAt': retrievedAt.toIso8601String(),
            'configVersion': 'metal-spot-pkr-v1',
          };
        } catch (_) {
          return null;
        }
      }),
    );
    return results.whereType<Map<String, Object?>>().toList();
  }

  Future<List<Map<String, Object?>>> _fuelPayload(DateTime retrievedAt) async {
    final html = await _readText(_psoFuelEndpoint);
    final text = _plainText(html);
    final items = <Map<String, Object?>>[];

    final petrol = _firstNumber(
      text,
      RegExp(
        r'(?:PREMIER\s+EURO\s*5|Motor\s+Spirit|Petrol)\s*(?:Rs\.?\s*)?([0-9]+(?:\.[0-9]+)?)\s*/\s*Ltr',
        caseSensitive: false,
      ),
    );
    if (petrol != null) {
      items.add({
        'seriesKey': 'petrol',
        'value': petrol,
        'unit': 'PKR/Ltr',
        'sourceName': 'Pakistan State Oil (PSO)',
        'sourceReference': _psoFuelEndpoint.toString(),
        'effectiveAt': retrievedAt.toIso8601String(),
        'retrievedAt': retrievedAt.toIso8601String(),
        'configVersion': 'pso-fuel-v1',
      });
    }

    final diesel = _firstNumber(
      text,
      RegExp(
        r'(?:HI-CETANE\s+DIESEL\s+EURO\s*5|High\s+Speed\s+Diesel|HSD)\s*(?:Rs\.?\s*)?([0-9]+(?:\.[0-9]+)?)\s*/\s*Ltr',
        caseSensitive: false,
      ),
    );
    if (diesel != null) {
      items.add({
        'seriesKey': 'diesel',
        'value': diesel,
        'unit': 'PKR/Ltr',
        'sourceName': 'Pakistan State Oil (PSO)',
        'sourceReference': _psoFuelEndpoint.toString(),
        'effectiveAt': retrievedAt.toIso8601String(),
        'retrievedAt': retrievedAt.toIso8601String(),
        'configVersion': 'pso-fuel-v1',
      });
    }
    return items;
  }

  Future<List<Map<String, Object?>>> _economyPayload(
    DateTime retrievedAt,
  ) async {
    final html = await _readText(_economyEndpoint);
    final text = _plainText(html);
    final items = <Map<String, Object?>>[];

    void addIndicator({
      required String seriesKey,
      required String labelPattern,
      required String unit,
    }) {
      final match = RegExp(
        '\\b$labelPattern\\s+([0-9,.]+)\\s+([0-9,.]+)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match == null) return;
      final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
      if (value == null || value <= 0) return;
      final previous = double.tryParse(match.group(2)!.replaceAll(',', ''));
      items.add({
        'seriesKey': seriesKey,
        'value': value,
        'previousValue': (previous != null && previous > 0) ? previous : null,
        'unit': unit,
        'sourceName': 'Trading Economics (SBP / PBS)',
        'sourceReference': _economyEndpoint.toString(),
        'effectiveAt': retrievedAt.toIso8601String(),
        'retrievedAt': retrievedAt.toIso8601String(),
        'configVersion': 'te-economy-v1',
      });
    }

    addIndicator(
      seriesKey: 'sbp_policy_rate',
      labelPattern: r'Interest\s+Rate',
      unit: '%',
    );
    addIndicator(
      seriesKey: 'kibor_3m',
      labelPattern: r'Interbank\s+Rate',
      unit: '%',
    );
    addIndicator(
      seriesKey: 'inflation_cpi',
      labelPattern: r'Inflation\s+Rate',
      unit: '%',
    );
    addIndicator(
      seriesKey: 'forex_reserves',
      labelPattern: r'Foreign\s+Exchange\s+Reserves',
      unit: 'USD million',
    );
    return items;
  }

  Future<String> _readText(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, _browserUserAgent);
    request.headers.set(
      HttpHeaders.acceptHeader,
      'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    );
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Data source failed (${response.statusCode}).');
    }
    return utf8.decoder.bind(response).join();
  }

  String _plainText(String html) => html
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'&nbsp;|&#160;', caseSensitive: false), ' ')
      .replaceAll('&amp;', '&')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  double? _firstNumber(String text, RegExp expression) {
    final match = expression.firstMatch(text);
    if (match == null) return null;
    final value = double.tryParse(match.group(1)!.replaceAll(',', ''));
    return (value != null && value > 0) ? value : null;
  }

  Future<Map<String, Object?>> _readJson(Uri uri) async {
    final request = await _client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Data source failed (${response.statusCode}).');
    }
    final decoded = jsonDecode(await utf8.decoder.bind(response).join());
    if (decoded is! Map) {
      throw const FormatException('Data source response is invalid.');
    }
    return Map<String, Object?>.from(decoded);
  }

  Future<int> _storePayload(List<dynamic> payload) async {
    var stored = 0;
    for (final raw in payload) {
      if (raw is! Map) continue;
      final map = Map<String, Object?>.from(raw);
      final value = map['value'];
      final effectiveAt = DateTime.tryParse('${map['effectiveAt']}');
      final retrievedAt = DateTime.tryParse('${map['retrievedAt']}');
      if (value is! num || effectiveAt == null || retrievedAt == null) continue;
      final point = PakistanDataPoint(
        seriesKey: '${map['seriesKey']}',
        value: value.toDouble(),
        unit: '${map['unit']}',
        sourceName: '${map['sourceName']}',
        sourceReference: '${map['sourceReference']}',
        effectiveAt: effectiveAt,
        retrievedAt: retrievedAt,
        previousValue: (map['previousValue'] as num?)?.toDouble(),
        freshness: DataFreshness.current,
        configVersion: '${map['configVersion']}',
      );
      await repository.cache(point);
      stored++;
    }
    return stored;
  }
}
