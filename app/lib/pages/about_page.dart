import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/content_sections.dart';
import '../widgets/shell.dart';

/// Company story and values, in the long-scroll rhythm of a modern
/// consultancy site: one belief, four values, one voice from a rider.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 820;

    return AppShell(
      title: 'About',
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const PageHero(
            eyebrow: 'About Teamak',
            headline: 'A rider should own the machine,\nnot rent it forever.',
            standfirst:
                'Teamak Global Solution Limited (RC 9907312) runs the Rider '
                'Ownership Programme across Ibadan and Environs — one-time '
                'deposits, short plans and a vehicle that ends up in your name.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 18, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionLead(
                  eyebrow: 'Why we exist',
                  title: 'Paying rent on a bike, week after week, is a trap.',
                  subtitle:
                      'Most riders here work a machine they will never own. They hand '
                      'over a share of every day\'s earnings, and at the end of it they '
                      'have nothing to show for it. We built the Rider Ownership '
                      'Programme to break that cycle: pay one deposit, clear a short '
                      'plan, and the asset is yours.',
                ),
                SizedBox(height: wide ? 44 : 32),
                _FactStrip(wide: wide),
                SizedBox(height: wide ? 52 : 36),
                const SectionLead(
                  eyebrow: 'What bonds us',
                  title: 'Four things we hold to.',
                  subtitle:
                      'They decide how we treat applicants, how we price the '
                      'programme, and what happens after the keys change hands.',
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: <Widget>[
                    for (final value in _values)
                      SizedBox(
                        width: wide ? (width - 96 - 20) / 2 : width - 36,
                        child: ValueCard(
                          title: value.$1,
                          body: value.$2,
                          crest: value.$3,
                          icon: value.$4,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),
                const QuoteBlock(
                  quote:
                      'Teamak changed my life. I applied with just my ID, got '
                      'approved in days, and now I earn daily from my Bajaj Boxer. '
                      'Best decision I ever made.',
                  name: 'Adeola O.',
                  role: 'Owner-rider · Ibadan, Oyo',
                ),
                const SizedBox(height: 32),
                const NextLink(
                  label: 'Next',
                  title: 'What we do',
                  path: '/what-we-do',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<(String, String, String, IconData)> _values =
      <(String, String, String, IconData)>[
    (
      'We say what it costs.',
      'Every programme states its deposit and its term before you pay a kobo. '
          'No hidden charges appear at handover, and no agent adds a fee on the '
          'side.',
      'We keep our word.',
      Icons.receipt_long_outlined,
    ),
    (
      'We build it around your earnings.',
      'There is no off-the-shelf plan here. Deposit bands and repayment terms '
          'are set against what a working rider actually makes on the road in '
          'Ibadan, not against a spreadsheet from far away.',
      'We make it fit.',
      Icons.tune_rounded,
    ),
    (
      'We stay after the keys change hands.',
      'Training, spare parts, maintenance guidance and a phone number that gets '
          'answered — support does not stop at delivery. A rider who keeps '
          'earning is the point of the whole programme.',
      'We stay in it with you.',
      Icons.support_agent_rounded,
    ),
    (
      'We take the hard cases.',
      'An applicant with no payslip and no collateral is exactly who this was '
          'built for. We verify what we can verify and we move quickly, because '
          'a rider waiting a month is a rider who goes back to renting.',
      'We push through.',
      Icons.bolt_rounded,
    ),
  ];
}

/// Three plain figures, kept separate from the landing page's animated
/// counters so this page has no timers to leak.
class _FactStrip extends StatelessWidget {
  const _FactStrip({required this.wide});

  final bool wide;

  static const List<(IconData, String, String)> _facts =
      <(IconData, String, String)>[
    (Icons.motorcycle_rounded, 'Bajaj & Maruwa', 'Assets we place'),
    (Icons.hourglass_bottom_rounded, '3–6 months', 'Typical plan length'),
    (Icons.location_on_outlined, 'Ibadan & Environs', 'Where we operate'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: <Widget>[
        for (final (icon, value, label) in _facts)
          SizedBox(
            width: wide ? (width - 96 - 32) / 3 : width - 36,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: TeamakColors.primary.withValues(alpha: 0.12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(icon, color: TeamakColors.primary, size: 26),
                  const SizedBox(height: 12),
                  Text(
                    value,
                    style: const TextStyle(
                      color: TeamakColors.ink,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 13.5,
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
