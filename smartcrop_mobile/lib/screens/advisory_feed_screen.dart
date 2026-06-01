import 'package:flutter/material.dart';
import '../core/lang_provider.dart';
import '../services/govt_api_service.dart';

/// mKisan Advisory Feed Screen
/// Government SMS advisories — weather, pest, crop management, schemes, market
class AdvisoryFeedScreen extends StatefulWidget {
  const AdvisoryFeedScreen({super.key});
  @override
  State<AdvisoryFeedScreen> createState() => _AdvisoryFeedScreenState();
}

class _AdvisoryFeedScreenState extends State<AdvisoryFeedScreen> {
  List<dynamic> _advisories = [];
  List<dynamic> _categories = [];
  String? _selectedCategory;
  String? _selectedState;
  List<String> _states = [];
  bool _loading = true;

  static const _categoryEmoji = {
    'weather': '🌦️',
    'pest_disease': '🐛',
    'crop_management': '🌱',
    'scheme_announcement': '📜',
    'market': '📊',
  };

  static const _severityColor = {
    'warning': Color(0xFFE9A23B),
    'alert': Color(0xFFE76F51),
    'info': Color(0xFF2D6A4F),
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        GovtApiService.getAdvisories(
          category: _selectedCategory,
          state: _selectedState,
        ),
        GovtApiService.getAdvisoryCategories(),
        GovtApiService.getStates(),
      ]);
      if (mounted) {
        setState(() {
        final res = futures[0] as Map<String, dynamic>;
        _advisories = List<dynamic>.from((res['data'] as List?) ?? []);
        _categories = futures[1] as List<dynamic>;
        _states = futures[2] as List<String>;
        _loading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _filter() async {
    setState(() => _loading = true);
    final res = await GovtApiService.getAdvisories(
      category: _selectedCategory,
      state: _selectedState,
    );
    if (mounted) {
      setState(() {
      _advisories = List<dynamic>.from((res['data'] as List?) ?? []);
      _loading = false;
    });
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppLang.current,
    builder: (context, _, __) => Scaffold(
      backgroundColor: const Color(0xFFFAFAF5),
      appBar: AppBar(
        title: Text(AppStrings.t('govtAdvisories'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF6B4226),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(children: [
        // Category chips
        _buildCategoryBar(),
        // State filter
        _buildStateFilter(),
        // Advisory list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B4226)))
              : _advisories.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text('📭', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      Text(AppStrings.t('noAdvisories'), style: const TextStyle(color: Color(0xFF6B7B6B))),
                    ]))
                  : RefreshIndicator(
                      onRefresh: _filter,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _advisories.length,
                        itemBuilder: (_, i) => _buildAdvisoryCard(_advisories[i]),
                      ),
                    ),
        ),
      ]),
    ),
  );

  Widget _buildCategoryBar() => Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        _catChip(null, '📋', AppStrings.t('allCategories'), null),
        ..._categories.map((c) {
          final cat = (c as Map<String, dynamic>)['category']?.toString() ?? '';
          final count = (c['count'] as num?)?.toInt() ?? 0;
          return _catChip(cat, _categoryEmoji[cat] ?? '📌', _formatCatName(cat), count);
        }),
      ]),
    ),
  );

  Widget _catChip(String? value, String emoji, String label, int? count) {
    final selected = _selectedCategory == value;
    return GestureDetector(
      onTap: () { setState(() => _selectedCategory = value); _filter(); },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6B4226) : const Color(0xFF6B4226).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : const Color(0xFF6B4226),
          )),
          if (count != null) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF6B4226).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF6B4226))),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildStateFilter() => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
    child: Row(children: [
      const Icon(Icons.location_on, size: 16, color: Color(0xFF6B7B6B)),
      const SizedBox(width: 6),
      Expanded(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _selectedState,
            hint: Text(AppStrings.t('allStates'), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B6B))),
            isExpanded: true,
            items: [
              DropdownMenuItem<String>(value: null, child: Text(AppStrings.t('allStates'), style: const TextStyle(fontSize: 12))),
              ..._states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))),
            ],
            onChanged: (v) { setState(() => _selectedState = v); _filter(); },
          ),
        ),
      ),
    ]),
  );

  Widget _buildAdvisoryCard(dynamic item) {
    final a = item as Map<String, dynamic>;
    final category = a['category']?.toString() ?? 'info';
    final severity = a['severity']?.toString() ?? 'info';
    final color = _severityColor[severity] ?? const Color(0xFF2D6A4F);
    final emoji = _categoryEmoji[category] ?? '📌';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header row
          Row(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(a['title']?.toString() ?? '',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B)))),
          ]),
          const SizedBox(height: 8),

          // Body
          Text(a['body']?.toString() ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF4A5D4A), height: 1.5)),
          const SizedBox(height: 10),

          // Footer tags
          Wrap(spacing: 6, runSpacing: 6, children: [
            _tag(Icons.source, a['source']?.toString() ?? '', const Color(0xFF264653)),
            _tag(Icons.eco, a['crop']?.toString() ?? '', const Color(0xFF2D6A4F)),
            _tag(Icons.location_on, a['state']?.toString() ?? '', const Color(0xFF6B4226)),
            _tag(Icons.warning_amber, severity.toUpperCase(), color),
          ]),

          // Published date
          if (a['published_at'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_formatDate(a['published_at'].toString()),
                style: const TextStyle(fontSize: 10, color: Color(0xFF6B7B6B))),
            ),
        ]),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: color),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    ]),
  );

  String _formatCatName(String cat) => cat.replaceAll('_', ' ').split(' ')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt);
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}
