import 'package:flutter/material.dart';
import 'dart:js' as js;
import '../core/lang_provider.dart';
import '../services/govt_api_service.dart';

/// PMFBY Insurance Screen — Premium Calculator + Claim Status
class InsuranceScreen extends StatefulWidget {
  const InsuranceScreen({super.key});
  @override
  State<InsuranceScreen> createState() => _InsuranceScreenState();
}

class _InsuranceScreenState extends State<InsuranceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Calculator state
  String _season = 'Kharif';
  String? _crop;
  final _areaCtrl = TextEditingController(text: '1');
  Map<String, dynamic>? _premium;
  Map<String, dynamic>? _cropsData;
  bool _calcLoading = false;

  // Status checker state
  final _appIdCtrl = TextEditingController();
  Map<String, dynamic>? _claimStatus;
  bool _statusLoading = false;

  // Deadlines
  Map<String, dynamic>? _deadlines;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadCrops();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _areaCtrl.dispose();
    _appIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCrops() async {
    final res = await Future.wait([
      GovtApiService.getInsurableCrops(),
      GovtApiService.getInsuranceDeadlines(),
    ]);
    if (mounted) {
      setState(() {
      _cropsData = res[0]['crops'] as Map<String, dynamic>?;
      _deadlines = res[1]['deadlines'] as Map<String, dynamic>?;
    });
    }
  }

  Future<void> _calculatePremium() async {
    if (_crop == null) return;
    setState(() => _calcLoading = true);
    final res = await GovtApiService.calculatePremium(
      season: _season, crop: _crop!, areaHectares: double.tryParse(_areaCtrl.text) ?? 1,
    );
    if (mounted) setState(() { _premium = res; _calcLoading = false; });
  }

  Future<void> _checkStatus() async {
    if (_appIdCtrl.text.isEmpty) return;
    setState(() => _statusLoading = true);
    final res = await GovtApiService.checkClaimStatus(_appIdCtrl.text.trim());
    if (mounted) setState(() { _claimStatus = res; _statusLoading = false; });
  }

  List<String> get _seasonCrops {
    if (_cropsData == null) return [];
    final seasonData = _cropsData![_season] as List<dynamic>?;
    return seasonData?.map((c) => (c as Map<String, dynamic>)['crop']?.toString() ?? '').toList() ?? [];
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: AppLang.current,
    builder: (context, _, __) => Scaffold(
      backgroundColor: const Color(0xFFFAFAF5),
      appBar: AppBar(
        title: Text(AppStrings.t('cropInsurance'), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFE76F51),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: [
            Tab(text: AppStrings.t('calculator'), icon: const Icon(Icons.calculate, size: 18)),
            Tab(text: AppStrings.t('claimStatus'), icon: const Icon(Icons.track_changes, size: 18)),
            Tab(text: AppStrings.t('deadlines'), icon: const Icon(Icons.event, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildCalculator(), _buildStatusChecker(), _buildDeadlines()],
      ),
    ),
  );

  // ── Tab 1: Premium Calculator ──────────────────────────────────────────

  Widget _buildCalculator() => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Info banner
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFE76F51), Color(0xFFE9A23B)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Text('🛡️', style: TextStyle(fontSize: 32)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(AppStrings.t('pmfbyCalc'),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            Text(AppStrings.t('pmfbyCalcSub'),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
          ])),
        ]),
      ),
      const SizedBox(height: 20),

      // Season selector
      _label(AppStrings.t('selectSeason')),
      Row(children: [
        _seasonChip('Kharif', '☔', 'Jun-Oct'),
        const SizedBox(width: 10),
        _seasonChip('Rabi', '❄️', 'Nov-Mar'),
      ]),
      const SizedBox(height: 16),

      // Crop selector
      _label(AppStrings.t('selectCrop')),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE76F51).withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: _crop,
            hint: Text(AppStrings.t('selectCrop'), style: const TextStyle(fontSize: 13)),
            isExpanded: true,
            items: _seasonCrops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _crop = v),
          ),
        ),
      ),
      const SizedBox(height: 16),

      // Area
      _label(AppStrings.t('areaHectares')),
      TextFormField(
        controller: _areaCtrl,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          hintText: '1.0',
          prefixIcon: const Icon(Icons.landscape, color: Color(0xFFE76F51), size: 20),
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFFE76F51).withValues(alpha: 0.2))),
        ),
      ),
      const SizedBox(height: 24),

      // Calculate button
      SizedBox(
        width: double.infinity, height: 50,
        child: ElevatedButton(
          onPressed: _calcLoading ? null : _calculatePremium,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE76F51),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: _calcLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.calculate, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(AppStrings.t('calculatePremium'), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ]),
        ),
      ),

      // Results
      if (_premium != null) ...[
        const SizedBox(height: 20),
        _buildPremiumResult(),
      ],
    ]),
  );

  Widget _buildPremiumResult() {
    if (_premium!['success'] != true) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(14)),
        child: Text(_premium!['error']?.toString() ?? 'Error', style: const TextStyle(color: Colors.red)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🧮', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(AppStrings.t('premiumBreakdown'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
        ]),
        const Divider(height: 24),

        _resultRow(AppStrings.t('crop'), _premium!['crop']?.toString() ?? ''),
        _resultRow(AppStrings.t('season'), _premium!['season']?.toString() ?? ''),
        _resultRow(AppStrings.t('area'), '${_premium!['area_hectares']} ${AppStrings.t('hectares')}'),
        _resultRow(AppStrings.t('sumInsured'), '₹${_formatNum(_premium!['total_sum_insured'])}'),
        const Divider(height: 16),

        // Highlight: farmer premium
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF2D6A4F), Color(0xFF40916C)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Text(AppStrings.t('youPay'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
            const SizedBox(height: 4),
            Text('₹${_formatNum(_premium!['farmer_premium'])}',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
            Text('(${_premium!['farmer_premium_rate']})',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),

        _resultRow(AppStrings.t('govtPays'), '₹${_formatNum(_premium!['government_subsidy'])}'),
        _resultRow(AppStrings.t('govtSubsidy'), '${_premium!['govt_subsidy_percentage']}%'),
        _resultRow(AppStrings.t('enrollBy'), _premium!['deadline']?.toString() ?? ''),

        if (_premium!['note'] != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2D6A4F).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              const Text('💡', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(_premium!['note'].toString(),
                style: const TextStyle(fontSize: 12, color: Color(0xFF2D6A4F), fontWeight: FontWeight.w600))),
            ]),
          ),
        ],

        // Portal links for PMFBY
        if (_premium!['portal_links'] != null) ...[
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => js.context.callMethod('open', [
                (_premium!['portal_links'] as Map)['premium_calculator']?.toString() ?? 'https://pmfby.gov.in/premiumCalculator',
                '_blank']),
              icon: const Icon(Icons.calculate, size: 14),
              label: const Text('PMFBY Calculator', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE76F51),
                side: const BorderSide(color: Color(0xFFE76F51)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => js.context.callMethod('open', [
                (_premium!['portal_links'] as Map)['enroll_online']?.toString() ?? 'https://pmfby.gov.in',
                '_blank']),
              icon: const Icon(Icons.open_in_new, size: 14),
              label: const Text('Enroll Online', style: TextStyle(fontSize: 11)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE76F51),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            )),
          ]),
        ],
      ]),
    );
  }

  Widget _resultRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7B6B))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
    ]),
  );

  // ── Tab 2: Claim Status ────────────────────────────────────────────────

  Widget _buildStatusChecker() => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(AppStrings.t('applicationId')),
      Row(children: [
        Expanded(child: TextFormField(
          controller: _appIdCtrl,
          decoration: InputDecoration(
            hintText: 'e.g., PMFBY2024KH00123',
            prefixIcon: const Icon(Icons.confirmation_number, color: Color(0xFFE76F51), size: 20),
            filled: true, fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFFE76F51).withValues(alpha: 0.2))),
          ),
        )),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: _statusLoading ? null : _checkStatus,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE76F51),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          child: _statusLoading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(AppStrings.t('check'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ]),

      if (_claimStatus != null) ...[
        const SizedBox(height: 20),
        _buildClaimCard(),
      ],
    ]),
  );

  Widget _buildClaimCard() {
    final status = _claimStatus!['status']?.toString() ?? 'Unknown';
    final isApproved = status.contains('Approved') || status.contains('Disbursed');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isApproved
            ? const Color(0xFF2D6A4F).withValues(alpha: 0.2)
            : const Color(0xFFE9A23B).withValues(alpha: 0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isApproved ? const Color(0xFF2D6A4F) : const Color(0xFFE9A23B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ]),
        const Divider(height: 24),
        _resultRow(AppStrings.t('crop'), _claimStatus!['crop']?.toString() ?? ''),
        _resultRow(AppStrings.t('season'), _claimStatus!['season']?.toString() ?? ''),
        _resultRow(AppStrings.t('area'), '${_claimStatus!['area_hectares']} ha'),
        _resultRow(AppStrings.t('sumInsured'), '₹${_formatNum(_claimStatus!['sum_insured'])}'),
        _resultRow(AppStrings.t('premiumPaid'), '₹${_formatNum(_claimStatus!['premium_paid'])}'),
        _resultRow(AppStrings.t('insurer'), _claimStatus!['insurance_company']?.toString() ?? ''),
        if ((_claimStatus!['claim_amount'] as num?) != null && (_claimStatus!['claim_amount'] as num) > 0)
          _resultRow(AppStrings.t('claimAmount'), '₹${_formatNum(_claimStatus!['claim_amount'])}'),

        // Timeline
        if (_claimStatus!['timeline'] != null) ...[
          const SizedBox(height: 16),
          Text(AppStrings.t('timeline'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
          const SizedBox(height: 8),
          ...List<dynamic>.from((_claimStatus!['timeline'] as List?) ?? []).map((t) {
            final step = t as Map<String, dynamic>;
            final completed = step['status'] == 'completed';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 16, color: completed ? const Color(0xFF2D6A4F) : Colors.grey),
                const SizedBox(width: 10),
                Expanded(child: Text(step['event']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF1B2A1B)))),
                Text(step['date']?.toString() ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7B6B))),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  // ── Tab 3: Deadlines ───────────────────────────────────────────────────

  Widget _buildDeadlines() => _deadlines == null
      ? const Center(child: CircularProgressIndicator(color: Color(0xFFE76F51)))
      : ListView(
          padding: const EdgeInsets.all(18),
          children: _deadlines!.entries.map((e) {
            final season = e.key;
            final info = e.value as Map<String, dynamic>;
            final emoji = season == 'Kharif' ? '☔' : '❄️';
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(emoji, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Text('$season ${AppStrings.t('season')}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1B2A1B))),
                ]),
                const Divider(height: 20),
                _deadlineRow(Icons.play_arrow, AppStrings.t('enrollStart'), info['enrollment_start']?.toString() ?? ''),
                _deadlineRow(Icons.flag, AppStrings.t('enrollEnd'), info['enrollment_end']?.toString() ?? ''),
                _deadlineRow(Icons.date_range, AppStrings.t('seasonPeriod'), info['season_period']?.toString() ?? ''),
              ]),
            );
          }).toList(),
        );

  Widget _deadlineRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16, color: const Color(0xFFE76F51)),
      const SizedBox(width: 10),
      Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7B6B))),
      const Spacer(),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
    ]),
  );

  // ── Shared helpers ─────────────────────────────────────────────────────

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
  );

  Widget _seasonChip(String season, String emoji, String period) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() { _season = season; _crop = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _season == season ? const Color(0xFFE76F51) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE76F51).withValues(alpha: 0.3)),
        ),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(season, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: _season == season ? Colors.white : const Color(0xFF1B2A1B),
          )),
          Text(period, style: TextStyle(fontSize: 10,
            color: _season == season ? Colors.white70 : const Color(0xFF6B7B6B),
          )),
        ]),
      ),
    ),
  );

  String _formatNum(dynamic value) {
    if (value == null) return '0';
    final n = double.tryParse(value.toString()) ?? 0;
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}
