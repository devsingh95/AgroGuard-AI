import 'package:flutter/material.dart';
import '../core/lang_provider.dart';
import '../services/govt_api_service.dart';

/// Mandi Price Screen — eNAM + Agmarknet integration
/// Shows live mandi prices, price comparison, trends, and market alerts
class MandiPriceScreen extends StatefulWidget {
  const MandiPriceScreen({super.key});
  @override
  State<MandiPriceScreen> createState() => _MandiPriceScreenState();
}

class _MandiPriceScreenState extends State<MandiPriceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<dynamic> _prices = [];
  List<dynamic> _alerts = [];
  List<dynamic> _calendar = [];
  Map<String, dynamic>? _comparison;
  List<String> _states = [];
  Map<String, dynamic> _commodities = {};
  String? _selectedState;
  String? _selectedCommodity;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final futures = await Future.wait([
        GovtApiService.getStates(),
        GovtApiService.getCommodities(),
        GovtApiService.getMandiPrices(limit: 30),
        GovtApiService.getMarketAlerts(),
        GovtApiService.getSeasonalCalendar(),
      ]);
      if (mounted) {
        setState(() {
        _states = futures[0] as List<String>;
        _commodities = futures[1] as Map<String, dynamic>;
        final priceRes = futures[2] as Map<String, dynamic>;
        _prices = List<dynamic>.from((priceRes['data'] as List?) ?? []);
        _alerts = futures[3] as List<dynamic>;
        _calendar = futures[4] as List<dynamic>;
        _loading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _filterPrices() async {
    setState(() => _loading = true);
    final res = await GovtApiService.getMandiPrices(
      state: _selectedState, commodity: _selectedCommodity, limit: 50,
    );
    if (mounted) {
      setState(() {
      _prices = List<dynamic>.from((res['data'] as List?) ?? []);
      _loading = false;
    });
    }
  }

  Future<void> _loadComparison(String commodity) async {
    final res = await GovtApiService.getMandiComparison(commodity);
    if (mounted) setState(() => _comparison = res);
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppLang.current,
    builder: (context, _, __) => Scaffold(
      backgroundColor: const Color(0xFFFAFAF5),
      appBar: AppBar(
        title: Text(AppStrings.t('mandiPrices'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF2D6A4F),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: AppStrings.t('liveprices'), icon: const Icon(Icons.trending_up, size: 18)),
            Tab(text: AppStrings.t('marketAlerts'), icon: const Icon(Icons.notifications_active, size: 18)),
            Tab(text: AppStrings.t('seasonalGuide'), icon: const Icon(Icons.calendar_month, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildPricesTab(), _buildAlertsTab(), _buildCalendarTab()],
      ),
    ),
  );

  // ── Tab 1: Live Prices ─────────────────────────────────────────────────

  Widget _buildPricesTab() => Column(children: [
    // Filter bar
    Container(
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Row(children: [
        Expanded(child: _buildDropdown(
          value: _selectedState,
          hint: AppStrings.t('selectState'),
          items: _states,
          onChanged: (v) { setState(() => _selectedState = v); _filterPrices(); },
        )),
        const SizedBox(width: 10),
        Expanded(child: _buildDropdown(
          value: _selectedCommodity,
          hint: AppStrings.t('selectCrop'),
          items: _commodities.keys.toList(),
          onChanged: (v) {
            setState(() => _selectedCommodity = v);
            _filterPrices();
            if (v != null) _loadComparison(v);
          },
        )),
        const SizedBox(width: 8),
        if (_selectedState != null || _selectedCommodity != null)
          IconButton(
            icon: const Icon(Icons.clear, size: 20),
            onPressed: () {
              setState(() { _selectedState = null; _selectedCommodity = null; _comparison = null; });
              _filterPrices();
            },
          ),
      ]),
    ),

    // Comparison card
    if (_comparison != null && _comparison!['stats'] != null) _buildComparisonCard(),

    // Price list
    Expanded(
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF2D6A4F)))
          : _prices.isEmpty
              ? Center(child: Text(AppStrings.t('noData'), style: const TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: _filterPrices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: _prices.length,
                    itemBuilder: (_, i) => _buildPriceCard(_prices[i]),
                  ),
                ),
    ),
  ]);

  Widget _buildComparisonCard() {
    final stats = _comparison!['stats'] as Map<String, dynamic>;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF264653), Color(0xFF2A9D8F)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${_comparison!['commodity']} — ${AppStrings.t('priceOverview')}',
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(children: [
          _statBubble('${AppStrings.t('avg')}\n₹${stats['avg_price']}'),
          _statBubble('${AppStrings.t('highest')}\n₹${stats['highest']}'),
          _statBubble('${AppStrings.t('lowest')}\n₹${stats['lowest']}'),
          if (stats['msp'] != null && (stats['msp'] as num) > 0)
            _statBubble('MSP\n₹${stats['msp']}'),
        ]),
        if (stats['above_msp_pct'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${stats['above_msp_pct']}% ${AppStrings.t('aboveMSP')}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ),
      ]),
    );
  }

  Widget _statBubble(String text) => Expanded(
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Text(text, textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
    ),
  );

  Widget _buildPriceCard(dynamic item) {
    final p = item as Map<String, dynamic>;
    final modal = (p['modal_price'] as num?)?.toDouble() ?? 0;
    final msp = (p['msp'] as num?)?.toDouble() ?? 0;
    final aboveMsp = msp > 0 && modal >= msp;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: aboveMsp
            ? const Color(0xFF2D6A4F).withValues(alpha: 0.2)
            : const Color(0xFFE76F51).withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(p['commodity']?.toString() ?? '',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B)))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: aboveMsp ? const Color(0xFF2D6A4F).withValues(alpha: 0.1) : const Color(0xFFE76F51).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(aboveMsp ? '↑ ${AppStrings.t('aboveMSP')}' : '↓ ${AppStrings.t('belowMSP')}',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                color: aboveMsp ? const Color(0xFF2D6A4F) : const Color(0xFFE76F51))),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.location_on, size: 13, color: Color(0xFF6B7B6B)),
          const SizedBox(width: 4),
          Text('${p['mandi']}, ${p['state']}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B6B))),
        ]),
        const Divider(height: 16),
        Row(children: [
          _priceLabel(AppStrings.t('minPrice'), '₹${p['min_price']}'),
          _priceLabel(AppStrings.t('modalPrice'), '₹${p['modal_price']}'),
          _priceLabel(AppStrings.t('maxPrice'), '₹${p['max_price']}'),
          if (msp > 0) _priceLabel('MSP', '₹$msp'),
        ]),
        if (p['arrival_qty'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${AppStrings.t('arrival')}: ${p['arrival_qty']} Qt',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7B6B))),
          ),
      ]),
    );
  }

  Widget _priceLabel(String label, String value) => Expanded(child: Column(children: [
    Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7B6B))),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
  ]));

  // ── Tab 2: Market Alerts ───────────────────────────────────────────────

  Widget _buildAlertsTab() => _alerts.isEmpty
      ? Center(child: Text(AppStrings.t('noAlerts'), style: const TextStyle(color: Colors.grey)))
      : ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: _alerts.length,
          itemBuilder: (_, i) => _buildAlertCard(_alerts[i]),
        );

  Widget _buildAlertCard(dynamic item) {
    final a = item as Map<String, dynamic>;
    final severity = a['severity']?.toString() ?? 'info';
    final color = severity == 'critical' ? const Color(0xFFE76F51)
        : severity == 'high' ? const Color(0xFFE9A23B)
        : severity == 'medium' ? const Color(0xFF264653)
        : const Color(0xFF2D6A4F);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(a['commodity']?.toString() ?? '',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B)))),
        ]),
        const SizedBox(height: 8),
        Text(a['message']?.toString() ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF4A5D4A), height: 1.4)),
      ]),
    );
  }

  // ── Tab 3: Seasonal Calendar ───────────────────────────────────────────

  Widget _buildCalendarTab() => _calendar.isEmpty
      ? Center(child: Text(AppStrings.t('noData')))
      : ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: _calendar.length,
          itemBuilder: (_, i) {
            final c = _calendar[i] as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Text('🌾', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(c['commodity']?.toString() ?? '',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B)))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF2D6A4F).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(c['season']?.toString() ?? '',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF2D6A4F))),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _seasonInfo('📈', '${AppStrings.t('bestSell')}:', (c['best_sell_months'] as List?)?.join(', ') ?? '', const Color(0xFF2D6A4F))),
                  const SizedBox(width: 10),
                  Expanded(child: _seasonInfo('📉', '${AppStrings.t('bestBuy')}:', (c['best_buy_months'] as List?)?.join(', ') ?? '', const Color(0xFFE76F51))),
                ]),
              ]),
            );
          },
        );

  Widget _seasonInfo(String emoji, String label, String months, Color color) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(10)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ]),
      const SizedBox(height: 4),
      Text(months, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
    ]),
  );

  // ── Shared widgets ─────────────────────────────────────────────────────

  Widget _buildDropdown({String? value, required String hint, required List<String> items, required ValueChanged<String?> onChanged}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7B6B))),
            isExpanded: true,
            items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
          ),
        ),
      );
}
