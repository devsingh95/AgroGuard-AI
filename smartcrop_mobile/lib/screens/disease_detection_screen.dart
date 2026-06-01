import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../services/disease_database_service.dart';
import '../services/disease_translations.dart';
import '../core/services/backend_config.dart';
import '../core/lang_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Disease Detection Screen – Professional Farming Theme + Animations
      final uri     = BackendConfig.apiUri('/api/predict_disease');
// ─────────────────────────────────────────────────────────────────────────────

class DiseaseDetectionScreen extends StatefulWidget {
  const DiseaseDetectionScreen({Key? key}) : super(key: key);

  @override
  State<DiseaseDetectionScreen> createState() =>
      _DiseaseDetectionScreenState();
}

class _DiseaseDetectionScreenState extends State<DiseaseDetectionScreen>
    with TickerProviderStateMixin {
  Uint8List? _imageBytes;
  String?   _imageFileName;
  bool      _isLoading      = false;
  String?   _errorMessage;
  Map<String, dynamic>? _diseaseResult;
  Map<String, dynamic>? _localKBMatch;

  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _savedAnalyses = [];
  String? _cropType = 'Unknown';
  final TextEditingController _notesController     = TextEditingController();
  final TextEditingController _fieldNameController =
      TextEditingController(text: 'Default Field');
  Map<String, dynamic>? _statistics;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _resultController;
  late Animation<double> _fadeIn;
  late Animation<double> _resultFade;
  late Animation<Offset> _resultSlide;

  // Colors
  static const _primary     = Color(0xFF2D6A4F);
  static const _accent      = Color(0xFF40916C);
  static const _cream       = Color(0xFFFAFAF5);
  static const _deepText    = Color(0xFF1B2A1B);
  static const _softText    = Color(0xFF4A5D4A);
  static const _warmAmber   = Color(0xFFD4A373);
  static const _sunset      = Color(0xFFE76F51);

  @override
  void initState() {
    super.initState();
    _loadHistory();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _resultController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _resultFade = CurvedAnimation(parent: _resultController, curve: Curves.easeOut);
    _resultSlide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _resultController, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _notesController.dispose();
    _fieldNameController.dispose();
    _fadeController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final analyses = await DiseaseDatabaseService.getAllAnalyses();
    final stats    = await DiseaseDatabaseService.getStatistics();
    setState(() {
      _savedAnalyses = analyses;
      _statistics    = stats;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: source, imageQuality: 85, maxWidth: 1024, maxHeight: 1024,
      );
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes    = bytes;
        _imageFileName = pickedFile.name;
        _errorMessage  = null;
        _diseaseResult = null;
        _localKBMatch  = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load image: $e');
    }
  }

  Future<void> _detectDisease() async {
    if (_imageBytes == null) {
      setState(() => _errorMessage = 'Please select an image first.');
      return;
    }
    setState(() {
      _isLoading     = true;
      _errorMessage  = null;
      _diseaseResult = null;
      _localKBMatch  = null;
    });

    try {
      final uri     = BackendConfig.apiUri('/api/predict_disease');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(http.MultipartFile.fromBytes(
        'image', _imageBytes!, filename: _imageFileName ?? 'upload.jpg',
      ));
      if (_cropType != null && _cropType != 'Unknown') {
        request.fields['crop_type'] = _cropType!;
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw Exception('Request timed out – is the backend reachable?'),
      );
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final diseaseName = (data['disease'] ?? data['prediction'] ?? 'Unknown').toString();
        final localInfo = DiseaseDatabaseService.lookupDisease(diseaseName);
        setState(() {
          _diseaseResult = data;
          _localKBMatch  = localInfo;
          _isLoading     = false;
        });
        _resultController.forward(from: 0);
      } else {
        String errMsg = 'Backend error ${streamedResponse.statusCode}';
        try { final err = jsonDecode(responseBody); errMsg = err['error']?.toString() ?? errMsg; } catch (_) {}
        setState(() { _errorMessage = errMsg; _isLoading = false; });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Analysis failed: ${e.toString().replaceAll("Exception: ", "")}';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveResult() async {
    if (_diseaseResult == null) return;
    setState(() => _isLoading = true);
    try {
      final diseaseName = (_diseaseResult!['disease'] ?? _diseaseResult!['prediction'] ?? 'Unknown').toString();
      final confidence = ((_diseaseResult!['confidence'] ?? _diseaseResult!['probability'] ?? 0) as num).toDouble();
      final kb = _localKBMatch;
      final symptoms  = kb != null ? (kb['symptoms'] as List).join('; ') : (_diseaseResult!['symptoms'] ?? '').toString();
      final treatment = kb != null ? (kb['treatment'] as List).join('; ') : (_diseaseResult!['treatment'] ?? '').toString();
      final prevention = kb != null ? (kb['prevention'] as List).join('; ') : (_diseaseResult!['prevention'] ?? '').toString();

      final id = await DiseaseDatabaseService.saveDiseaseAnalysis(
        imagePath: _imageFileName ?? 'web_upload',
        disease: diseaseName, confidence: confidence,
        symptoms: symptoms, treatment: treatment, prevention: prevention,
        cropType: _cropType ?? 'Unknown',
        fieldName: _fieldNameController.text.isEmpty ? 'Default Field' : _fieldNameController.text,
        notes: _notesController.text,
      );
      setState(() => _isLoading = false);
      if (!mounted) return;
      if (id != -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.t('saveSuccess')), backgroundColor: _primary),
        );
        await _loadHistory();
        _notesController.clear();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteAnalysis(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppStrings.t('deleteAnalysis'), style: const TextStyle(color: _deepText)),
        content: Text(AppStrings.t('deleteConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.t('cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.t('delete'), style: const TextStyle(color: _sunset)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await DiseaseDatabaseService.deleteAnalysis(id);
      await _loadHistory();
    }
  }

  Color _severityColor(String? s) {
    switch ((s ?? '').toLowerCase()) {
      case 'high':     return const Color(0xFFc0392b);
      case 'moderate': case 'moderate–high': return const Color(0xFFe67e22);
      case 'none':     return _primary;
      default:         return const Color(0xFF607D8B);
    }
  }

  Color _confidenceColor(double c) =>
      c >= 0.80 ? _primary : c >= 0.50 ? const Color(0xFFe67e22) : _sunset;

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: AppLang.current,
    builder: (context, _, __) => DefaultTabController(
    length: 2,
    child: Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔬', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Text(AppStrings.t('diseaseDetectorTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          ],
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        bottom: TabBar(
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: const Color(0xFFE9C46A),
          indicatorWeight: 3,
          dividerHeight: 0,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(icon: const Icon(Icons.biotech, size: 20), text: AppStrings.t('newAnalysis')),
            Tab(icon: const Icon(Icons.history, size: 20), text: AppStrings.t('history')),
          ],
        ),
      ),
      body: FadeTransition(
        opacity: _fadeIn,
        child: TabBarView(children: [_buildAnalysisTab(), _buildHistoryTab()]),
      ),
    ),
  ));

  Widget _buildAnalysisTab() => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildImageSection(),
        const SizedBox(height: 16),
        _buildCropFieldRow(),
        const SizedBox(height: 16),
        _buildAnalyzeButton(),
        if (_errorMessage != null) ...[const SizedBox(height: 12), _buildErrorBanner()],
        if (_diseaseResult != null) ...[const SizedBox(height: 20),
          SlideTransition(position: _resultSlide, child: FadeTransition(opacity: _resultFade, child: _buildResultsSection()))],
      ],
    ),
  );

  Widget _buildImageSection() => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.add_photo_alternate, color: _primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(AppStrings.t('uploadImage'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _deepText)),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 220, width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: _imageBytes != null ? _primary : const Color(0xFFE0E0E0), width: 2,
              ),
              borderRadius: BorderRadius.circular(14),
              color: _imageBytes != null ? _primary.withValues(alpha: 0.03) : const Color(0xFFF8F8F8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _imageBytes != null
                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.eco_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text(AppStrings.t('noImageSelected'), style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(AppStrings.t('takeOrChoose'), style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _actionButton(
                icon: Icons.photo_library_outlined, label: AppStrings.t('gallery'),
                gradient: const [Color(0xFF264653), Color(0xFF2A9D8F)],
                onTap: () => _pickImage(ImageSource.gallery),
              )),
              const SizedBox(width: 10),
              Expanded(child: _actionButton(
                icon: Icons.camera_alt_outlined, label: AppStrings.t('camera'),
                gradient: const [Color(0xFF6B4226), Color(0xFFD4A373)],
                onTap: () => _pickImage(ImageSource.camera),
              )),
            ],
          ),
          if (_imageFileName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.attach_file, size: 14, color: _accent),
                  const SizedBox(width: 4),
                  Flexible(child: Text(_imageFileName!, style: const TextStyle(fontSize: 12, color: _softText),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _actionButton({required IconData icon, required String label, required List<Color> gradient, required VoidCallback onTap}) =>
    Material(
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
            ],
          ),
        ),
      ),
    );

  Widget _buildCropFieldRow() => Row(
    children: [
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _cropType, isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down, color: _accent),
                style: const TextStyle(fontSize: 13, color: _deepText),
                items: const [
                  DropdownMenuItem(value: 'Unknown',  child: Text('🌱 Crop type')),
                  DropdownMenuItem(value: 'Wheat',    child: Text('🌾 Wheat')),
                  DropdownMenuItem(value: 'Rice',     child: Text('🍚 Rice')),
                  DropdownMenuItem(value: 'Corn',     child: Text('🌽 Corn')),
                  DropdownMenuItem(value: 'Potato',   child: Text('🥔 Potato')),
                  DropdownMenuItem(value: 'Tomato',   child: Text('🍅 Tomato')),
                  DropdownMenuItem(value: 'Apple',    child: Text('🍎 Apple')),
                  DropdownMenuItem(value: 'Grape',    child: Text('🍇 Grape')),
                  DropdownMenuItem(value: 'Cucumber', child: Text('🥒 Cucumber')),
                  DropdownMenuItem(value: 'Cotton',   child: Text('🌿 Cotton')),
                ],
                onChanged: (v) => setState(() => _cropType = v),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _fieldNameController,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Field name',
              prefixIcon: Icon(Icons.landscape_outlined, color: _accent, size: 18),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _buildAnalyzeButton() => SizedBox(
    height: 52,
    child: Material(
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _isLoading ? null : _detectDisease,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            gradient: _isLoading
              ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade500])
              : const LinearGradient(colors: [Color(0xFF2D6A4F), Color(0xFF40916C)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isLoading ? [] : [
              BoxShadow(color: _primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
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
                  const Icon(Icons.biotech, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(_isLoading ? AppStrings.t('analysing') : AppStrings.t('analyseDisease'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildErrorBanner() => Container(
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
  );

  Widget _buildResultsSection() {
    final diseaseName = (_diseaseResult!['disease'] ?? _diseaseResult!['prediction'] ?? 'Unknown').toString();
    final confidence = ((_diseaseResult!['confidence'] ?? _diseaseResult!['probability'] ?? 0) as num).toDouble();
    final kb = _localKBMatch;
    final isHealthy = diseaseName.toLowerCase().contains('healthy');

    // ── Translated KB overlay ───────────────────────────────────────────
    // Look up translated content for the current language. If found, merge
    // over the English KB so that symptoms/causes/treatment/prevention/
    // organicOptions display in the user's language.
    Map<String, dynamic>? tKb;
    if (kb != null) {
      final lang = AppLang.current.value;
      final diseaseKey = diseaseName.toLowerCase().trim();
      final translated = DiseaseTranslations.getTranslated(diseaseKey, lang);
      if (translated != null) {
        tKb = {...kb, ...translated};
      } else {
        tKb = kb;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(Icons.analytics, AppStrings.t('analysisResults')),
        const SizedBox(height: 10),
        // Summary card
        Container(
          decoration: BoxDecoration(
            color: isHealthy ? const Color(0xFFF0FAF0) : const Color(0xFFFFF8F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isHealthy ? _primary.withValues(alpha: 0.2) : _warmAmber.withValues(alpha: 0.3)),
            boxShadow: [BoxShadow(color: (isHealthy ? _primary : _warmAmber).withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isHealthy ? _primary : _sunset).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(isHealthy ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: isHealthy ? _primary : _sunset, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(diseaseName,
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
                        color: isHealthy ? _primary : const Color(0xFF5D4037))),
                  ),
                ],
              ),
              if (kb != null) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Text('${kb["scientificName"]}',
                    style: const TextStyle(fontSize: 12, color: _softText, fontStyle: FontStyle.italic)),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Confidence ', style: TextStyle(fontSize: 13, color: _softText)),
                  Text('${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _confidenceColor(confidence))),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: confidence, minHeight: 8,
                  backgroundColor: Colors.grey.shade200, color: _confidenceColor(confidence)),
              ),
              if (kb != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: [
                    _chip('${kb["severity"]}', _severityColor(kb['severity'] as String?)),
                    ...(kb['affectedCrops'] as List).take(3).map(
                      (c) => _chip(c.toString(), const Color(0xFF2A9D8F)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        // DB match indicator
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(kb != null ? Icons.library_books : Icons.help_outline, size: 14,
              color: kb != null ? _primary : Colors.grey),
            const SizedBox(width: 6),
            Text(
              kb != null ? AppStrings.t('matchedDB') : AppStrings.t('noDBMatch'),
              style: TextStyle(fontSize: 11, color: kb != null ? _primary : Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        // Detail cards
        if (kb != null && !isHealthy) ...[
          const SizedBox(height: 16),
          _detailCard(icon: Icons.sick, title: AppStrings.t('symptoms'), color: const Color(0xFFc0392b), bgColor: const Color(0xFFFFF5F4),
            items: (tKb!['symptoms'] as List).cast<String>()),
          const SizedBox(height: 10),
          _detailCard(icon: Icons.info_outline, title: AppStrings.t('cause'), color: const Color(0xFFe67e22), bgColor: const Color(0xFFFFF8F0),
            body: tKb['causes'] as String),
          const SizedBox(height: 10),
          _detailCard(icon: Icons.healing, title: AppStrings.t('treatment'), color: const Color(0xFF264653), bgColor: const Color(0xFFF0F7FA),
            items: (tKb['treatment'] as List).cast<String>()),
          const SizedBox(height: 10),
          _detailCard(icon: Icons.eco, title: AppStrings.t('prevention'), color: _primary, bgColor: const Color(0xFFF0FAF0),
            items: (tKb['prevention'] as List).cast<String>()),
          const SizedBox(height: 10),
          _detailCard(icon: Icons.spa, title: AppStrings.t('organicOptions'), color: const Color(0xFF6B4226), bgColor: const Color(0xFFFAF5EE),
            items: (tKb['organicOptions'] as List).cast<String>()),
        ],
        if (isHealthy && kb != null) ...[
          const SizedBox(height: 10),
          _detailCard(icon: Icons.eco, title: AppStrings.t('preventiveCare'), color: _primary, bgColor: const Color(0xFFF0FAF0),
            items: (tKb!['prevention'] as List).cast<String>()),
        ],
        // Notes + Save
        const SizedBox(height: 22),
        _sectionHeader(Icons.edit_note, AppStrings.t('notesTitle')),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _notesController,
                decoration: InputDecoration(
                  hintText: AppStrings.t('notesHint'),
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.edit_note, color: _accent),
                  filled: true, fillColor: const Color(0xFFFAFAF5),
                ),
                minLines: 3, maxLines: 5,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveResult,
                  icon: const Icon(Icons.save_alt, size: 18),
                  label: Text(AppStrings.t('saveHistory'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF264653),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: _primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 16, color: _primary),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _deepText)),
    ],
  );

  Widget _detailCard({
    required IconData icon, required String title,
    required Color color, required Color bgColor,
    List<String>? items, String? body,
  }) => Container(
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.15)),
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 10),
        if (body != null && body.isNotEmpty)
          Text(body, style: const TextStyle(fontSize: 13, height: 1.5, color: _softText)),
        if (items != null)
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.5), shape: BoxShape.circle),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.4, color: _softText))),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _chip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.25)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
  );

  // ── History Tab ───────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_savedAnalyses.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_toggle_off, size: 48, color: _accent),
            ),
            const SizedBox(height: 16),
            Text(AppStrings.t('noHistoryYet'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _deepText)),
            const SizedBox(height: 6),
            Text(AppStrings.t('noHistoryHint'), style: const TextStyle(fontSize: 13, color: _softText)),
          ],
        ),
      );
    }
    return Column(
      children: [
        if (_statistics != null)
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statTile(AppStrings.t('totalAnalyses'), (_statistics!['totalAnalyses'] ?? 0).toString(), _primary),
                Container(width: 1, height: 32, color: _primary.withValues(alpha: 0.1)),
                _statTile(AppStrings.t('avgConf'),
                  '${((_statistics!['averageConfidence'] ?? 0) * 100).toStringAsFixed(0)}%',
                  const Color(0xFF264653)),
                if ((_statistics!['diseaseCounts'] as List).isNotEmpty) ...[
                  Container(width: 1, height: 32, color: _primary.withValues(alpha: 0.1)),
                  _statTile(AppStrings.t('topDisease'),
                    (_statistics!['diseaseCounts'] as List).first['disease'].toString().split(' ').first,
                    _sunset),
                ],
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            itemCount: _savedAnalyses.length,
            itemBuilder: (context, i) {
              final a = _savedAnalyses[i];
              final conf = ((a['confidence'] as num? ?? 0) * 100).toStringAsFixed(0);
              final disease = (a['disease'] ?? 'Unknown').toString();
              final kb = DiseaseDatabaseService.lookupDisease(disease);
              final isHealthy = disease.toLowerCase().contains('healthy');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: _primary.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isHealthy ? _primary : _sunset).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isHealthy ? Icons.check_circle : Icons.bug_report,
                        color: isHealthy ? _primary : _sunset, size: 20),
                    ),
                    title: Text(disease, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: _deepText)),
                    subtitle: Text(
                      'Conf: $conf% · ${a['cropType'] ?? ''} · ${a['timestamp'] ?? ''}',
                      style: const TextStyle(fontSize: 11, color: _softText),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (kb != null) _chip(kb['severity'] as String, _severityColor(kb['severity'] as String?)),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: _sunset, size: 20),
                          tooltip: 'Delete',
                          onPressed: () => _deleteAnalysis(a['id'] as int),
                        ),
                      ],
                    ),
                    children: [
                      if (kb != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((a['notes'] ?? '').toString().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text('Notes: ${a['notes']}',
                                    style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13, color: _softText)),
                                ),
                              _detailCard(icon: Icons.healing, title: AppStrings.t('treatment'),
                                color: const Color(0xFF264653), bgColor: const Color(0xFFF0F7FA),
                                items: (kb['treatment'] as List).cast<String>()),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, Color color) => Column(
    children: [
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11, color: _softText)),
    ],
  );
}
