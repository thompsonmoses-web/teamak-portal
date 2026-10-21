import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../form/form_utils.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/shell.dart';

/// Status value → the words both staff pages and the applicant's dashboard
/// show for it.
String statusLabel(String status) => switch (status) {
      'submitted' => 'Submitted',
      'pending' => 'Under review',
      'approved' => 'Approved',
      'not_approved' => 'Not approved',
      'further_review' => 'Further review',
      _ => status,
    };

/// Programme id → the display line used on receipts and dashboards.
String programmeLabel(String programmeId) => switch (programmeId) {
      'okada_650' => 'Okada ownership — ₦650,000 / 3 months',
      'okada_400' => 'Okada ownership — ₦400,000 / 6 months',
      'maruwa_2300' => 'Maruwa ownership — ₦2,300,000 / 3 months',
      _ => programmeId,
    };

/// What the applicant sees after applying: their receipt, live status, the
/// history of changes and what happens next.
///
/// Three ways in — handed over by the wizard as `extra`, remembered on the
/// device from an earlier visit, or looked up through the tracking form in a
/// fresh browser. A refresh that loses `extra` falls back to the stored pair
/// instead of crashing on a missing route argument.
class ApplicantDashboardPage extends StatefulWidget {
  const ApplicantDashboardPage({super.key, required this.api, this.detail});

  final ApiClient api;

  /// Freshly submitted application from the wizard; null when opened cold.
  final ApplicationDetail? detail;

  @override
  State<ApplicantDashboardPage> createState() => _ApplicantDashboardPageState();
}

class _ApplicantDashboardPageState extends State<ApplicantDashboardPage> {
  /// Device-local pointer to the applicant's own application: the pair the
  /// API accepts, never a token — losing it costs a retyped form, not access.
  static const String _refKey = 'teamak_applicant_ref';

  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _phone = TextEditingController();

  ApplicationDetail? _detail;
  bool _loading = false;
  bool _viaForm = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final seed = widget.detail;
    if (seed != null) {
      _detail = seed;
      _remember(seed);
    } else {
      _restore();
    }
  }

  @override
  void dispose() {
    _number.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _remember(ApplicationDetail detail) async {
    final phone = '${detail.application['phoneNumber'] ?? ''}';
    if (phone.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _refKey,
        '{"applicationNo":"${detail.applicationNo}","phone":"$phone"}',
      );
    } catch (_) {
      // Storage is a convenience: a browser that refuses it only means the
      // applicant retypes the pair next visit, never a broken dashboard.
    }
  }

  Future<void> _forget() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_refKey);
    } catch (_) {
      // Nothing remembered is nothing to forget.
    }
    if (!mounted) return;
    setState(() {
      _detail = null;
      _error = null;
      _number.clear();
      _phone.clear();
    });
  }

  /// Loads the stored pair on a cold visit so returning applicants land on
  /// their dashboard without retyping anything.
  Future<void> _restore() async {
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(_refKey);
    } catch (_) {
      stored = null;
    }
    if (stored == null || !mounted) return;

    try {
      final ref = jsonDecodeRef(stored);
      await _track(
        applicationNo: '${ref['applicationNo'] ?? ''}',
        phone: '${ref['phone'] ?? ''}',
      );
    } catch (_) {
      // A corrupt pointer behaves like none: show the form and say so.
      await _forget();
      if (!mounted) return;
      setState(() {
        _error = 'We could not load your saved application — '
            'enter your details below.';
      });
    }
  }

  Future<void> _track({
    required String applicationNo,
    required String phone,
    bool viaForm = false,
  }) async {
    setState(() {
      _loading = true;
      _viaForm = viaForm;
      _error = null;
    });
    try {
      final detail = await widget.api.trackApplication(
        applicationNo: applicationNo.trim(),
        phone: phone.trim(),
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
      _remember(detail);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.statusCode == 404
            ? 'No application matches that number and phone number.'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not reach the server. Check your connection and '
            'try again.';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await _track(
      applicationNo: _number.text,
      phone: _phone.text,
      viaForm: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AppShell(
      title: 'Application dashboard',
      child: detail != null
          ? _buildDashboard(context, detail)
          : _loading && !_viaForm
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _buildForm(context),
    );
  }

  // ── Tracking form ──────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: EdgeInsets.all(wide ? 32 : 16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: EdgeInsets.all(wide ? 28 : 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      const Text(
                        'Find your application',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enter the application number from your receipt and '
                        'the phone number you applied with.',
                        style: TextStyle(color: TeamakColors.subtle),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Application number',
                          hintText: 'TRP-2026-0001',
                        ),
                        validator: (value) => requiredText(
                          value,
                          'Application number is required.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                        ),
                        validator: phoneValidator,
                        onFieldSubmitted: (_) => _submitForm(),
                      ),
                      if (_error != null) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          _error!,
                          style: const TextStyle(
                            color: TeamakColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _loading ? null : _submitForm,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_loading ? 'Searching…' : 'Track application'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dashboard ──────────────────────────────────────────────────────────

  Widget _buildDashboard(BuildContext context, ApplicationDetail detail) {
    final application = detail.application;
    final official = detail.official;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;
    // The wizard handed this page over in the same visit, so the header can
    // greet the applicant as a fresh submission.
    final fresh = widget.detail != null;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: EdgeInsets.all(wide ? 32 : 16),
          children: <Widget>[
            _HeaderCard(detail: detail, fresh: fresh),
            const SizedBox(height: 16),
            _StatStrip(detail: detail),
            const SizedBox(height: 20),
            _NextStepsCard(
              status: detail.status,
              phone: _value(application, 'phoneNumber'),
            ),
            const SizedBox(height: 20),
            _ProgressCard(detail: detail),
            if (_PreparationCard.appliesTo(application)) ...<Widget>[
              const SizedBox(height: 20),
              _PreparationCard(application: application),
            ],
            if (_hasOutcome(official)) ...<Widget>[
              const SizedBox(height: 20),
              _OutcomeCard(official: official),
            ],
            const SizedBox(height: 20),
            _QuickActionsCard(
              onWhatsApp: _chatOnWhatsApp,
              onPrint: _printReceipt,
              onTrackAnother: _forget,
              showTrackAnother: !fresh,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Your application',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Row(label: 'Applicant', value: _value(application, 'fullName')),
                    _Row(label: 'Phone', value: _value(application, 'phoneNumber')),
                    _Row(label: 'Area / Community', value: _value(application, 'areaCommunity')),
                    _Row(label: 'NIN', value: _value(application, 'nin')),
                    _Row(label: 'Programme', value: programmeLabel(detail.programmeId)),
                    _Row(label: 'Park / Association', value: _value(application, 'parkAssociationName')),
                    _Row(label: 'Submitted', value: _stamp(detail.createdAt)),
                    _Row(label: 'Status', value: statusLabel(detail.status)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _printReceipt() {
    // Printing is platform specific; fall back to a friendly message on web.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Use your browser\'s print dialog (Ctrl+P) to save this receipt.',
        ),
      ),
    );
  }

  /// Opens WhatsApp with the application number already in the draft message
  /// — the channel riders live on, and the context saves them the typing.
  Future<void> _chatOnWhatsApp() async {
    final detail = _detail;
    final text = detail == null
        ? 'Hello Teamak, I have a question about the Rider Ownership '
            'Programme.'
        : 'Hello Teamak, I am following up on my application '
            '${detail.applicationNo} (${statusLabel(detail.status)}).';
    final uri = Uri.parse(
      'https://wa.me/2348023449126?text=${Uri.encodeComponent(text)}',
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // No WhatsApp here (or the scheme is blocked) — the number is the
      // point, so give it rather than an error.
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

// ── Pieces ───────────────────────────────────────────────────────────────

/// The Section E checklist the applicant answered in the wizard, read back
/// as visit preparation: what they told us is already sorted, and what
/// still needs arranging before staff check the originals.
class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.application});

  final Map<String, dynamic> application;

  static const List<(String, String)> _items = <(String, String)>[
    ('hasPassportPhotograph', 'Passport photograph'),
    ('hasTwoPassportPhotographs', 'Two passport photographs'),
    ('hasGovernmentIdOrNinSlip', 'Government ID or NIN slip'),
    ('hasRiderOrAssociationRegistration', 'Rider or association registration'),
    ('hasProofOfResidentialAddress', 'Proof of residential address'),
  ];

  /// True when the payload carries any Section E answers — a submission
  /// without them shows no card rather than a hollow one.
  static bool appliesTo(Map<String, dynamic> application) =>
      _items.any((item) => application.containsKey(item.$1));

  @override
  Widget build(BuildContext context) {
    final answered =
        _items.where((item) => application.containsKey(item.$1)).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Getting ready for verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Staff will check the originals at your verification visit. '
              'Bring everything marked "Arrange".',
              style: TextStyle(color: TeamakColors.subtle, height: 1.5),
            ),
            const SizedBox(height: 12),
            for (final (key, label) in answered)
              _PreparationRow(label: label, ready: application[key] == true),
          ],
        ),
      ),
    );
  }
}

class _PreparationRow extends StatelessWidget {
  const _PreparationRow({required this.label, required this.ready});

  final String label;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    // Icon + wrapped label + short verdict: nothing fixed except the icon
    // and the 10px gaps, so 320px squeezes only the text.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            ready ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            size: 20,
            color: ready ? TeamakColors.primary : TeamakColors.accentDark,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          Text(
            ready ? 'Ready' : 'Arrange',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: ready ? TeamakColors.primary : TeamakColors.accentDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.detail, required this.fresh});

  final ApplicationDetail detail;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final status = detail.status;
    // The returning applicant gets a personal welcome; a fresh submission
    // still headlines its receipt.
    final name = '${detail.application['fullName'] ?? ''}'.trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    final title = fresh
        ? 'Application received'
        : firstName.isEmpty
            ? statusLabel(status)
            : 'Welcome back, $firstName';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: <Widget>[
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: TeamakColors.accent, width: 2.5),
              ),
              child: Icon(
                switch (status) {
                  'approved' => Icons.verified_rounded,
                  'not_approved' => Icons.cancel_rounded,
                  'further_review' => Icons.search_rounded,
                  _ => fresh
                      ? Icons.check_rounded
                      : Icons.hourglass_top_rounded,
                },
                color: status == 'not_approved'
                    ? TeamakColors.ink
                    : TeamakColors.primary,
                size: 52,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fresh ? 'Your application number is' : 'Application number',
              style: const TextStyle(color: TeamakColors.subtle),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: TeamakColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: TeamakColors.accent),
              ),
              child: Text(
                detail.applicationNo,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: TeamakColors.primaryDark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _StatusChip(status: status),
            if (fresh) ...<Widget>[
              const SizedBox(height: 12),
              const Text(
                'Keep this number safe. Our team will contact you for '
                'verification before any approval.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TeamakColors.subtle),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: TeamakColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusLabel(status),
        style: const TextStyle(
          color: TeamakColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The application's journey: every status change the API recorded, ending
/// with where it stands now.
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.detail});

  final ApplicationDetail detail;

  @override
  Widget build(BuildContext context) {
    final events = detail.events.whereType<Map>().toList();
    final lastTo = events.isEmpty
        ? null
        : '${events.last['toStatus'] ?? ''}';
    // The current status is worth its own entry only when the recorded
    // history has not already ended on it.
    final showCurrent = lastTo == null || lastTo != detail.status;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            for (final raw in events)
              _TimelineEntry(
                title:
                    '${statusLabel('${raw['fromStatus'] ?? ''}')} → '
                    '${statusLabel('${raw['toStatus'] ?? ''}')}',
                when: _stamp(raw['createdAt']),
              ),
            if (showCurrent)
              _TimelineEntry(
                title: statusLabel(detail.status),
                when: _stamp(detail.createdAt),
                current: true,
              ),

          ],
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.title,
    required this.when,
    this.current = false,
  });

  final String title;
  final String when;
  final bool current;

  @override
  Widget build(BuildContext context) {
    // The stamp is not allowed to shrink, so beside the entry it would push
    // the row past a phone's width; under it, the text simply wraps.
    final narrow = MediaQuery.sizeOf(context).width < 600;
    final dot = Icon(
      current ? Icons.radio_button_checked : Icons.circle,
      size: current ? 14 : 9,
      color: current ? TeamakColors.primary : TeamakColors.accent,
    );
    final heading = Row(
      children: <Widget>[
        SizedBox(width: 14, child: Center(child: dot)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontWeight: current ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
    final stamp = Text(
      when,
      style: const TextStyle(color: TeamakColors.subtle, fontSize: 12),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                heading,
                Padding(
                  padding: const EdgeInsets.only(left: 22, top: 2),
                  child: stamp,
                ),
              ],
            )
          : Row(
              children: <Widget>[
                Expanded(child: heading),
                const SizedBox(width: 12),
                stamp,
              ],
            ),
    );
  }
}

/// The four numbers an applicant checks first: where it stands, on what,
/// since when, and what comes next — the glanceable row that member
/// dashboards are built around.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.detail});

  final ApplicationDetail detail;

  /// The next thing to wait for, in the applicant's words: a delivery date
  /// once staff record one, otherwise the step the current status is
  /// working towards.
  String get _milestone {
    final delivery = '${detail.official['expectedDeliveryDate'] ?? ''}';
    if (delivery.isNotEmpty) return displayDate(delivery);
    return switch (detail.status) {
      'approved' => 'Handover',
      'pending' => 'Verification visit',
      'further_review' => 'Extra checks',
      'not_approved' => 'Next intake',
      _ => 'Team review',
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 680;
    final tiles = <(String, String, Color)>[
      ('Status', statusLabel(detail.status), TeamakColors.primary),
      (
        'Programme',
        _shortProgramme(programmeLabel(detail.programmeId)),
        TeamakColors.ink,
      ),
      (
        'Submitted',
        _stamp(detail.createdAt).split(' ').first,
        TeamakColors.ink,
      ),
      ('Next milestone', _milestone, TeamakColors.accentDark),
    ];

    Widget tile((String, String, Color) data) => Expanded(
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
                Text(
                  data.$1,
                  style: const TextStyle(
                    color: TeamakColors.subtle,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  data.$2,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.25,
                    color: data.$3,
                  ),
                ),
              ],
            ),
          ),
        );

    // Two tiles per row on a phone; one row of four on anything wider.
    if (wide) {
      return Row(
        children: <Widget>[
          for (var i = 0; i < tiles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 12),
            tile(tiles[i]),
          ],
        ],
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            tile(tiles[0]),
            const SizedBox(width: 12),
            tile(tiles[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            tile(tiles[2]),
            const SizedBox(width: 12),
            tile(tiles[3]),
          ],
        ),
      ],
    );
  }
}

/// Everything an applicant can do from the dashboard, gathered into one
/// card so the page reads like a portal rather than a receipt.
class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({
    required this.onWhatsApp,
    required this.onPrint,
    required this.onTrackAnother,
    this.showTrackAnother = true,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onPrint;
  final VoidCallback onTrackAnother;
  final bool showTrackAnother;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Quick actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Support, answers and your receipt — one tap away.',
              style: TextStyle(color: TeamakColors.subtle),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                // WhatsApp is the channel riders actually use, so it leads
                // and carries the application number in the first message.
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onWhatsApp,
                  icon: const Icon(Icons.chat_rounded),
                  label: const Text('Chat on WhatsApp'),
                ),
                OutlinedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Print receipt'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/faq'),
                  icon: const Icon(Icons.help_outline),
                  label: const Text('FAQ & help'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/contact'),
                  icon: const Icon(Icons.mail_outline),
                  label: const Text('Contact us'),
                ),
                if (showTrackAnother)
                  OutlinedButton.icon(
                    onPressed: onTrackAnother,
                    icon: const Icon(Icons.manage_search_outlined),
                    label: const Text('Track another application'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.home_outlined),
                  label: const Text('Back to home'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Section I outcomes worth showing on an applicant's dashboard. A fresh
/// application has none of them, so the "From our team" card stays hidden
/// until staff records one.
bool _hasOutcome(Map<String, dynamic> official) => const <String>[
      'verificationDate',
      'approvedProgrammeId',
      'approvedAmount',
      'expectedDeliveryDate',
    ].any((key) => official[key] != null && '${official[key]}'.isNotEmpty);

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.official});

  final Map<String, dynamic> official;

  bool _present(String key) => official[key] != null && '${official[key]}'.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      if (_present('verificationDate'))
        ('Verification date', displayDate('${official['verificationDate']}')),
      if (_present('approvedProgrammeId'))
        ('Approved programme', programmeLabel('${official['approvedProgrammeId']}')),
      if (_present('approvedAmount'))
        ('Approved amount', '₦${_group('${official['approvedAmount']}')}'),
      if (_present('expectedDeliveryDate'))
        ('Expected delivery', displayDate('${official['expectedDeliveryDate']}')),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'From our team',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              _Row(label: label, value: value),
          ],
        ),
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({required this.status, required this.phone});

  final String status;
  final String phone;

  ({String title, String body}) get _copy => switch (status) {
        'pending' => (
            title: 'Under review',
            body:
                'Your application is with our verification team. Please keep '
                    'your phone reachable on $phone — we will call to confirm '
                    'your details.',
          ),
        'further_review' => (
            title: 'More time needed',
            body:
                'We need a little more time to complete our checks. We will '
                    'reach out if we need anything from you.',
          ),
        'approved' => (
            title: 'Approved',
            body:
                'Congratulations — your application has been approved. Our '
                    'team will contact you about your deposit and the '
                    'handover of your vehicle.',
          ),
        'not_approved' => (
            title: 'Not approved',
            body:
                'This time we could not approve your application. Contact us '
                    'if you would like to know why, or apply again when the '
                    'next intake opens.',
          ),
        _ => (
            title: 'Application received',
            body:
                'Our team is reviewing your application. We will contact you '
                    'on $phone for verification before any approval.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final copy = _copy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              copy.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              copy.body,
              style: const TextStyle(color: TeamakColors.subtle, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(color: TeamakColors.subtle),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Missing answers read as `—` rather than the string `null`.
String _value(Map<String, dynamic> map, String key) {
  final text = '${map[key] ?? ''}';
  return text.isEmpty ? '—' : text;
}

/// Renders an ISO timestamp as `YYYY-MM-DD HH:MM`, tolerating short values.
String _stamp(Object? raw) {
  final text = '${raw ?? ''}'.replaceAll('T', ' ');
  return text.length >= 16 ? text.substring(0, 16) : (text.isEmpty ? '—' : text);
}

/// 650000 → 650,000, without pulling in number formatting for one field.
String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// 'Okada ownership — ₦650,000 / 3 months' → 'Okada ownership': the short
/// form the dashboard's stat tiles carry; the full line lives in the
/// summary below them.
String _shortProgramme(String label) => label.split(' — ').first;

/// Parses the stored `{applicationNo, phone}` pair, rejecting anything else
/// so a corrupted value falls back to the tracking form instead of a map of
/// nulls.
Map<String, dynamic> jsonDecodeRef(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw const FormatException('not an application reference');
  }
  return Map<String, dynamic>.from(decoded);
}
