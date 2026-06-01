import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/services/backend_config.dart';
import '../core/lang_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Crop Recommendation Screen – Professional Farming Theme
// ─────────────────────────────────────────────────────────────────────────────

class CropRecommendationScreen extends StatefulWidget {
  const CropRecommendationScreen({Key? key}) : super(key: key);

  @override
  State<CropRecommendationScreen> createState() =>
      _CropRecommendationScreenState();
}

class _CropRecommendationScreenState extends State<CropRecommendationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _recommendedCrop;
  double? _confidence;
  String? _errorMessage;

  static const _primary   = Color(0xFF2D6A4F);
  static const _accent    = Color(0xFF40916C);
  static const _cream     = Color(0xFFFAFAF5);
  static const _deepText  = Color(0xFF1B2A1B);
  static const _softText  = Color(0xFF4A5D4A);
  static const _sunset    = Color(0xFFE76F51);
  static const _golden    = Color(0xFFE9C46A);

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _resultController;
  late Animation<double> _fadeIn;
  late Animation<double> _resultScale;

  final nitrogenController     = TextEditingController();
  final phosphorusController   = TextEditingController();
  final potassiumController    = TextEditingController();
  final temperatureController  = TextEditingController();
  final humidityController     = TextEditingController();
  final phController           = TextEditingController();
  final rainfallController     = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultScale = CurvedAnimation(parent: _resultController, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _resultController.dispose();
    nitrogenController.dispose();
    phosphorusController.dispose();
    potassiumController.dispose();
    temperatureController.dispose();
    humidityController.dispose();
    phController.dispose();
    rainfallController.dispose();
    super.dispose();
  }

  Future<void> _predictCrop() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      final response = await http.post(
        BackendConfig.apiUri('/api/predict_crop'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nitrogen': double.parse(nitrogenController.text),
          'phosphorus': double.parse(phosphorusController.text),
          'potassium': double.parse(potassiumController.text),
          'temperature': double.parse(temperatureController.text),
          'humidity': double.parse(humidityController.text),
          'ph': double.parse(phController.text),
          'rainfall': double.parse(rainfallController.text),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _recommendedCrop = data['crop']?.toString();
          _confidence = (data['confidence'] as num?)?.toDouble();
          _isLoading = false;
        });
        _resultController.forward(from: 0);
      } else {
        setState(() { _errorMessage = 'Backend error: ${response.statusCode}'; _isLoading = false; });
      }
    } catch (e) {
      setState(() { _errorMessage = 'Could not connect to backend'; _isLoading = false; });
    }
  }

  String _getCropEmoji(String crop) {
    final map = {
      'rice': '🍚', 'wheat': '🌾', 'maize': '🌽', 'corn': '🌽',
      'cotton': '🌿', 'jute': '🧶', 'coffee': '☕', 'coconut': '🥥',
      'apple': '🍎', 'mango': '🥭', 'banana': '🍌', 'grapes': '🍇',
      'orange': '🍊', 'papaya': '🍈', 'pomegranate': '🫐',
      'lentil': '🫘', 'chickpea': '🫛', 'kidney beans': '🫘',
      'mung bean': '🫛', 'pigeon peas': '🫛',
    };
    return map[crop.toLowerCase()] ?? '🌱';
  }

  Widget _buildTextField(
    TextEditingController controller, String label, String unit, IconData icon,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(fontSize: 14, color: _deepText),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 8, right: 4),
          child: Icon(icon, size: 18, color: _accent),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 36),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _sunset, width: 1.5),
        ),
        labelStyle: const TextStyle(fontSize: 13, color: _softText),
        suffixStyle: const TextStyle(fontSize: 12, color: _softText),
      ),
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Please enter $label';
        if (double.tryParse(value!) == null) return 'Invalid number';
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: AppLang.current,
    builder: (context, _, __) => Scaffold(
    backgroundColor: _cream,
    appBar: AppBar(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🌾', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text(AppStrings.t('cropAdvisorTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _primary.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Text('🧪', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppStrings.t('soilWeatherTitle'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _deepText)),
                          const SizedBox(height: 2),
                          Text(AppStrings.t('soilWeatherSub'),
                            style: const TextStyle(fontSize: 12, color: _softText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Form card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                padding: const EdgeInsets.all(18),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Soil nutrients section
                      Row(
                        children: [
                          Container(width: 3, height: 18, decoration: BoxDecoration(color: _primary, borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(AppStrings.t('soilNutrients'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _deepText)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(nitrogenController, AppStrings.t('nitrogen'), 'mg/kg', Icons.science),
                      _buildTextField(phosphorusController, AppStrings.t('phosphorus'), 'mg/kg', Icons.science_outlined),
                      _buildTextField(potassiumController, AppStrings.t('potassium'), 'mg/kg', Icons.science),

                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(width: 3, height: 18, decoration: BoxDecoration(color: const Color(0xFF264653), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 8),
                          Text(AppStrings.t('weatherCond'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _deepText)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildTextField(temperatureController, AppStrings.t('temperature'), '°C', Icons.thermostat),
                      _buildTextField(humidityController, AppStrings.t('humidity'), '%', Icons.water_drop),
                      _buildTextField(phController, AppStrings.t('phLevel'), '', Icons.analytics),
                      _buildTextField(rainfallController, AppStrings.t('rainfall'), 'mm', Icons.grain),

                      const SizedBox(height: 8),

                      // Predict button
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: Material(
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            onTap: _isLoading ? null : _predictCrop,
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              decoration: BoxDecoration(
                                gradient: _isLoading
                                  ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
                                  : const LinearGradient(colors: [Color(0xFF2D6A4F), Color(0xFF40916C)]),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: _isLoading ? [] : [
                                  BoxShadow(color: _primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isLoading)
                                      const SizedBox(height: 20, width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    else
                                      const Icon(Icons.agriculture, color: Colors.white, size: 20),
                                    const SizedBox(width: 10),
                                    Text(_isLoading ? AppStrings.t('analyzing') : AppStrings.t('getRecommendation'),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Error banner
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
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
              ],

              // Result card
              if (_recommendedCrop != null) ...[
                const SizedBox(height: 24),
                ScaleTransition(
                  scale: _resultScale,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFF0FAF0), Color(0xFFFAFAF5)],
                      ),
                      border: Border.all(color: _primary.withValues(alpha: 0.2)),
                      boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.06),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.check_circle, color: _primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(AppStrings.t('recommendedCrop'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _deepText)),
                            ],
                          ),
                        ),
                        // Body
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(_getCropEmoji(_recommendedCrop!), style: const TextStyle(fontSize: 48)),
                              const SizedBox(height: 10),
                              Text(_recommendedCrop!,
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: _primary, letterSpacing: -0.5)),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(AppStrings.t('confidence'), style: const TextStyle(fontSize: 14, color: _softText)),
                                  Text('${(_confidence! * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _primary)),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: _confidence, minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  color: _primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  ));
}
