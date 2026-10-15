import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/content_sections.dart';
import '../widgets/shell.dart';

/// Who does what. Roles rather than names: the company supplies real people,
/// photos and contact lines, and inventing them here would put words in
/// mouths that never said them.
class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 820;

    return AppShell(
      title: 'Our team',
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const PageHero(
            eyebrow: 'Our team',
            headline: 'People who answer\nwhen you call.',
            standfirst:
                'Ownership programmes fail on follow-through, not on paperwork. '
                'These are the roles that carry an applicant from the first form '
                'to the day the vehicle is theirs — and stay on the phone after.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 18, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionLead(
                  eyebrow: 'Who you will deal with',
                  title: 'Six roles, one programme.',
                  subtitle:
                      'An application moves through these hands. Names, photographs '
                      'and direct lines are published here once the company signs '
                      'them off.',
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: <Widget>[
                    for (final role in _roles)
                      SizedBox(
                        width: wide ? (width - 96 - 40) / 3 : width - 36,
                        child: _RoleCard(role: role),
                      ),
                  ],
                ),
                const SizedBox(height: 44),
                const QuoteBlock(
                  quote:
                      'I was skeptical at first, but Teamak is real. The process '
                      'was smooth and the training helped me stay safe on the road. '
                      'Highly recommend to any young person.',
                  name: 'Blessing A.',
                  role: 'Owner-rider · Oyo Town',
                ),
                const SizedBox(height: 32),
                const NextLink(
                  label: 'Next',
                  title: 'About Teamak',
                  path: '/about',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<_Role> _roles = <_Role>[
    _Role(
      'Programme Director',
      Icons.workspace_premium_outlined,
      'Owns the ownership programme end to end: deposit bands, partner '
          'agreements with the vehicle suppliers, and the terms riders sign.',
    ),
    _Role(
      'Applications & Verification',
      Icons.fact_check_outlined,
      'Reads every submission, checks the details against what can be '
          'confirmed, and decides what moves forward. This is the desk that '
          'turns a form into an approval.',
    ),
    _Role(
      'Field Operations',
      Icons.map_outlined,
      'Runs collection, handover and inspection across Ibadan and Environs — '
          'the people who meet you with the keys and the documents.',
    ),
    _Role(
      'Training & Rider Safety',
      Icons.school_outlined,
      'Delivers the rider training bundled with every programme: road safety, '
          'defensive riding and the basic maintenance that keeps a working '
          'vehicle working.',
    ),
    _Role(
      'After-Sales Support',
      Icons.support_agent_rounded,
      'The line riders call when something goes wrong after handover — spare '
          'parts, service scheduling and faults that need a technician.',
    ),
    _Role(
      'Partnerships & Logistics',
      Icons.handshake_outlined,
      'Manages the corporate side: haulage clients, delivery partners and the '
          'rider network that serves them.',
    ),
  ];
}

class _Role {
  const _Role(this.title, this.icon, this.body);

  final String title;
  final IconData icon;
  final String body;
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role});

  final _Role role;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TeamakColors.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(role.icon, color: TeamakColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    role.title,
                    style: const TextStyle(
                      color: TeamakColors.ink,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              role.body,
              style: const TextStyle(
                color: TeamakColors.subtle,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
