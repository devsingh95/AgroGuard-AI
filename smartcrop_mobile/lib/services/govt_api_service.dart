import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/services/backend_config.dart';

/// Government Portal API Service
/// Communicates with all /api/govt/* backend endpoints
class GovtApiService {
  static String get _baseUrl => '${BackendConfig.origin}/api/govt';

  // ── eNAM Mandi Prices ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMandiPrices({
    String? state, String? commodity, String? mandi, int limit = 50,
  }) async {
    final params = <String, String>{};
    if (state != null) params['state'] = state;
    if (commodity != null) params['commodity'] = commodity;
    if (mandi != null) params['mandi'] = mandi;
    params['limit'] = limit.toString();
    return _get('/mandi/prices', params);
  }

  static Future<Map<String, dynamic>> getMandiComparison(String commodity) =>
      _get('/mandi/compare/$commodity');

  static Future<List<String>> getStates() async {
    final res = await _get('/mandi/states');
    return List<String>.from((res['states'] as List?) ?? []);
  }

  static Future<Map<String, dynamic>> getCommodities() async {
    final res = await _get('/mandi/commodities');
    return Map<String, dynamic>.from((res['commodities'] as Map?) ?? {});
  }

  static Future<List<String>> getMandisForState(String state) async {
    final res = await _get('/mandi/mandis/$state');
    return List<String>.from((res['mandis'] as List?) ?? []);
  }

  // ── Agmarknet Market Trends ─────────────────────────────────────────────

  static Future<Map<String, dynamic>> getMarketTrend(String commodity, {int months = 6}) =>
      _get('/market/trend/$commodity', {'months': months.toString()});

  static Future<List<dynamic>> getMarketAlerts({String? commodity}) async {
    final params = <String, String>{};
    if (commodity != null) params['commodity'] = commodity;
    final res = await _get('/market/alerts', params);
    return List<dynamic>.from((res['alerts'] as List?) ?? []);
  }

  static Future<List<dynamic>> getSeasonalCalendar() async {
    final res = await _get('/market/calendar');
    return List<dynamic>.from((res['calendar'] as List?) ?? []);
  }

  // ── mKisan Advisories ──────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAdvisories({
    String? category, String? state, String? crop, int limit = 30,
  }) async {
    final params = <String, String>{};
    if (category != null) params['category'] = category;
    if (state != null) params['state'] = state;
    if (crop != null) params['crop'] = crop;
    params['limit'] = limit.toString();
    return _get('/advisories', params);
  }

  static Future<List<dynamic>> getAdvisoryCategories() async {
    final res = await _get('/advisories/categories');
    return List<dynamic>.from((res['categories'] as List?) ?? []);
  }

  // ── myScheme Eligibility ───────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAllSchemes() => _get('/schemes');

  static Future<Map<String, dynamic>> checkEligibility({
    int? age, String? gender, double? landHectares,
    String? state, String? farmerType, String? keywords,
  }) async {
    final body = <String, dynamic>{};
    if (age != null) body['age'] = age;
    if (gender != null) body['gender'] = gender;
    if (landHectares != null) body['land_hectares'] = landHectares;
    if (state != null) body['state'] = state;
    if (farmerType != null) body['farmer_type'] = farmerType;
    if (keywords != null) body['keywords'] = keywords;
    return _post('/schemes/check', body);
  }

  static Future<Map<String, dynamic>> getSchemeDetail(int id) => _get('/schemes/$id');

  // ── PMFBY Insurance ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> calculatePremium({
    required String season, required String crop, required double areaHectares,
  }) => _post('/insurance/calculate', {
    'season': season, 'crop': crop, 'area_hectares': areaHectares,
  });

  static Future<Map<String, dynamic>> checkClaimStatus(String applicationId) =>
      _get('/insurance/status/$applicationId');

  static Future<Map<String, dynamic>> getInsurableCrops() => _get('/insurance/crops');

  static Future<Map<String, dynamic>> getInsuranceDeadlines() => _get('/insurance/deadlines');

  // ── Dashboard ──────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboard({String state = 'Punjab'}) =>
      _get('/dashboard', {'state': state});

  // ── HTTP helpers ───────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _get(String path, [Map<String, String>? params]) async {
    try {
      final uri = BackendConfig.apiUri('/api/govt$path', queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    try {
      final uri = BackendConfig.apiUri('/api/govt$path');
      final response = await http.post(uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}
