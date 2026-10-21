import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/shell.dart';

/// The support centre: every question riders ask, answered in one place.
///
/// Follows the pattern proven on the Value Circle site — a trust strip, a
/// category filter over accordion questions, and the compliance cards that
/// say how the programme is run — with Teamak's own words throughout.
class FaqPage extends StatefulWidget {
  const FaqPage({super.key});

  @override
  State<FaqPage> createState() => _FaqPageState();
}

class _FaqPageState extends State<FaqPage> {
  /// Which category of questions is showing; null means all of them.
  String? _category;

  static const List<(String, String)> _categories = <(String, String)>[
    ('Applying', 'Applying'),
    ('Verification', 'Verification'),
    ('Approval & payment', 'Approval & payment'),
    ('Ownership', 'Ownership'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;
    final visible = _questions
        .where((item) => _category == null || item.category == _category)
        .toList();

    return AppShell(
      title: 'FAQ & support',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            children: <Widget>[
              _buildHeader(context),
              const SizedBox(height: 20),
              const _TrustStrip(),
              const SizedBox(height: 24),
              Text(
                'Frequently asked questions',
                style: TextStyle(
                  fontSize: wide ? 22 : 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pick a topic, then tap a question to open it.',
                style: TextStyle(color: TeamakColors.subtle),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final (id, label) in _categories)
                    ChoiceChip(
                      label: Text(label),
                      selected: _category == id,
                      onSelected: (_) => setState(() => _category = id),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              for (final item in visible) ...<Widget>[
                _FaqTile(question: item.question, answer: item.answer),
                const SizedBox(height: 10),
              ],
              if (visible.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No questions in this topic yet — try another category.',
                    style: TextStyle(color: TeamakColors.subtle),
                  ),
                ),
              TextButton(
                onPressed: () => setState(() => _category = null),
                child: const Text('Show all questions'),
              ),
              const SizedBox(height: 16),
              const _CommitmentCards(),
              const SizedBox(height: 24),
              _buildSupportCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Card(
        child: Padding(
          padding: EdgeInsets.all(MediaQuery.sizeOf(context).width >= 720 ? 28 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'SUPPORT CENTRE',
                style: TextStyle(
                  color: TeamakColors.accentDark,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Questions, answered clearly',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Applying for a slot should never feel like a gamble. Here is '
                'exactly how the programme works, what it costs, and what '
                'happens at every step.',
                style: TextStyle(color: TeamakColors.subtle, height: 1.5),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton(
                    onPressed: () => context.go('/apply'),
                    child: const Text('Apply for a slot'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _chatOnWhatsApp,
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Ask on WhatsApp'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSupportCard(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Still have questions?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Our team answers on WhatsApp every day. Message us with your '
                'application number (if you have one) and we will pick it up '
                'from there.',
                style: TextStyle(color: TeamakColors.subtle, height: 1.5),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _chatOnWhatsApp,
                    icon: const Icon(Icons.chat_rounded),
                    label: const Text('Chat on WhatsApp'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/contact'),
                    icon: const Icon(Icons.mail_outline),
                    label: const Text('Contact us'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  /// Opens WhatsApp with a pre-typed greeting — the same channel the
  /// dashboard leads with, so the answer arrives where riders already are.
  Future<void> _chatOnWhatsApp() async {
    final uri = Uri.parse(
      'https://wa.me/2348023449126?text=${Uri.encodeComponent(
        'Hello Teamak, I have a question about the Rider Ownership Programme.',
      )}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No WhatsApp here — the number is the point, so give it rather
      // than an error.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'WhatsApp could not open — call or message +234 802 344 9126.',
          ),
        ),
      );
    }
  }
}

/// One question, collapsed until tapped. ExpansionTile inside a plain Card
/// keeps the accordion look without Material 3's heavy default surfaces.
class _FaqTile extends StatelessWidget {
  const _FaqTile({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: TeamakColors.primary,
          collapsedIconColor: TeamakColors.primary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
          title: Text(
            question,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: <Widget>[
            Text(
              answer,
              style: const TextStyle(
                color: TeamakColors.subtle,
                height: 1.55,
                fontSize: 14.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Four numbers that answer the worry behind most questions before they
/// are asked — free to apply, transparent to run, registered to hold.
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  static const List<(String, String)> _tiles = <(String, String)>[
    ('₦0', 'Application fee'),
    ('100%', 'Transparent review'),
    ('RC 9907312', 'Registered company'),
    ('Anytime', 'Track your status'),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 680;

    Widget tile(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: TeamakColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: TeamakColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // The registration number is much wider than a stat, so it
                // gets the small type that fits rather than the big one.
                Text(
                  value,
                  style: TextStyle(
                    fontSize: value.length > 6 ? 15 : 20,
                    fontWeight: FontWeight.w800,
                    color: TeamakColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: const TextStyle(
                    color: TeamakColors.subtle,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        );

    if (wide) {
      return Row(
        children: <Widget>[
          for (var i = 0; i < _tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 12),
            tile(_tiles[i].$1, _tiles[i].$2),
          ],
        ],
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            tile(_tiles[0].$1, _tiles[0].$2),
            const SizedBox(width: 12),
            tile(_tiles[1].$1, _tiles[1].$2),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            tile(_tiles[2].$1, _tiles[2].$2),
            const SizedBox(width: 12),
            tile(_tiles[3].$1, _tiles[3].$2),
          ],
        ),
      ],
    );
  }
}

/// How the programme is run — the promises behind the answers above.
class _CommitmentCards extends StatelessWidget {
  const _CommitmentCards();

  static const List<(IconData, String, String)> _cards =
      <(IconData, String, String)>[
    (
      Icons.verified_outlined,
      'Transparent review',
      'Every application moves through the same documented steps. No '
          'secret criteria, no back doors, no preferential slots.',
    ),
    (
      Icons.history_edu_outlined,
      'Every decision recorded',
      'Status changes are stamped with the date and time, and your '
          'dashboard shows them. You always know where your application '
          'stands.',
    ),
    (
      Icons.lock_person_outlined,
      'Your details stay protected',
      'We ask only what the programme needs, and your answers are used '
          'for your application and nothing else.',
    ),
    (
      Icons.account_balance_outlined,
      'Registered and accountable',
      'TEAMAK GLOBAL SOLUTIONS is a registered company (RC No. '
          '9907312) with a physical office you can visit.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 680
            ? (constraints.maxWidth - 16) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: <Widget>[
            for (final (icon, title, body) in _cards)
              SizedBox(
                width: cardWidth,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(icon, color: TeamakColors.primary, size: 28),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          body,
                          style: const TextStyle(
                            color: TeamakColors.subtle,
                            height: 1.5,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A question and its answer, tagged with the category it sits under.
class _FaqEntry {
  const _FaqEntry(this.category, this.question, this.answer);

  final String category;
  final String question;
  final String answer;
}

/// The programme's answers in the riders' order of worry: getting in,
/// getting verified, getting approved, and getting the machine.
const List<_FaqEntry> _questions = <_FaqEntry>[
  _FaqEntry(
    'Applying',
    'How do I apply for a slot?',
    'Tap "Apply for a slot" and fill the form — your details, your riding '
        'experience, the programme you want, your finances and your '
        'documents. It takes about ten minutes and works on any phone. '
        'Prefer a hand? Message us on WhatsApp and our team will walk '
        'through it with you.',
  ),
  _FaqEntry(
    'Applying',
    'How much does it cost to apply?',
    'Nothing. Applying is completely free — no fee, no charge, no purchase '
        'required. You only pay a deposit after your application has been '
        'approved, and it goes to Teamak Global Solutions directly, never '
        'to an individual.',
  ),
  _FaqEntry(
    'Applying',
    'What do I need before I start?',
    'Your NIN, a passport photograph, your rider or association '
        'registration, and proof of where you live. Section E of the form '
        'asks which of these you already have, so you know exactly what to '
        'arrange before the verification visit.',
  ),
  _FaqEntry(
    'Applying',
    'Can I apply again if I am not approved?',
    'Yes. A "Not approved" decision is about that application only. When '
        'the next intake opens, apply again — and message us if you would '
        'like to understand what held the first one back.',
  ),
  _FaqEntry(
    'Verification',
    'What happens after I submit?',
    'Your application starts as "Submitted", then moves to "Under review". '
        'Our verification team calls you on the number you gave and invites '
        'you to a visit where the originals of your documents are checked. '
        'Every step appears live on your dashboard.',
  ),
  _FaqEntry(
    'Verification',
    'Why do you check originals?',
    'A verification visit confirms that what is on the form matches the '
        'person and the documents behind it. It protects you as much as it '
        'protects the programme — a slot confirmed honestly is a slot that '
        'holds.',
  ),
  _FaqEntry(
    'Verification',
    'How do I know what to bring to verification?',
    'Your dashboard shows it. The "Getting ready for verification" card '
        'lists every document and marks it "Ready" or "Arrange" based on '
        'your own answers — bring everything marked "Arrange" to the visit.',
  ),
  _FaqEntry(
    'Approval & payment',
    'When do I pay the deposit?',
    'Only after approval, and only to Teamak Global Solutions through the '
        'arrangement our team confirms with you. Nobody from Teamak will '
        'ever ask you to send money to a personal account — if that '
        'happens, it is not us. Report it to us on WhatsApp.',
  ),
  _FaqEntry(
    'Approval & payment',
    'What do the programmes cost?',
    'There are three ownership tracks: Okada at ₦650,000 over 3 months, '
        'Okada at ₦400,000 over 6 months, and Maruwa at ₦2,300,000 over '
        '3 months. The programme you pick in the form is what staff '
        'confirm with you at approval.',
  ),
  _FaqEntry(
    'Approval & payment',
    'What if my application needs more time?',
    'Some checks take longer than others. If that happens your status '
        'shows "Further review" — we will reach out if anything else is '
        'needed from you, and there is nothing you need to do meanwhile.',
  ),
  _FaqEntry(
    'Ownership',
    'What happens at handover?',
    'Once your deposit is confirmed, our team arranges the handover of '
        'your vehicle. When the agreed plan is completed, ownership '
        'transfers to you.',
  ),
  _FaqEntry(
    'Ownership',
    'How do I follow my application from my phone?',
    'Your dashboard is built for it: enter your application number and '
        'phone number, and see the live status, every recorded step, and a '
        'WhatsApp button that carries your number in the message. The link '
        'is permanent — bookmark it.',
  ),
];
