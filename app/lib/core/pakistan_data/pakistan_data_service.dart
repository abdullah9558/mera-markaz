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
    return _refreshExchangeRates();
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

  Future<int> _refreshExchangeRates() async {
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
    final retrievedAt = DateTime.now().toUtc();
    final updateSeconds = decoded['time_last_update_unix'];
    final effectiveAt = updateSeconds is num
        ? DateTime.fromMillisecondsSinceEpoch(
            updateSeconds.toInt() * 1000,
            isUtc: true,
          )
        : retrievedAt;
    final payload = <Map<String, Object?>>[];
    for (final currency in _exchangeCurrencies) {
      final currencyRate = rates[currency];
      if (currencyRate is! num || currencyRate <= 0) continue;
      payload.add({
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
    try {
      payload.addAll(
        await _metalPayload(
          pkrPerUsd: pkr.toDouble(),
          retrievedAt: retrievedAt,
        ),
      );
    } catch (_) {
      // Currency data remains useful when a precious-metal feed is down.
    }
    return _storePayload(payload);
  }

  Future<List<Map<String, Object?>>> _metalPayload({
    required double pkrPerUsd,
    required DateTime retrievedAt,
  }) async {
    final responses = await Future.wait([
      _readJson(_goldEndpoint),
      _readJson(_silverEndpoint),
    ]);
    final output = <Map<String, Object?>>[];
    for (var index = 0; index < responses.length; index++) {
      final response = responses[index];
      final price = response['price'];
      if (price is! num || price <= 0) continue;
      final effectiveAt =
          DateTime.tryParse('${response['updatedAt']}') ?? retrievedAt;
      final perTolaPkr =
          price.toDouble() * (_gramsPerTola / _gramsPerTroyOunce) * pkrPerUsd;
      final isGold = index == 0;
      output.add({
        'seriesKey': isGold ? 'gold_24k_tola' : 'silver_tola',
        'value': perTolaPkr,
        'unit': 'PKR',
        'sourceName': 'Gold-API international spot estimate',
        'sourceReference': (isGold ? _goldEndpoint : _silverEndpoint)
            .toString(),
        'effectiveAt': effectiveAt.toUtc().toIso8601String(),
        'retrievedAt': retrievedAt.toIso8601String(),
        'configVersion': 'metal-spot-pkr-v1',
      });
    }
    return output;
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
