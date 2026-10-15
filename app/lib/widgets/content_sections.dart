import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';

/// Full-bleed statement hero used by the company pages: an eyebrow label, a
/// short headline and one supporting line over the brand gradient.
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

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFF04122E),
            Color(0xFF072E68),
            Color(0xFF0D47A1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -60,
            top: -60,
            child: _blob(220, Colors.white.withValues(alpha: 0.05)),
          ),
          Positioned(
            left: -40,
            bottom: -80,
            child: _blob(180, TeamakColors.accent.withValues(alpha: 0.1)),
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
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: TeamakColors.accent.withValues(alpha: 0.95),
                        fontSize: wide ? 12.5 : 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: wide ? 2.4 : 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      headline,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 42 : 28,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        standfirst,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: wide ? 16.5 : 14.5,
                          height: 1.6,
                        ),
                      ),
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

/// Eyebrow + statement pair introducing a section, matching the landing page's
/// header rhythm.
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
            color: TeamakColors.primary,
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
              height: 1.6,
            ),
          ),
        ),
      ],
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: TeamakColors.primary, size: 24),
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
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              crest,
              style: const TextStyle(
                color: TeamakColors.primary,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: TeamakColors.accent, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: const TextStyle(
                      color: TeamakColors.primary,
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

/// Pull quote with attribution.
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E9F2)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: TeamakColors.primary.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.format_quote_rounded,
              color: TeamakColors.accent, size: 36),
          const SizedBox(height: 10),
          Text(
            quote,
            style: const TextStyle(
              color: TeamakColors.ink,
              fontSize: 18,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
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
              color: TeamakColors.subtle,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Footer-of-page link to the next company page, mirroring the "next section"
/// affordance on a long-scroll site.
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
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4E9F2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
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
                        color: TeamakColors.subtle,
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
                  color: TeamakColors.primary, size: 26),
            ],
          ),
        ),
      ),
    );
  }
}
