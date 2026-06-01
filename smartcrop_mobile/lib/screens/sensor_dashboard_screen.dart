import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../core/services/backend_config.dart';
import '../core/lang_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Sensor Dashboard Screen – Professional Farming Theme + Animations
// ─────────────────────────────────────────────────────────────────────────────

class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _sensorData;
  Map<String, dynamic>? _analytics;
  List<dynamic>? _sensorAlerts;
  Map<String, dynamic>? _scenarios;
  String? _currentScenario;
  String? _errorMessage;
  late Timer _refreshTimer;

  static const _primary   = Color(0xFF2D6A4F);
  static const _accent    = Color(0xFF40916C);
  static const _cream     = Color(0xFFFAFAF5);
  static const _deepText  = Color(0xFF1B2A1B);
  static const _softText  = Color(0xFF4A5D4A);
  static const _sunset    = Color(0xFFE76F51);
  static const _golden    = Color(0xFFE9C46A);
  static const _teal      = Color(0xFF2A9D8F);
  static const _navy      = Color(0xFF264653);

  late AnimationController _fadeController;
  late AnimationController _pulseController;
  late Animation<double> _fadeIn;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.6, end: 1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _fetchAllData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchAllData());
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    _fadeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    try {
      final responses = await Future.wait([
        http.get(BackendConfig.apiUri('/api/sensor_data')),
        http.get(BackendConfig.apiUri('/api/sensor_data/analytics')),
        http.get(BackendConfig.apiUri('/api/sensor_scenarios')),
      ], eagerError: false);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200 && responses[2].statusCode == 200) {
        final sensorResponse   = jsonDecode(responses[0].body);
        final analyticsResponse = jsonDecode(responses[1].body);
        final scenariosResponse = jsonDecode(responses[2].body);
        setState(() {
          _sensorData     = sensorResponse['current_data'] as Map<String, dynamic>?;
          _sensorAlerts   = sensorResponse['alerts'] as List<dynamic>?;
          _analytics      = analyticsResponse['analytics'] as Map<String, dynamic>?;
          _scenarios      = (scenariosResponse['scenarios'] ?? {}) as Map<String, dynamic>?;
          _currentScenario = scenariosResponse['current_scenario']?.toString();
          _errorMessage   = null;
        });
      } else {
        setState(() => _errorMessage = 'Backend error: ${responses[0].statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Could not connect to backend');
    }
  }

  Future<void> _setScenario(String scenario) async {
    try {
      final response = await http.post(BackendConfig.apiUri('/api/sensor_scenarios/$scenario'));
      if (response.statusCode == 200) {
        _fetchAllData();
      } else {
        setState(() => _errorMessage = 'Failed to switch scenario');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error switching scenario');
    }
  }

  Color _getStatusColor(String metric, double value) {
    switch (metric) {
      case 'nitrogen': case 'phosphorus': case 'potassium':
        if (value < 20) return _sunset;
        if (value < 40) return _golden;
        return _primary;
      case 'temperature':
        if (value < 15 || value > 35) return const Color(0xFF3498db);
        if (value < 20 || value > 30) return _golden;
        return _primary;
      case 'humidity': case 'soil_moisture':
        if (value < 30 || value > 80) return _golden;
        return _primary;
      case 'ph':
        if (value < 6 || value > 8) return _sunset;
        if (value < 6.5 || value > 7.5) return _golden;
        return _primary;
      case 'light_intensity':
        if (value < 100) return _golden;
        return _primary;
      default: return _primary;
    }
  }

  String _getStatusText(String metric, double value) {
    final color = _getStatusColor(metric, value);
    if (color == _primary) return AppStrings.t('statusOptimal');
    if (color == _golden) return AppStrings.t('statusCaution');
    return AppStrings.t('statusAlert');
  }

  String _getTrendIcon(String trend) {
    switch (trend) { case 'improving': return '📈'; case 'declining': return '📉'; default: return '➡️'; }
  }

  Widget _buildHealthScoreCard() {
    if (_analytics == null) return const SizedBox.shrink();
    final double healthScore = ((_analytics!['health_score'] ?? 50) as num).toDouble();
    final String trend = (_analytics!['trend'] ?? 'stable').toString();
    final String crop  = (_analytics!['crop'] ?? 'Unknown').toString();
    final String stage = (_analytics!['stage'] ?? 'Unknown').toString();

    final Color scoreColor = healthScore >= 75 ? _primary : healthScore >= 50 ? _golden : _sunset;
    final String statusLabel = healthScore >= 75 ? AppStrings.t('statusHealthy') : healthScore >= 50 ? AppStrings.t('statusFair') : AppStrings.t('statusPoor');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scoreColor.withValues(alpha: 0.08), Colors.white],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('🌾', style: TextStyle(fontSize: 18)),
                        const SizedBox(width: 6),
                        Text(crop, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _deepText)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Stage: $stage', style: const TextStyle(fontSize: 12, color: _softText)),
                  ],
                ),
                // Health score circle
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [scoreColor.withValues(alpha: 0.15 * _pulse.value), Colors.transparent],
                        radius: 1.2,
                      ),
                    ),
                    child: child,
                  ),
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: scoreColor, width: 3),
                      boxShadow: [BoxShadow(color: scoreColor.withValues(alpha: 0.2), blurRadius: 8)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(healthScore.toStringAsFixed(0),
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scoreColor)),
                        Text('Score', style: TextStyle(fontSize: 9, color: scoreColor, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Progress bar & trend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (healthScore / 100).clamp(0.0, 1.0), minHeight: 8,
                    backgroundColor: Colors.grey.shade200, color: scoreColor,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(_getTrendIcon(trend), style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          trend == 'improving' ? AppStrings.t('trendImproving')
                            : trend == 'declining' ? AppStrings.t('trendDeclining')
                            : AppStrings.t('trendStable'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _softText)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scoreColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(String icon, String title, String value, String unit, double normalizedValue, String metric) {
    final statusColor = _getStatusColor(metric, double.parse(value));
    final statusText  = _getStatusText(metric, double.parse(value));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          // Subtle background gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topRight, end: Alignment.bottomLeft,
                  colors: [statusColor.withValues(alpha: 0.06), Colors.white],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
                      ),
                      child: Text(statusText,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 11, color: _softText, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: statusColor)),
                    const SizedBox(width: 4),
                    Text(unit, style: const TextStyle(fontSize: 11, color: _softText)),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: normalizedValue.clamp(0.0, 1.0), minHeight: 5,
                    backgroundColor: Colors.grey.shade200, color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(dynamic recommendation) {
    final String severity = (recommendation['severity'] ?? 'info').toString();
    final String icon     = (recommendation['icon'] ?? '📋').toString();
    final String message  = (recommendation['message'] ?? '').toString();
    final String action   = (recommendation['action'] ?? '').toString();

    Color bgColor, textColor, borderColor;
    switch (severity) {
      case 'critical':
        bgColor = const Color(0xFFFFF0EF); textColor = _sunset; borderColor = _sunset; break;
      case 'warning':
        bgColor = const Color(0xFFFFF8F0); textColor = const Color(0xFFe67e22); borderColor = _golden; break;
      case 'info':
        bgColor = const Color(0xFFF0F7FA); textColor = _navy; borderColor = _navy; break;
      default:
        bgColor = const Color(0xFFF0FAF0); textColor = _primary; borderColor = _primary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: textColor),
                const SizedBox(width: 6),
                Expanded(child: Text(action, style: TextStyle(fontSize: 11, color: textColor))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector() {
    if (_scenarios == null || _scenarios!.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: _teal.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
                child: const Icon(Icons.swap_horiz, size: 16, color: _teal),
              ),
              const SizedBox(width: 8),
              Text(AppStrings.t('demoScenarios'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _deepText)),
            ],
          ),
          const SizedBox(height: 4),
          Text(AppStrings.t('demoScenariosSub'), style: const TextStyle(fontSize: 11, color: _softText)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _scenarios!.entries.map<Widget>((entry) {
              final String key  = entry.key;
              final String name = (entry.value['display_name'] ?? key).toString();
              final String crop = (entry.value['crop'] ?? '').toString();
              final isActive = _currentScenario == key;
              return Material(
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => _setScenario(key),
                  borderRadius: BorderRadius.circular(10),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? _primary : _primary.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isActive ? _primary : _primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(name, style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _deepText)),
                        Text(crop, style: TextStyle(
                          fontSize: 9, color: isActive ? Colors.white70 : _softText)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;

    return ValueListenableBuilder<String>(
      valueListenable: AppLang.current,
      builder: (context, _, __) => Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(AppStrings.t('fieldMonitorTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        actions: [
          // Live indicator
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(Colors.green.shade300, Colors.green, _pulse.value),
                      boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.5 * _pulse.value), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _fetchAllData),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF0F7EE), _cream, Color(0xFFF5F0E8)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: _fetchAllData,
            color: _primary,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error banner
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _sunset.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: _sunset, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_errorMessage!, style: const TextStyle(color: _sunset, fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Health score
                  if (_analytics != null) ...[
                    _buildHealthScoreCard(),
                    const SizedBox(height: 18),
                  ],

                  // Scenario selector
                  _buildScenarioSelector(),
                  const SizedBox(height: 20),

                  // Section header
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 8),
                      Text(AppStrings.t('sensorData'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _deepText)),
                      const Spacer(),
                      if (_sensorData != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(AppStrings.t('sensorCount'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Sensor grid
                  if (_sensorData != null) ...[
                    GridView.count(
                      crossAxisCount: isWide ? 3 : 2,
                      crossAxisSpacing: 12, mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isWide ? 1.3 : 1.05,
                      children: [
                        _buildSensorCard('🧬', 'Nitrogen', (_sensorData!['nitrogen'] as num).toStringAsFixed(1), 'mg/kg', (_sensorData!['nitrogen'] as num) / 100, 'nitrogen'),
                        _buildSensorCard('✨', 'Phosphorus', (_sensorData!['phosphorus'] as num).toStringAsFixed(1), 'mg/kg', (_sensorData!['phosphorus'] as num) / 100, 'phosphorus'),
                        _buildSensorCard('💪', 'Potassium', (_sensorData!['potassium'] as num).toStringAsFixed(1), 'mg/kg', (_sensorData!['potassium'] as num) / 100, 'potassium'),
                        _buildSensorCard('🌡️', 'Temperature', (_sensorData!['temperature'] as num).toStringAsFixed(1), '°C', (_sensorData!['temperature'] as num) / 50, 'temperature'),
                        _buildSensorCard('💧', 'Humidity', (_sensorData!['humidity'] as num).toStringAsFixed(1), '%', (_sensorData!['humidity'] as num) / 100, 'humidity'),
                        _buildSensorCard('⚗️', 'pH Level', (_sensorData!['ph'] as num).toStringAsFixed(2), '', (_sensorData!['ph'] as num) / 14, 'ph'),
                        _buildSensorCard('🌧️', 'Rainfall', (_sensorData!['rainfall'] as num).toStringAsFixed(1), 'mm', (_sensorData!['rainfall'] as num) / 500, 'rainfall'),
                        _buildSensorCard('🌱', 'Soil Moisture', (_sensorData!['soil_moisture'] as num).toStringAsFixed(1), '%', (_sensorData!['soil_moisture'] as num) / 100, 'soil_moisture'),
                        _buildSensorCard('☀️', 'Light Intensity', (_sensorData!['light_intensity'] as num).toStringAsFixed(0), 'lux', (_sensorData!['light_intensity'] as num) / 10000, 'light_intensity'),
                      ],
                    ),
                  ] else ...[
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.05), blurRadius: 10)],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: _primary, strokeWidth: 3),
                            const SizedBox(height: 14),
                            Text(AppStrings.t('connecting'), style: const TextStyle(fontSize: 13, color: _softText)),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // Recommendations
                  if (_analytics != null && _analytics!['recommendations'] != null) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 4, height: 20, decoration: BoxDecoration(color: _teal, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(AppStrings.t('smartRecs'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _deepText)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...(_analytics!['recommendations'] as List).map<Widget>(_buildRecommendationCard),
                  ],

                  // Alerts
                  if (_sensorAlerts != null && _sensorAlerts!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Container(width: 4, height: 20, decoration: BoxDecoration(color: _sunset, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text(AppStrings.t('activeAlerts'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _deepText)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: _sunset.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text('${_sensorAlerts!.length}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _sunset)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._sensorAlerts!.map<Widget>((alert) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0EF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _sunset.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Text((alert['icon'] ?? '⚠️').toString(), style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Expanded(child: Text((alert['message'] ?? 'Unknown alert').toString(),
                            style: const TextStyle(color: _sunset, fontSize: 13, fontWeight: FontWeight.w500))),
                        ],
                      ),
                    )),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
