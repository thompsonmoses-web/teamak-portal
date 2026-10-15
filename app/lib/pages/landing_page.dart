import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/hover_card.dart';
import '../widgets/shell.dart';
import '../widgets/showcase_slideshow.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  late final ApiClient _api;
  List<Programme> _programmes = const <Programme>[];
  bool _loading = true;
  bool _showPromoPopup = false;
  Timer? _promoTimer;

  @override
  void initState() {
    super.initState();
    _api = ApiClient();
    _load();
    _promoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showPromoPopup = true);
    });
  }

  @override
  void dispose() {
    // Without this the delayed pop-up outlives the page and keeps a timer
    // pending against the disposed widget tree.
    _promoTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final programmes = await _api.fetchProgrammes();
      if (mounted) setState(() => _programmes = programmes);
    } catch (_) {
      // Keep the static fallback tiers below.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Programme> get _tiers => _programmes.isNotEmpty
      ? _programmes
      : const <Programme>[
          Programme(
            id: 'okada_650',
            label: 'OKADA OWNERSHIP',
            depositNgn: 650000,
            months: 3,
            asset: '1 brand-new Bajaj motorcycle',
            summary: '₦650,000 one-time deposit → 3 months → brand-new Bajaj.',
          ),
          Programme(
            id: 'okada_400',
            label: 'OKADA OWNERSHIP',
            depositNgn: 400000,
            months: 6,
            asset: '1 brand-new Bajaj motorcycle',
            summary: '₦400,000 one-time deposit → 6 months → brand-new Bajaj.',
          ),
          Programme(
            id: 'maruwa_2300',
            label: 'MARUWA OWNERSHIP',
            depositNgn: 2300000,
            months: 3,
            asset: '1 Bajaj/approved Maruwa tricycle',
            summary: '₦2,300,000 one-time deposit → 3 months → approved Maruwa.',
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;
    final now = DateTime.now();
    // Promo ends 20 December midnight.
    final promoEnd = DateTime(now.year, 12, 20);

    return AppShell(
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              _Hero(wide: wide),
              const SizedBox(height: 28),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 12),
                child: const ShowcaseSlideshow(),
              ),
              const SizedBox(height: 32),
              // Bike promo split banner.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16),
                child: _VehiclePromoBanner(
                  wide: wide,
                  asset: 'assets/slides/motorcycle.png',
                  badge: 'HOT DEAL',
                  badgeGradient: const <Color>[Color(0xFFE53935), Color(0xFFFF7043)],
                  badgeShadow: const Color(0xFFE53935),
                  title: 'BAJAJ BOXER — LIMITED PROMO',
                  headline: 'Own a brand-new Bajaj Boxer\nfrom just ₦400,000',
                  mobileHeadline: 'Own a brand-new Bajaj Boxer from just ₦400,000',
                  benefits: '6-month instalment plan · One-time deposit · Free rider training',
                  mobileBenefits: '6-month plan · One-time deposit · Free training',
                  slots: '⚡ Only 12 slots left',
                  mobileSlots: '⚡ Only 12 slots left this month',
                  deadline: promoEnd,
                ),
              ),
              const SizedBox(height: 20),
              // Tricycle promo.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16),
                child: _VehiclePromoBanner(
                  wide: wide,
                  asset: 'assets/slides/tricycle.png',
                  badge: 'POPULAR',
                  badgeGradient: const <Color>[Color(0xFF00897B), Color(0xFF26A69A)],
                  badgeShadow: const Color(0xFF00897B),
                  title: 'BAJAJ TRICYCLE — FAMILY & BUSINESS',
                  headline: 'Own a Bajaj tricycle\nfrom just ₦450,000',
                  mobileHeadline: 'Own a Bajaj tricycle from just ₦450,000',
                  benefits: '6-month instalment plan · High earning capacity · Free maintenance training',
                  mobileBenefits: '6-month plan · High earnings · Free training',
                  slots: '⚡ Only 10 slots left',
                  mobileSlots: '⚡ Only 10 slots left this month',
                  deadline: promoEnd,
                ),
              ),
              const SizedBox(height: 20),
              // Sun King solar promo.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16),
                child: _VehiclePromoBanner(
                  wide: wide,
                  asset: 'assets/slides/solar.png',
                  badge: 'ECO FRIENDLY',
                  badgeGradient: const <Color>[Color(0xFF2E7D32), Color(0xFF66BB6A)],
                  badgeShadow: const Color(0xFF2E7D32),
                  title: 'SUN KING SOLAR — GO GREEN',
                  headline: 'Sun King solar home system\nfrom just ₦50,000',
                  mobileHeadline: 'Sun King solar home system from just ₦50,000',
                  benefits: 'Solar panel · LED lights · Phone charging · TV support',
                  mobileBenefits: 'Panel · LED lights · Charging · TV',
                  slots: '⚡ Limited stock available',
                  mobileSlots: '⚡ Limited stock available',
                  deadline: promoEnd,
                ),
              ),
              const SizedBox(height: 48),
              // Stats counters.
              Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 16),
                child: const _StatsCounter(),
              ),
              const SizedBox(height: 48),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const _SectionHeader(
                  title: 'Choose your ownership programme',
                  subtitle: 'One-time programme deposit. No further vehicle payment '
                      'under the stated ownership offer, subject to approval and '
                      'the final agreement.',
                ),
                const SizedBox(height: 28),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      for (var i = 0; i < _tiers.length; i++)
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: 1),
                          duration: Duration(milliseconds: 350 + (i * 80)),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(
                              offset: Offset(0, 24 * (1 - t)),
                              child: child,
                            ),
                          ),
                          child: SizedBox(
                            width: wide
                                ? (width - 96 - 40) / 3
                                : width - 40,
                            child: _TierCard(programme: _tiers[i]),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 52),
                const _SectionHeader(
                  title: 'Our global services',
                  subtitle: 'Beyond rider ownership, Teamak Global Solutions delivers '
                      'end-to-end services across mobility, energy, trade and '
                      'enterprise support.',
                ),
                const SizedBox(height: 28),
                _GlobalServices(wide: wide),
                const SizedBox(height: 52),
                const _SectionHeader(
                  title: 'How it works',
                  subtitle: 'Four simple steps from application to ownership.',
                ),
                const SizedBox(height: 24),
                _HowItWorks(wide: wide),
                const SizedBox(height: 52),
                // Trust badges strip.
                const _TrustBadges(),
                const SizedBox(height: 52),
                // Earnings calculator.
                const _SectionHeader(
                  title: 'See what you could earn',
                  subtitle: 'Estimate your weekly income with a Teamak vehicle.',
                ),
                const SizedBox(height: 24),
                const _EarningsCalculator(),
                const SizedBox(height: 52),
                // After-sales support.
                const _SectionHeader(
                  title: 'We\'ve got your back',
                  subtitle: 'Support doesn\'t stop at delivery — we\'re with you long after.',
                ),
                const SizedBox(height: 24),
                _AfterSalesSupport(wide: wide),
                const SizedBox(height: 52),
                const _SectionHeader(
                  title: 'What our riders say',
                  subtitle: 'Real stories from riders who own their vehicles through Teamak.',
                ),
                const SizedBox(height: 24),
                const _Testimonials(),
                const SizedBox(height: 52),
                _CallToAction(wide: wide),
                const SizedBox(height: 48),
              ],
            ),
          ),
          const _Footer(),
            ],
          ),
          // Promo pop-up overlay.
          if (_showPromoPopup)
            _PromoPopup(
              onClose: () => setState(() => _showPromoPopup = false),
            ),
          // Sticky bottom CTA bar.
          const _StickyCtaBar(),
          // WhatsApp floating button.
          Positioned(
            bottom: 80,
            right: 16,
            child: _WhatsAppButton(),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF04122E),
            Color(0xFF072E68),
            Color(0xFF0D47A1),
            Color(0xFF1565C0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: <double>[0, 0.3, 0.65, 1],
        ),
      ),
      child: Stack(
        children: <Widget>[
          // Luxury mesh glows.
          Positioned(
            right: -80,
            top: -80,
            child: _blob(280, Colors.white.withValues(alpha: 0.045)),
          ),
          Positioned(
            right: wide ? 120 : 20,
            top: wide ? 120 : 70,
            child: _blob(140, TeamakColors.accent.withValues(alpha: 0.12)),
          ),
          Positioned(
            left: -60,
            bottom: -100,
            child: _blob(220, Colors.white.withValues(alpha: 0.04)),
          ),
          Positioned(
            left: wide ? 300 : 150,
            top: -40,
            child: _blob(100, TeamakColors.accent.withValues(alpha: 0.08)),
          ),
          // Subtle diagonal gold streak.
          Positioned(
            right: wide ? 180 : 40,
            top: 0,
            bottom: 0,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Colors.transparent,
                      TeamakColors.accent.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 56 : 22,
              vertical: wide ? 80 : 52,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 960),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Logo + company pill.
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/teamak_logo.png',
                            height: wide ? 72 : 54,
                            width: wide ? 72 : 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'TEAMAK GLOBAL',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: wide ? 15 : 13,
                                letterSpacing: 1.8,
                              ),
                            ),
                            Text(
                              'SOLUTIONS  ·  RC 9907312',
                              style: TextStyle(
                                color: TeamakColors.accent.withValues(alpha: 0.9),
                                fontSize: wide ? 11 : 9.5,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Premium badge.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            TeamakColors.accent,
                            Color(0xFFE09210),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: TeamakColors.accent.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.star_rounded, size: 15, color: TeamakColors.ink),
                          SizedBox(width: 5),
                          Text(
                            'FROM RIDER TO OWNER',
                            style: TextStyle(
                              color: TeamakColors.ink,
                              letterSpacing: 1.8,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'TEAMAK GLOBAL\nSOLUTIONS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 52 : 34,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                        letterSpacing: -0.5,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Gold underline accent.
                    Container(
                      width: wide ? 120 : 80,
                      height: 4,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[TeamakColors.accent, Colors.white],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        'Own a brand-new Bajaj motorcycle or Maruwa tricycle '
                        'through a one-time programme deposit. Built for riders '
                        'in Ibadan & Environs.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: wide ? 17 : 15,
                          height: 1.55,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: const <Widget>[
                        _HeroChip(icon: Icons.verified_outlined, label: 'One-time deposit'),
                        _HeroChip(icon: Icons.schedule_rounded, label: '3–6 months'),
                        _HeroChip(icon: Icons.motorcycle_rounded, label: 'Bajaj & Maruwa'),
                        _HeroChip(icon: Icons.location_on_outlined, label: 'Ibadan & Environs'),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Wrap(
                      spacing: 14,
                      runSpacing: 14,
                      children: <Widget>[
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TeamakColors.accent,
                            foregroundColor: TeamakColors.ink,
                            elevation: 8,
                            shadowColor: TeamakColors.accent.withValues(alpha: 0.55),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 36,
                              vertical: 20,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => context.go('/apply'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text('Start application'),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 20),
                            ],
                          ),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 19,
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () => context.go('/staff/login'),
                          child: const Text('Staff login'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _blob(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer({required this.deadline, this.compact = false});

  final DateTime deadline;
  final bool compact;

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final diff = widget.deadline.difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;
    final text = '${_pad(h)}:${_pad(m)}:${_pad(s)}';

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_outlined, size: 14, color: TeamakColors.accent),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _timeBox(h, 'HRS'),
        const SizedBox(width: 6),
        const Text(':', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        _timeBox(m, 'MIN'),
        const SizedBox(width: 6),
        const Text(':', style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w900)),
        const SizedBox(width: 6),
        _timeBox(s, 'SEC'),
      ],
    );
  }

  Widget _timeBox(int value, String label) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            _pad(value),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 17,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _VehiclePromoBanner extends StatefulWidget {
  const _VehiclePromoBanner({
    required this.wide,
    required this.asset,
    required this.badge,
    required this.badgeGradient,
    required this.badgeShadow,
    required this.title,
    required this.headline,
    required this.mobileHeadline,
    required this.benefits,
    required this.mobileBenefits,
    required this.slots,
    required this.mobileSlots,
    required this.deadline,
  });

  final bool wide;
  final String asset;
  final String badge;
  final List<Color> badgeGradient;
  final Color badgeShadow;
  final String title;
  final String headline;
  final String mobileHeadline;
  final String benefits;
  final String mobileBenefits;
  final String slots;
  final String mobileSlots;
  final DateTime deadline;

  @override
  State<_VehiclePromoBanner> createState() => _VehiclePromoBannerState();
}

class _VehiclePromoBannerState extends State<_VehiclePromoBanner> {
  @override
  Widget build(BuildContext context) {
    final wide = widget.wide;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF072E68), Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TeamakColors.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -40,
            top: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeamakColors.accent.withValues(alpha: 0.14),
              ),
            ),
          ),
          Positioned(
            left: wide ? 280 : -20,
            bottom: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: widget.badgeGradient),
                borderRadius: BorderRadius.circular(20),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: widget.badgeShadow.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Text(
                widget.badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 28 : 18),
            child: wide
                ? Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Image.asset(
                          widget.asset,
                          height: 150,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.image_rounded,
                            size: 80,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: TeamakColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.headline,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.benefits,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Text(
                                  'Ends in',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CountdownTimer(deadline: widget.deadline, compact: true),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: <Widget>[
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: TeamakColors.accent,
                                    foregroundColor: TeamakColors.ink,
                                    elevation: 6,
                                    shadowColor: TeamakColors.accent.withValues(alpha: 0.5),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 15,
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => context.go('/apply'),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text('Claim this deal'),
                                      SizedBox(width: 6),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: Text(
                                    widget.slots,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Image.asset(
                          widget.asset,
                          height: 110,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) => const Icon(
                            Icons.image_rounded,
                            size: 60,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: TeamakColors.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.mobileHeadline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.mobileBenefits,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          Text(
                            'Ends in',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CountdownTimer(deadline: widget.deadline, compact: true),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TeamakColors.accent,
                            foregroundColor: TeamakColors.ink,
                            elevation: 6,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.go('/apply'),
                          child: const Text('Claim this deal'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          widget.mobileSlots,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PromoPopup extends StatelessWidget {
  const _PromoPopup({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;

    return Stack(
      children: <Widget>[
        // Scrim.
        GestureDetector(
          onTap: onClose,
          child: Container(
            color: Colors.black.withValues(alpha: 0.5),
          ),
        ),
        // Card.
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
            ),
            child: Container(
              width: wide ? 420 : MediaQuery.sizeOf(context).width - 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF072E68), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: TeamakColors.accent.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, 20),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: <Widget>[
                  // Decorative.
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TeamakColors.accent.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  // Close button.
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Material(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClose,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.close_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Fire icon.
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: <Color>[Color(0xFFE53935), Color(0xFFFF7043)],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.red.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'LIMITED TIME OFFER',
                          style: TextStyle(
                            color: TeamakColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '₦100,000 OFF\nBajaj Boxer Promo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Apply this month and own a brand-new Bajaj Boxer '
                          'with a one-time deposit. Free rider training included.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: TeamakColors.accent,
                              foregroundColor: TeamakColors.ink,
                              elevation: 8,
                              shadowColor: TeamakColors.accent.withValues(alpha: 0.55),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              onClose();
                              context.go('/apply');
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text('Claim ₦100,000 OFF'),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: onClose,
                          child: const Text(
                            'Maybe later',
                            style: TextStyle(color: Colors.white54),
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
      ],
    );
  }
}

class _StatsCounter extends StatefulWidget {
  const _StatsCounter();

  @override
  State<_StatsCounter> createState() => _StatsCounterState();
}

class _StatsCounterState extends State<_StatsCounter> {
  bool _visible = false;
  final List<double> _values = List<double>.filled(4, 0);

  static const List<(IconData, double, String, String)> _stats = <(IconData, double, String, String)>[
    (Icons.groups_2_rounded, 500, '+', 'Riders empowered'),
    (Icons.location_on_rounded, 3, '', 'States covered'),
    (Icons.payments_rounded, 200, 'M+', 'Naira disbursed'),
    (Icons.verified_rounded, 95, '%', 'Success rate'),
  ];

  void _animate() {
    if (_visible) return;
    _visible = true;
    for (var i = 0; i < _stats.length; i++) {
      _countTo(i, _stats[i].$2);
    }
  }

  Future<void> _countTo(int index, double target) async {
    const steps = 40;
    for (var s = 0; s <= steps; s++) {
      await Future<void>.delayed(const Duration(milliseconds: 25));
      if (!mounted) return;
      setState(() {
        _values[index] = target * Curves.easeOutCubic.transform(s / steps);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels > 300) _animate();
        return false;
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 20, vertical: 28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFF04122E), Color(0xFF072E68)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: TeamakColors.accent.withValues(alpha: 0.3)),
        ),
        child: wide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_stats.length, (i) => _statCell(i, true)),
              )
            : Wrap(
                spacing: 20,
                runSpacing: 24,
                alignment: WrapAlignment.spaceEvenly,
                children: List.generate(_stats.length, (i) => _statCell(i, false)),
              ),
      ),
    );
  }

  Widget _statCell(int i, bool wide) {
    final (icon, target, suffix, label) = _stats[i];
    final val = _values[i];
    final display = target == 200
        ? '₦${val.round()}'
        : '${val.round()}$suffix';

    return SizedBox(
      width: wide ? 140 : MediaQuery.sizeOf(context).width / 2 - 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: TeamakColors.accent, size: 28),
          const SizedBox(height: 8),
          Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 28,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Testimonials extends StatefulWidget {
  const _Testimonials();

  @override
  State<_Testimonials> createState() => _TestimonialsState();
}

class _TestimonialsState extends State<_Testimonials> {
  int _index = 0;
  Timer? _timer;
  bool _paused = false;

  static const List<(String, String, String, IconData)> _items =
      <(String, String, String, IconData)>[
    (
      'Adeola O.',
      'Ibadan, Oyo',
      'Teamak changed my life. I applied with just my ID, got approved in days, '
          'and now I earn daily from my Bajaj Boxer. Best decision I ever made.',
      Icons.motorcycle_rounded,
    ),
    (
      'Chinedu M.',
      'Ibadan, Oyo',
      'The tricycle programme gave me a real business. My family eats better '
          'now because I own the machine — no more renting and giving half my '
          'earnings to someone else.',
      Icons.local_taxi_rounded,
    ),
    (
      'Blessing A.',
      'Oyo Town',
      'I was skeptical at first, but Teamak is real. The process was smooth '
          'and the training helped me stay safe on the road. Highly recommend '
          'to any young person.',
      Icons.verified_user_rounded,
    ),
    (
      'Tunde K.',
      'Ogbomoso',
      'The solar home system powers my shop and my kids can study at night. '
          'Affordable and easy. Teamak delivers on their promises.',
      Icons.solar_power_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && !_paused) setState(() => _index = (_index + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (name, location, quote, icon) = _items[_index];
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return MouseRegion(
      onEnter: (_) => setState(() => _paused = true),
      onExit: (_) => setState(() => _paused = false),
      child: Column(
        children: <Widget>[
          AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.08, 0),
                end: Offset.zero,
              ).animate(anim),
              child: child,
            ),
          ),
          child: Container(
            key: ValueKey<int>(_index),
            width: double.infinity,
            padding: EdgeInsets.all(wide ? 32 : 22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TeamakColors.primary.withValues(alpha: 0.1)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: TeamakColors.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[TeamakColors.primary, TeamakColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: TeamakColors.accent, size: 32),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: List.generate(
                                5,
                                (_) => const Icon(
                                  Icons.star_rounded,
                                  color: TeamakColors.accent,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '"$quote"',
                              style: const TextStyle(
                                fontSize: 17,
                                height: 1.55,
                                color: TeamakColors.ink,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              location,
                              style: const TextStyle(
                                color: TeamakColors.subtle,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[TeamakColors.primary, TeamakColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: TeamakColors.accent, size: 24),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: List.generate(
                          5,
                          (_) => const Icon(
                            Icons.star_rounded,
                            color: TeamakColors.accent,
                            size: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"$quote"',
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: TeamakColors.ink,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        location,
                        style: const TextStyle(color: TeamakColors.subtle, fontSize: 13),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _items.length,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == _index
                    ? TeamakColors.accent
                    : TeamakColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }
}

class _StickyCtaBar extends StatefulWidget {
  const _StickyCtaBar();

  @override
  State<_StickyCtaBar> createState() => _StickyCtaBarState();
}

class _StickyCtaBarState extends State<_StickyCtaBar> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final show = n.metrics.pixels > 500 && n.metrics.pixels < n.metrics.maxScrollExtent - 200;
        if (show != _visible && mounted) setState(() => _visible = show);
        return false;
      },
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          offset: _visible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _visible ? 1 : 0,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: wide ? 48 : 16, vertical: 16),
              padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF04122E), Color(0xFF072E68)],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: TeamakColors.accent.withValues(alpha: 0.5)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: wide
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.motorcycle_rounded, color: TeamakColors.accent, size: 24),
                        const SizedBox(width: 12),
                        const Text(
                          'Ready to own your vehicle?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 20),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TeamakColors.accent,
                            foregroundColor: TeamakColors.ink,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => context.go('/apply'),
                          child: const Text('Apply now'),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'Ready to own?',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: TeamakColors.accent,
                            foregroundColor: TeamakColors.ink,
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => context.go('/apply'),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final badges = <(IconData, String)>[
      (Icons.verified_user_rounded, 'NIN Verified'),
      (Icons.shield_rounded, 'Secure & Licensed'),
      (Icons.workspace_premium_rounded, 'RC 9907312'),
      (Icons.support_agent_rounded, '24/7 Support'),
      (Icons.handshake_rounded, 'Trusted Partner'),
    ];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 14, vertical: 18),
      decoration: BoxDecoration(
        color: TeamakColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: TeamakColors.primary.withValues(alpha: 0.1)),
      ),
      child: Wrap(
        spacing: wide ? 28 : 16,
        runSpacing: 14,
        alignment: WrapAlignment.center,
        children: [
          for (final (icon, label) in badges)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: TeamakColors.primary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: TeamakColors.ink,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _EarningsCalculator extends StatefulWidget {
  const _EarningsCalculator();

  @override
  State<_EarningsCalculator> createState() => _EarningsCalculatorState();
}

class _EarningsCalculatorState extends State<_EarningsCalculator> {
  bool _isTricycle = false;
  double _daysPerWeek = 6;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    // Rough Nigerian market estimates.
    final dailyEarning = _isTricycle ? 4500.0 : 3500.0;
    final weeklyEarning = dailyEarning * _daysPerWeek;
    final monthlyEarning = weeklyEarning * 4.3;
    final yearlyEarning = monthlyEarning * 12;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(wide ? 28 : 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF04122E), Color(0xFF072E68)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TeamakColors.accent.withValues(alpha: 0.3)),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Controls.
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Adjust your inputs',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Vehicle toggle.
                      Row(
                        children: [
                          _toggleBtn('Okada', !_isTricycle, () => setState(() => _isTricycle = false)),
                          const SizedBox(width: 8),
                          _toggleBtn('Tricycle', _isTricycle, () => setState(() => _isTricycle = true)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Days per week: ${_daysPerWeek.round()}',
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Slider(
                        value: _daysPerWeek,
                        min: 1,
                        max: 7,
                        divisions: 6,
                        activeColor: TeamakColors.accent,
                        inactiveColor: Colors.white24,
                        onChanged: (v) => setState(() => _daysPerWeek = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 32),
                // Results.
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      _earnRow('Daily', '₦${dailyEarning.toStringAsFixed(0)}'),
                      _earnRow('Weekly', '₦${weeklyEarning.toStringAsFixed(0)}'),
                      _earnRow('Monthly', '₦${monthlyEarning.toStringAsFixed(0)}'),
                      const SizedBox(height: 8),
                      _earnRow('Per Year', '₦${(yearlyEarning / 1000000).toStringAsFixed(1)}M', highlight: true),
                      const SizedBox(height: 14),
                      const Text(
                        '*Estimates based on average market earnings. Actual income varies.',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    _toggleBtn('Okada', !_isTricycle, () => setState(() => _isTricycle = false)),
                    const SizedBox(width: 8),
                    _toggleBtn('Tricycle', _isTricycle, () => setState(() => _isTricycle = true)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Days per week: ${_daysPerWeek.round()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Slider(
                  value: _daysPerWeek,
                  min: 1,
                  max: 7,
                  divisions: 6,
                  activeColor: TeamakColors.accent,
                  inactiveColor: Colors.white24,
                  onChanged: (v) => setState(() => _daysPerWeek = v),
                ),
                const SizedBox(height: 8),
                _earnRow('Weekly', '₦${weeklyEarning.toStringAsFixed(0)}'),
                _earnRow('Monthly', '₦${monthlyEarning.toStringAsFixed(0)}'),
                _earnRow('Per Year', '₦${(yearlyEarning / 1000000).toStringAsFixed(1)}M', highlight: true),
                const SizedBox(height: 10),
                const Text(
                  '*Estimates based on average market earnings.',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
    );
  }

  Widget _toggleBtn(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? TeamakColors.accent : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? TeamakColors.accent : Colors.white24,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? TeamakColors.ink : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _earnRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? TeamakColors.accent : Colors.white60,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
              fontSize: highlight ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: highlight ? TeamakColors.accent : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: highlight ? 24 : 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _AfterSalesSupport extends StatelessWidget {
  const _AfterSalesSupport({required this.wide});

  final bool wide;

  static const items = <(IconData, String, String)>[
    (
      Icons.build_circle_rounded,
      'Free maintenance training',
      'Learn basic upkeep so your vehicle lasts longer and costs less.',
    ),
    (
      Icons.health_and_safety_rounded,
      'Insurance guidance',
      'We help you get affordable coverage to protect your investment.',
    ),
    (
      Icons.phone_in_talk_rounded,
      'Dedicated support line',
      'Call or WhatsApp us anytime — real people, real help.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cardW = wide ? (MediaQuery.sizeOf(context).width - 96 - 32) / 3 : MediaQuery.sizeOf(context).width - 40;

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (final (icon, title, desc) in items)
          SizedBox(
            width: cardW,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: TeamakColors.primary.withValues(alpha: 0.08)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: TeamakColors.primary.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          TeamakColors.primary.withValues(alpha: 0.1),
                          TeamakColors.accent.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: TeamakColors.primary, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _WhatsAppButton extends StatelessWidget {
  const _WhatsAppButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            final phone = '2348023449126';
            final msg = Uri.encodeComponent(
              'Hello Teamak, I want to apply for a vehicle ownership programme.',
            );
            final uri = Uri.parse('https://wa.me/$phone?text=$msg');
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.chat_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 5,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[TeamakColors.accent, TeamakColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 14),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 19),
          child: Text(
            subtitle,
            style: TextStyle(color: TeamakColors.subtle, fontSize: 15, height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: TeamakColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.programme});

  final Programme programme;

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      accentBar: true,
      onTap: () => context.go('/apply'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: TeamakColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              programme.label,
              style: const TextStyle(
                color: TeamakColors.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            programme.depositLabel,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              const Icon(Icons.schedule_rounded, size: 16, color: TeamakColors.subtle),
              const SizedBox(width: 5),
              Text(
                'over ${programme.months} months',
                style: const TextStyle(color: TeamakColors.subtle),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: TeamakColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.motorcycle, color: TeamakColors.accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  programme.asset,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            programme.summary,
            style: const TextStyle(color: TeamakColors.subtle, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/apply'),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Apply for this'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlobalServices extends StatelessWidget {
  const _GlobalServices({required this.wide});

  final bool wide;

  static const List<Map<String, dynamic>> _services = <Map<String, dynamic>>[
    <String, dynamic>{
      'icon': Icons.local_shipping_rounded,
      'title': 'Logistics & Haulage',
      'body': 'End-to-end cargo movement, last-mile delivery and fleet '
          'logistics powered by our rider network.',
    },
    <String, dynamic>{
      'icon': Icons.school_rounded,
      'title': 'Training & Capacity',
      'body': 'Rider safety, road etiquette and business-skills training '
          'so every partner succeeds on and off the road.',
    },
    <String, dynamic>{
      'icon': Icons.handshake_rounded,
      'title': 'Corporate Partnerships',
      'body': 'B2B fleet packages, CSR mobility schemes and white-label '
          'ownership programmes for NGOs and institutions.',
    },
    <String, dynamic>{
      'icon': Icons.recycling_rounded,
      'title': 'Sustainable Solutions',
      'body': 'Clean-energy products and eco-friendly mobility options that '
          'cut emissions and support greener communities.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final cardW = wide
        ? (MediaQuery.sizeOf(context).width - 96 - 40) / 3
        : MediaQuery.sizeOf(context).width - 40;

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        for (var i = 0; i < _services.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + (i * 60).clamp(0, 400)),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - t)),
                child: child,
              ),
            ),
            child: SizedBox(
              width: cardW,
              child: HoverCard(
                onTap: () {},
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            TeamakColors.primary.withValues(alpha: 0.14),
                            TeamakColors.accent.withValues(alpha: 0.14),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        _services[i]['icon'] as IconData,
                        color: TeamakColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _services[i]['title'] as String,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _services[i]['body'] as String,
                            style: TextStyle(
                              color: TeamakColors.subtle,
                              fontSize: 13.5,
                              height: 1.45,
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
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks({required this.wide});

  final bool wide;

  static const _steps = <Map<String, String>>[
    <String, String>{
      'title': 'Apply online',
      'body': 'Fill the eight-section application form with your rider and '
          'association details.',
    },
    <String, String>{
      'title': 'Verification',
      'body': 'Our team verifies your park, identity, next of kin and '
          'references.',
    },
    <String, String>{
      'title': 'Pay your deposit',
      'body': 'Commit the one-time programme deposit for your chosen option '
          'on the agreed date.',
    },
    <String, String>{
      'title': 'Take ownership',
      'body': 'Sign the asset ownership agreement and receive your brand-new '
          'Bajaj machine.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        for (var i = 0; i < _steps.length; i++)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + (i * 70)),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - t)),
                child: child,
              ),
            ),
            child: SizedBox(
              width: wide ? (900 - 48) / 4 : 400,
              child: HoverCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: <Color>[TeamakColors.primary, TeamakColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: TeamakColors.accent, width: 2),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _steps[i]['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _steps[i]['body']!,
                      style: const TextStyle(
                        color: TeamakColors.subtle,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CallToAction extends StatelessWidget {
  const _CallToAction({required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[TeamakColors.primaryDark, TeamakColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TeamakColors.primary.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -50,
            top: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TeamakColors.accent.withValues(alpha: 0.16),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(wide ? 40 : 26),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 20,
              children: <Widget>[
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Ready to own your machine?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Applications for Ibadan & Environs are open now.',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ],
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: TeamakColors.accent,
                    foregroundColor: TeamakColors.ink,
                    elevation: 6,
                    shadowColor: TeamakColors.accent.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 36,
                      vertical: 20,
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () => context.go('/apply'),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Start application'),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF04122E), Color(0xFF072E68), Color(0xFF04122E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(top: BorderSide(color: TeamakColors.accent, width: 2.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Image.asset(
              'assets/teamak_logo.png',
              height: 72,
              width: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'TEAMAK GLOBAL SOLUTIONS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'RC No. 9907312',
            style: TextStyle(
              color: TeamakColors.accent,
              fontSize: 12.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: 56,
            height: 3,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[TeamakColors.accent, Colors.white],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Solution Gospel Complex, Aba Opa, Ojoo, Ibadan',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '+234 802 344 9126  ·  Teamakgloblsolution33@gmail.com',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () => context.go('/contact'),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.mail_rounded, size: 16, color: TeamakColors.accent),
                  SizedBox(width: 8),
                  Text(
                    'Contact us',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Ride with Dignity. Own Your Future.',
            style: TextStyle(
              color: TeamakColors.accent,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} Teamak Global Solutions. All rights reserved.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
