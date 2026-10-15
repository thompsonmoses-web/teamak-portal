import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme.dart';
import '../widgets/content_sections.dart';
import '../widgets/shell.dart';

/// The four service pillars, each worded as the question a customer actually
/// asks rather than as an internal department name.
class WhatWeDoPage extends StatelessWidget {
  const WhatWeDoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 820;

    return AppShell(
      title: 'What we do',
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          const PageHero(
            eyebrow: 'What we do',
            headline: 'Four things, done properly.\nNot ten, done halfway.',
            standfirst:
                'Rider ownership is the core of the business. Around it sit '
                'training, logistics and energy — the things that keep a rider '
                'earning once the vehicle is theirs.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 48 : 18, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionLead(
                  eyebrow: 'Our work',
                  title: 'What each one actually gives you.',
                  subtitle:
                      'Pick the one that matches where you are today. Most riders '
                      'start at the first and end up using all four.',
                ),
                const SizedBox(height: 26),
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: <Widget>[
                    for (final pillar in _pillars)
                      SizedBox(
                        width: wide ? (width - 96 - 20) / 2 : width - 36,
                        child: PillarCard(
                          title: pillar.$1,
                          question: pillar.$2,
                          body: pillar.$3,
                          icon: pillar.$4,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 44),
                _PathStrip(wide: wide),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: TeamakColors.accent,
                      foregroundColor: TeamakColors.ink,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    onPressed: () => context.go('/apply'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Start an application'),
                  ),
                ),
                const SizedBox(height: 28),
                const NextLink(
                  label: 'Next',
                  title: 'Our team',
                  path: '/team',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const List<(String, String, String, IconData)> _pillars =
      <(String, String, String, IconData)>[
    (
      'Rider ownership',
      'How do I stop renting and start owning?',
      'Pay a one-time programme deposit — from ₦400,000 for a Bajaj Boxer or '
          '₦2,300,000 for an approved Maruwa tricycle — clear the plan over three '
          'to six months, and take the vehicle. Applications are reviewed and '
          'verified by our own staff before anything is approved.',
      Icons.motorcycle_rounded,
    ),
    (
      'Training & capacity',
      'How do I stay safe and earn more?',
      'Rider training comes with the programme at no extra charge: road safety, '
          'basic maintenance and how to protect the asset you now own. A rider '
          'who can fix a minor fault himself keeps working through the week.',
      Icons.school_outlined,
    ),
    (
      'Logistics & haulage',
      'Who can move goods dependably?',
      'Our rider network handles last-mile delivery and haulage across our '
          'operating states. Partners get a vetted, trained, vehicle-owning '
          'fleet rather than a queue of renters with no stake in the job.',
      Icons.local_shipping_outlined,
    ),
    (
      'Sustainable solutions',
      'What else can I add to the business?',
      'Sun King solar home systems from ₦50,000 — panel, LED lighting, phone '
          'charging and TV support — so the income a vehicle earns can go '
          'further at home, and so a shop can stay open after dark.',
      Icons.solar_power_rounded,
    ),
  ];
}

/// The route an applicant travels, shown as three stops rather than another
/// card grid, so the page has one rhythm break before the call to action.
class _PathStrip extends StatelessWidget {
  const _PathStrip({required this.wide});

  final bool wide;

  static const List<(IconData, String, String)> _stops =
      <(IconData, String, String)>[
    (Icons.description_outlined, 'Apply online', 'Eight short sections, no office visit.'),
    (Icons.fact_check_outlined, 'Verification', 'Our team reviews and confirms what you sent.'),
    (Icons.key_rounded, 'Take ownership', 'Pay the deposit, collect the vehicle, keep the keys.'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cards = <Widget>[
      for (final (icon, title, body) in _stops)
        Container(
          width: wide ? (width - 96 - 32) / 3 : width - 36,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E9F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, color: TeamakColors.accent, size: 26),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: TeamakColors.ink,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  color: TeamakColors.subtle,
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionLead(
          eyebrow: 'How it runs',
          title: 'Three stops from form to keys.',
          subtitle: 'The same route whether you are taking a motorcycle or a tricycle.',
        ),
        const SizedBox(height: 22),
        Wrap(spacing: 16, runSpacing: 16, children: cards),
      ],
    );
  }
}
