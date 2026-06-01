import 'dart:math';
import 'package:flutter/material.dart';
import '../core/lang_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Home Screen – Emotionally-Connected Farming Theme with Animations
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _heroController;
  late AnimationController _cardsController;
  late AnimationController _floatingController;
  late Animation<double> _heroFade;
  late Animation<Offset> _heroSlide;
  late List<Animation<double>> _cardFades;
  late List<Animation<Offset>> _cardSlides;

  @override
  void initState() {
    super.initState();

    // Hero entrance animation
    _heroController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroFade = CurvedAnimation(parent: _heroController, curve: Curves.easeOut);
    _heroSlide = Tween<Offset>(begin: const Offset(0, -0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _heroController, curve: Curves.easeOutCubic));

    // Staggered card entrance
    _cardsController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _cardFades = List.generate(5, (i) {
      final start = 0.12 * i;
      final end = (start + 0.35).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _cardsController, curve: Interval(start, end, curve: Curves.easeOut)),
      );
    });
    _cardSlides = List.generate(5, (i) {
      final start = 0.15 * i;
      final end = (start + 0.4).clamp(0.0, 1.0);
      return Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _cardsController, curve: Interval(start, end, curve: Curves.easeOutCubic)),
      );
    });

    // Continuous floating animation for decorative elements
    _floatingController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);

    _heroController.forward();
    Future.delayed(const Duration(milliseconds: 400), () => _cardsController.forward());
  }

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
      valueListenable: AppLang.current,
      builder: (context, _, __) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isWide = screenWidth > 700;

        return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF0F7EE), Color(0xFFFAFAF5), Color(0xFFF5F0E8)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Floating decorative leaves
          ..._buildFloatingElements(),
          // Main content
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(isWide, context),
              SliverToBoxAdapter(child: _buildBody(context, isWide)),
            ],
          ),
        ],
      ),
        );
      },
    );

  List<Widget> _buildFloatingElements() {
    final items = [
      _FloatingLeaf(icon: '🌿', top: 120, right: 20, controller: _floatingController, delay: 0),
      _FloatingLeaf(icon: '🍃', top: 300, left: 10, controller: _floatingController, delay: 0.3),
      _FloatingLeaf(icon: '🌾', top: 500, right: 30, controller: _floatingController, delay: 0.6),
      _FloatingLeaf(icon: '☘️', top: 680, left: 25, controller: _floatingController, delay: 0.15),
    ];
    return items;
  }

  Widget _buildSliverAppBar(bool isWide, BuildContext context) => SliverAppBar(
    expandedHeight: isWide ? 240 : 210,
    floating: false,
    pinned: true,
    stretch: true,
    backgroundColor: const Color(0xFF2D6A4F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
    ),
    flexibleSpace: FlexibleSpaceBar(
      background: FadeTransition(
        opacity: _heroFade,
        child: SlideTransition(
          position: _heroSlide,
          child: Container(
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
              ),
            ),
            child: Stack(
              children: [
                // Subtle pattern overlay
                Positioned.fill(
                  child: CustomPaint(painter: _FieldPatternPainter()),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24, isWide ? 80 : 70, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const _CoderPiratesLogo(size: 52),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.t('appName'),
                                  style: const TextStyle(
                                    fontSize: 26, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  AppStrings.t('byCoderPirates'),
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500,
                                    color: Color(0xAAFFFFFF), letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppStrings.t('tagline'),
                                  style: const TextStyle(
                                    fontSize: 13, color: Color(0xCCFFFFFF),
                                    fontWeight: FontWeight.w400, letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9C46A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE9C46A).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('☀️', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              AppStrings.t('motto'),
                              style: const TextStyle(fontSize: 12, color: Color(0xFFE9C46A), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _CoderPiratesLogo(size: 26),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            AppStrings.t('appBarTitle'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    actions: [
      ValueListenableBuilder<String>(
        valueListenable: AppLang.current,
        builder: (_, lang, __) {
          final langMeta = AppLang.languages.firstWhere(
            (l) => l['code'] == lang, orElse: () => AppLang.languages[0]);
          return TextButton(
            onPressed: () => showLanguagePicker(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(langMeta['flag']!, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
              ],
            ),
          );
        },
      ),
      const SizedBox(width: 4),
    ],
  );

  Widget _buildBody(BuildContext context, bool isWide) => Padding(
    padding: EdgeInsets.symmetric(horizontal: isWide ? 32 : 18, vertical: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick stats row
        _buildQuickStats(),
        const SizedBox(height: 28),

        // Section header
        Row(
          children: [
            Container(
              width: 4, height: 22,
              decoration: BoxDecoration(color: const Color(0xFF2D6A4F), borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 10),
            Text(AppStrings.t('smartTools'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(AppStrings.t('features'), style: const TextStyle(fontSize: 11, color: Color(0xFF2D6A4F), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Feature cards grid
        GridView.count(
          crossAxisCount: isWide ? 5 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: isWide ? 1.1 : 0.9,
          children: [
            _buildAnimatedCard(0, icon: Icons.agriculture, emoji: '🌾',
              title: AppStrings.t('cropAdvisor'), subtitle: AppStrings.t('cropAdvisorSub'),
              gradient: const [Color(0xFF2D6A4F), Color(0xFF40916C)], route: '/crop'),
            _buildAnimatedCard(1, icon: Icons.biotech, emoji: '🔬',
              title: AppStrings.t('diseaseDetector'), subtitle: AppStrings.t('diseaseDetectorSub'),
              gradient: const [Color(0xFFE76F51), Color(0xFFE9A23B)], route: '/disease'),
            _buildAnimatedCard(2, icon: Icons.sensors, emoji: '📡',
              title: AppStrings.t('fieldMonitor'), subtitle: AppStrings.t('fieldMonitorSub'),
              gradient: const [Color(0xFF264653), Color(0xFF2A9D8F)], route: '/sensors'),
            _buildAnimatedCard(3, icon: Icons.account_balance, emoji: '🏛️',
              title: AppStrings.t('govtServices'), subtitle: AppStrings.t('govtServicesSub'),
              gradient: const [Color(0xFF1B4332), Color(0xFF2D6A4F)], route: '/govt'),
            _buildAnimatedCard(4, icon: Icons.eco, emoji: '🌍',
              title: AppStrings.t('ecoGuardian'), subtitle: AppStrings.t('ecoGuardianSub'),
              gradient: const [Color(0xFF6B4226), Color(0xFFD4A373)], route: '/sensors'),
          ],
        ),

        const SizedBox(height: 32),

        // About section
        _buildAboutSection(),

        const SizedBox(height: 24),

        // Footer
        Center(
          child: Column(
            children: [
              Container(
                width: 40, height: 3,
                decoration: BoxDecoration(color: const Color(0xFF2D6A4F).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.t('version'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4A5D4A)),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.t('copyright'),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildQuickStats() => AnimatedBuilder(
    animation: _heroFade,
    builder: (_, __) => Opacity(
      opacity: _heroFade.value,
      child: Row(
        children: [
          _quickStatChip('🤖', AppStrings.t('aiPowered')),
          const SizedBox(width: 8),
          _quickStatChip('📊', AppStrings.t('realTime')),
          const SizedBox(width: 8),
          _quickStatChip('🌿', AppStrings.t('organicTips')),
        ],
      ),
    ),
  );

  Widget _quickStatChip(String emoji, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: const Color(0xFF2D6A4F).withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1B2A1B)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    ),
  );

  Widget _buildAnimatedCard(int index, {
    required IconData icon, required String emoji,
    required String title, required String subtitle,
    required List<Color> gradient, required String route,
  }) => AnimatedBuilder(
    animation: _cardsController,
    builder: (_, child) => FadeTransition(
      opacity: _cardFades[index],
      child: SlideTransition(position: _cardSlides[index], child: child),
    ),
    child: _FeatureCard(
      icon: icon, emoji: emoji, title: title,
      subtitle: subtitle, gradient: gradient, route: route,
    ),
  );

  Widget _buildAboutSection() => AnimatedBuilder(
    animation: _heroFade,
    builder: (_, __) => Opacity(
      opacity: _heroFade.value,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF2D6A4F).withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(color: const Color(0xFF2D6A4F).withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2D6A4F).withValues(alpha: 0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  const Text('🌻', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Text(AppStrings.t('aboutTitle'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1B2A1B))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _aboutItem(Icons.psychology, AppStrings.t('about1')),
                  _aboutItem(Icons.camera_alt, AppStrings.t('about2')),
                  _aboutItem(Icons.sensors, AppStrings.t('about3')),
                  _aboutItem(Icons.eco, AppStrings.t('about4')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _aboutItem(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF2D6A4F).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF2D6A4F)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF4A5D4A), height: 1.4))),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Feature Card with hover/tap scale animation
// ─────────────────────────────────────────────────────────────────────────────

class _FeatureCard extends StatefulWidget {
  final IconData icon;
  final String emoji, title, subtitle, route;
  final List<Color> gradient;

  const _FeatureCard({
    required this.icon, required this.emoji, required this.title,
    required this.subtitle, required this.gradient, required this.route,
  });

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1, end: 0.96).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => _hoverController.forward(),
    onExit: (_) => _hoverController.reverse(),
    child: GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) { _hoverController.reverse(); Navigator.pushNamed(context, widget.route); },
      onTapCancel: () => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.gradient,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.last.withValues(alpha: 0.35),
                blurRadius: 14, offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Background icon watermark
              Positioned(
                right: -10, bottom: -10,
                child: Icon(widget.icon, size: 70, color: Colors.white.withValues(alpha: 0.08)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(widget.emoji, style: const TextStyle(fontSize: 24)),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.2,
                        )),
                        const SizedBox(height: 4),
                        Text(widget.subtitle, style: TextStyle(
                          fontSize: 10, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.w400,
                        )),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Positioned(
                right: 10, top: 10,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Leaf Decoration (ambient animation)
// ─────────────────────────────────────────────────────────────────────────────

class _FloatingLeaf extends StatelessWidget {
  final String icon;
  final double? top, left, right;
  final AnimationController controller;
  final double delay;

  const _FloatingLeaf({
    required this.icon, this.top, this.left, this.right,
    required this.controller, required this.delay,
  });

  @override
  Widget build(BuildContext context) => Positioned(
    top: top, left: left, right: right,
    child: AnimatedBuilder(
      animation: controller,
      builder: (_, child) {
        final t = (controller.value + delay) % 1.0;
        final yOffset = sin(t * 2 * pi) * 12;
        final rotation = sin(t * 2 * pi) * 0.15;
        return Transform.translate(
          offset: Offset(0, yOffset),
          child: Transform.rotate(angle: rotation, child: child),
        );
      },
      child: Opacity(
        opacity: 0.12,
        child: Text(icon, style: const TextStyle(fontSize: 32)),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// AgroGuard Logo Widget – Shield + Leaf motif, no image file required
// ─────────────────────────────────────────────────────────────────────────────

class _CoderPiratesLogo extends StatelessWidget {
  final double size;
  const _CoderPiratesLogo({this.size = 40});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFF95D5B2), width: size * 0.035),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D6A4F).withValues(alpha: 0.45),
            blurRadius: size * 0.3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - size * 0.035),
        child: CustomPaint(
          size: Size(size, size),
          painter: _AgroLogoInnerPainter(),
          child: Center(
            child: Text(
              '🌿',
              style: TextStyle(fontSize: size * 0.48, height: 1),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws subtle leaf-vein / shield patterns inside the logo
class _AgroLogoInnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Subtle radial glow at centre
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF52B788).withValues(alpha: 0.25),
          const Color(0xFF52B788).withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(w / 2, h / 2), radius: w * 0.45));
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.45, glowPaint);

    // Thin arc lines (like a shield emblem)
    final arcPaint = Paint()
      ..color = const Color(0xFF95D5B2).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.15 * i, arcPaint);
    }

    // Small corner leaf accents
    final dotPaint = Paint()..color = const Color(0xFF95D5B2).withValues(alpha: 0.35);
    final dotR = w * 0.04;
    canvas.drawCircle(Offset(w * 0.18, h * 0.18), dotR, dotPaint);
    canvas.drawCircle(Offset(w * 0.82, h * 0.18), dotR, dotPaint);
    canvas.drawCircle(Offset(w * 0.18, h * 0.82), dotR, dotPaint);
    canvas.drawCircle(Offset(w * 0.82, h * 0.82), dotR, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Subtle field-pattern painter for hero background
// ─────────────────────────────────────────────────────────────────────────────

class _FieldPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Curved farming-field lines
    for (var i = 0; i < 6; i++) {
      final path = Path();
      final y = size.height * 0.3 + (i * 20.0);
      path.moveTo(0, y);
      path.quadraticBezierTo(size.width * 0.3, y - 15, size.width * 0.6, y + 10);
      path.quadraticBezierTo(size.width * 0.8, y + 20, size.width, y - 5);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
