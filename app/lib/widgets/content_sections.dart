import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Full-bleed statement hero in the Value Circle Africa idiom: a light aurora
/// background (white→mint with soft green and amber glows), a pill kicker, a
/// very large ink headline and one supporting line.
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.standfirst,
  });

  final String eyebrow;
  final String headline;
  final String standfirst;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 760;

    return Stack(
      children: <Widget>[
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[Colors.white, TeamakColors.surface2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        // Soft aurora glows, standing in for the reference design's blurred
        // conic gradient.
        Positioned(
          right: -80,
          top: -90,
          child: _glow(260, TeamakColors.primary.withValues(alpha: 0.16)),
        ),
        Positioned(
          left: -60,
          bottom: -110,
          child: _glow(220, TeamakColors.gold.withValues(alpha: 0.12)),
        ),
        Positioned(
          right: 120,
          bottom: -60,
          child: _glow(160, TeamakColors.accent.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 56 : 22,
            vertical: wide ? 64 : 44,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  KickerPill(label: eyebrow, icon: Icons.eco_rounded),
                  const SizedBox(height: 18),
                  Text(
                    headline,
                    style: TextStyle(
                      color: TeamakColors.ink,
                      fontSize: wide ? 42 : 28,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      standfirst,
                      style: TextStyle(
                        color: TeamakColors.subtle,
                        fontSize: wide ? 16.5 : 14.5,
                        height: 1.75,
                      ),
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

  static Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: <Color>[color, color.withValues(alpha: 0)]),
        ),
      );
}

/// The pill-shaped kicker used above headlines: green tint fill, green hairline
/// border, dark-green semibold label with a small leading icon.
class KickerPill extends StatelessWidget {
  const KickerPill({super.key, required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: TeamakColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: TeamakColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: TeamakColors.primaryDark),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: TeamakColors.primaryDark,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Eyebrow + statement pair introducing a section.
class SectionLead extends StatelessWidget {
  const SectionLead({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: TeamakColors.primaryDark,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.8,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: TeamakColors.ink,
            fontSize: 27,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: TeamakColors.subtle,
              fontSize: 15.5,
              height: 1.65,
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared card frame: white, radius 20, hairline border, and the reference
/// design's 3px gradient line along the top edge.
class _AccentCard extends StatelessWidget {
  const _AccentCard({required this.gradient, required this.child});

  final LinearGradient gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(height: 3, decoration: BoxDecoration(gradient: gradient)),
          child,
        ],
      ),
    );
  }
}

/// A named value: a short label, one sentence on what it means in practice,
/// and the standing line the company signs it off with.
class ValueCard extends StatelessWidget {
  const ValueCard({
    super.key,
    required this.title,
    required this.body,
    required this.crest,
    required this.icon,
  });

  final String title;
  final String body;

  /// The closing line, e.g. "We keep our word."
  final String crest;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      gradient: TeamakColors.gradPrimary,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: TeamakColors.primaryDark, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: TeamakColors.ink,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                color: TeamakColors.subtle,
                fontSize: 14.5,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              crest,
              style: const TextStyle(
                color: TeamakColors.primaryDark,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A service pillar, worded as the question a customer actually asks.
class PillarCard extends StatelessWidget {
  const PillarCard({
    super.key,
    required this.title,
    required this.question,
    required this.body,
    required this.icon,
  });

  final String title;
  final String question;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _AccentCard(
      gradient: TeamakColors.gradGold,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: TeamakColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: TeamakColors.accentDark, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: TeamakColors.primaryDark,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              question,
              style: const TextStyle(
                color: TeamakColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: const TextStyle(
                color: TeamakColors.subtle,
                fontSize: 14.5,
                height: 1.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pull quote with star rating and an initials avatar, per the reference
/// design's testimonial cards.
class QuoteBlock extends StatelessWidget {
  const QuoteBlock({
    super.key,
    required this.quote,
    required this.name,
    required this.role,
  });

  final String quote;
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TeamakColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TeamakColors.primary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.star_rounded, color: TeamakColors.gold, size: 20),
              Icon(Icons.star_rounded, color: TeamakColors.gold, size: 20),
              Icon(Icons.star_rounded, color: TeamakColors.gold, size: 20),
              Icon(Icons.star_rounded, color: TeamakColors.gold, size: 20),
              Icon(Icons.star_rounded, color: TeamakColors.gold, size: 20),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '“$quote”',
            style: const TextStyle(
              color: TeamakColors.ink,
              fontSize: 17,
              height: 1.7,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: TeamakColors.gradPrimary,
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: const TextStyle(
                        color: TeamakColors.ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role,
                      style: const TextStyle(
                        color: TeamakColors.dim,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Footer-of-page link to the next company page.
class NextLink extends StatelessWidget {
  const NextLink({
    super.key,
    required this.label,
    required this.title,
    required this.path,
  });

  final String label;
  final String title;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TeamakColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.go(path),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        color: TeamakColors.dim,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: const TextStyle(
                        color: TeamakColors.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: TeamakColors.primaryDark, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
