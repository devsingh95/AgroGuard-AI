import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../core/services/backend_config.dart';

class SensorDashboardScreen extends StatefulWidget {
  const SensorDashboardScreen({Key? key}) : super(key: key);

  @override
  State<SensorDashboardScreen> createState() => _SensorDashboardScreenState();
}

class _SensorDashboardScreenState extends State<SensorDashboardScreen> {
  Map<String, dynamic>? _sensorData;
  List<dynamic>? _sensorAlerts;
  final bool _isLoading = false;
  String? _errorMessage;
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchSensorData();
    // Auto-refresh every 5 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchSensorData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  Future<void> _fetchSensorData() async {
    try {
      final response =
          await http.get(BackendConfig.apiUri('/api/sensor_data'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _sensorData = data['current_data'];
          _sensorAlerts = data['alerts'];
          _errorMessage = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Backend error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: Could not connect to backend';
      });
    }
  }

  Color _getStatusColor(String metric, double value) {
    // Optimize color based on metric ranges
    switch (metric) {
      case 'nitrogen':
      case 'phosphorus':
      case 'potassium':
        if (value < 20) return Colors.red;
        if (value < 40) return Colors.orange;
        return Colors.green;
      case 'temperature':
        if (value < 15 || value > 35) return Colors.blue;
        if (value < 20 || value > 30) return Colors.orange;
        return Colors.green;
      case 'humidity':
      case 'soil_moisture':
        if (value < 30 || value > 80) return Colors.orange;
        return Colors.green;
      case 'ph':
        if (value < 6 || value > 8) return Colors.red;
        if (value < 6.5 || value > 7.5) return Colors.orange;
        return Colors.green;
      case 'light_intensity':
        if (value < 100) return Colors.orange;
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  String _getStatusText(String metric, double value) {
    final color = _getStatusColor(metric, value);
    if (color == Colors.green) return 'Optimal';
    if (color == Colors.orange) return 'Caution';
    return 'Alert';
  }

  Widget _buildSensorCard(
    String icon,
    String title,
    String value,
    String unit,
    double normalizedValue,
    String metric,
  ) {
    final statusColor = _getStatusColor(metric, double.parse(value));
    final statusText = _getStatusText(metric, double.parse(value));

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              statusColor.withOpacity(0.1),
            ],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 28),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: statusColor,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF2c3e50),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$value $unit',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2ecc71),
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: normalizedValue.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('�️ Field Monitor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchSensorData,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0FDF4),
              Color(0xFFE0F5E9),
            ],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _fetchSensorData,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFffe0e0),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFe74c3c),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_rounded,
                          color: Color(0xFFe74c3c),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Color(0xFFe74c3c),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Text(
                  'Real-Time Sensor Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF27ae60),
                  ),
                ),
                const SizedBox(height: 12),
                if (_sensorData != null) ...[
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildSensorCard(
                        '🧬',
                        'Nitrogen',
                        (_sensorData!['nitrogen'] as num).toStringAsFixed(1),
                        'mg/kg',
                        (_sensorData!['nitrogen'] as num) / 100,
                        'nitrogen',
                      ),
                      _buildSensorCard(
                        '✨',
                        'Phosphorus',
                        (_sensorData!['phosphorus'] as num)
                            .toStringAsFixed(1),
                        'mg/kg',
                        (_sensorData!['phosphorus'] as num) / 100,
                        'phosphorus',
                      ),
                      _buildSensorCard(
                        '💪',
                        'Potassium',
                        (_sensorData!['potassium'] as num).toStringAsFixed(1),
                        'mg/kg',
                        (_sensorData!['potassium'] as num) / 100,
                        'potassium',
                      ),
                      _buildSensorCard(
                        '🌡️',
                        'Temperature',
                        (_sensorData!['temperature'] as num)
                            .toStringAsFixed(1),
                        '°C',
                        (_sensorData!['temperature'] as num) / 50,
                        'temperature',
                      ),
                      _buildSensorCard(
                        '💧',
                        'Humidity',
                        (_sensorData!['humidity'] as num).toStringAsFixed(1),
                        '%',
                        (_sensorData!['humidity'] as num) / 100,
                        'humidity',
                      ),
                      _buildSensorCard(
                        '⚗️',
                        'pH Level',
                        (_sensorData!['ph'] as num).toStringAsFixed(2),
                        '',
                        (_sensorData!['ph'] as num) / 14,
                        'ph',
                      ),
                      _buildSensorCard(
                        '🌧️',
                        'Rainfall',
                        (_sensorData!['rainfall'] as num).toStringAsFixed(1),
                        'mm',
                        (_sensorData!['rainfall'] as num) / 500,
                        'rainfall',
                      ),
                      _buildSensorCard(
                        '🌱',
                        'Soil Moisture',
                        (_sensorData!['soil_moisture'] as num)
                            .toStringAsFixed(1),
                        '%',
                        (_sensorData!['soil_moisture'] as num) / 100,
                        'soil_moisture',
                      ),
                      _buildSensorCard(
                        '☀️',
                        'Light Intensity',
                        (_sensorData!['light_intensity'] as num)
                            .toStringAsFixed(0),
                        'lux',
                        (_sensorData!['light_intensity'] as num) / 10000,
                        'light_intensity',
                      ),
                    ],
                  ),
                ] else ...[
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
                if (_sensorAlerts != null && _sensorAlerts!.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    '⚠️ Active Alerts',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFe74c3c),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ..._sensorAlerts!.map<Widget>((alert) => Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: const Color(0xFFffe0e0),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.warning,
                              color: Color(0xFFe74c3c),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                alert['message'] ?? 'Unknown alert',
                                style: const TextStyle(
                                  color: Color(0xFFe74c3c),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
}
