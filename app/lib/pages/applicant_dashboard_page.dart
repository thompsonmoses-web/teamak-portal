import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../form/form_utils.dart';
import '../models/models.dart';
import '../theme.dart';
import '../util/download_stub.dart'
    if (dart.library.js_interop) '../util/download_web.dart';
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
  const ApplicantDashboardPage({
    super.key,
    required this.api,
    this.detail,
    this.prefillNumber,
  });

  final ApiClient api;

  /// Freshly submitted application from the wizard; null when opened cold.
  final ApplicationDetail? detail;

  /// Carried by a shared tracking link so the form opens with the number
  /// already filled in — the phone check still happens on every device.
  final String? prefillNumber;

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

  /// Where the device lock lives, beside the stored pair.
  static const String _pinKey = 'teamak_dashboard_pin';

  /// Whether this device holds the stored pair — the account card says so.
  bool _remembered = false;

  /// The device-only dashboard lock; null means no PIN has been set.
  String? _pin;

  /// A PIN-protected session opens locked — except straight from the
  /// wizard, where the fresh applicant has just proven themselves by
  /// filing the form.
  bool _pinUnlocked = true;

  @override
  void initState() {
    super.initState();
    // A shared tracking link fills the number so only the phone check
    // remains for the visitor on the receiving end.
    _number.text = widget.prefillNumber ?? '';
    final seed = widget.detail;
    if (seed != null) {
      _detail = seed;
      _remember(seed);
      _loadPinFlag();
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
    // Optimistic: the catch below corrects it if storage refuses, and the
    // next build of the account card picks the flag up either way.
    _remembered = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _refKey,
        '{"applicationNo":"${detail.applicationNo}","phone":"$phone"}',
      );
    } catch (_) {
      // Storage is a convenience: a browser that refuses it only means the
      // applicant retypes the pair next visit, never a broken dashboard.
      _remembered = false;
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
      _remembered = false;
      _number.clear();
      _phone.clear();
      // A forgotten device still opens links that carry their number.
      _number.text = widget.prefillNumber ?? '';
    });
  }

  /// Loads the stored pair on a cold visit so returning applicants land on
  /// their dashboard without retyping anything.
  Future<void> _restore() async {
    String? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = prefs.getString(_refKey);
      _pin = prefs.getString(_pinKey);
    } catch (_) {
      stored = null;
    }
    // A saved pair plus a saved PIN means the dashboard opens locked.
    _pinUnlocked = _pin == null;
    if (stored == null || !mounted) return;
    _remembered = true;

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

  /// Reads whether a lock exists, for the account card on a fresh visit.
  Future<void> _loadPinFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pin = prefs.getString(_pinKey);
      if (!mounted) return;
      setState(() => _pin = pin);
    } catch (_) {
      // No storage, no lock.
    }
  }

  Future<void> _setPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinKey, pin);
    } catch (_) {
      // The session still holds it for this visit even without storage.
    }
    if (!mounted) return;
    setState(() {
      _pin = pin;
      _pinUnlocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN lock saved for this device.')),
    );
  }

  Future<void> _clearPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pinKey);
    } catch (_) {
      // Nothing stored is nothing to clear.
    }
    if (!mounted) return;
    setState(() {
      _pin = null;
      _pinUnlocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN lock turned off for this device.')),
    );
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

  /// The lock in front of a PIN-protected dashboard on this device.
  Widget _buildPinGate() => _PinGate(
        pin: _pin!,
        onUnlocked: () => setState(() => _pinUnlocked = true),
        onRemovePin: _clearPin,
      );

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return AppShell(
      title: 'Application dashboard',
      child: detail != null
          ? (!_pinUnlocked && _pin != null)
              ? _buildPinGate()
              : _buildDashboard(context, detail)
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
            _JourneyCard(status: detail.status),
            const SizedBox(height: 20),
            _PlanCard(programmeId: detail.programmeId),
            const SizedBox(height: 20),
            _CommitmentCard(application: application),
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
              onInvite: _inviteRider,
              onSave: _saveReceipt,
              onTrackAnother: _forget,
              showTrackAnother: !fresh,
            ),
            const SizedBox(height: 20),
            _AccountCard(
              applicationNo: detail.applicationNo,
              remembered: _remembered,
              pin: _pin,
              onForget: _forget,
              onSetPin: () async {
                final saved = await showDialog<String>(
                  context: context,
                  builder: (_) => _PinSetupDialog(change: _pin != null),
                );
                if (saved == null || !mounted) return;
                await _setPin(saved);
              },
              onClearPin: _clearPin,
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
                    ..._riderGroup(application),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveReceipt() {
    final detail = _detail;
    if (detail == null) return;
    final filename = 'Teamak-${detail.applicationNo}.txt';
    try {
      saveTextDownload(filename, receiptText(detail));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Receipt saved — $filename')),
      );
    } catch (_) {
      // No downloads here (or the browser blocked one): the dashboard
      // itself is the receipt, so say so rather than fail.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This device cannot save files — screenshot this dashboard '
            'instead.',
          ),
        ),
      );
    }
  }

  /// Opens WhatsApp with the application number already in the draft message
  /// — the channel riders live on, and the context saves them the typing.
  Future<void> _chatOnWhatsApp() {
    final detail = _detail;
    return _openWhatsApp(
      number: '2348023449126',
      text: detail == null
          ? 'Hello Teamak, I have a question about the Rider Ownership '
              'Programme.'
          : followUpText(detail.applicationNo, detail.status),
    );
  }

  /// Passes the portal on to another rider — the referral move every
  /// investment-club app keeps one tap from the dashboard. The link is
  /// resolved against the current page, so it keeps this deployment's
  /// base path instead of falling to the domain root.
  Future<void> _inviteRider() => _openWhatsApp(
        text: 'Riders wanted: apply for the Teamak Rider Ownership '
            'Programme and own your machine. '
            '${Uri.base.resolve('#/apply')}',
      );

  Future<void> _openWhatsApp({String number = '', required String text}) async {
    final uri = Uri.parse(
      'https://wa.me/$number?text=${Uri.encodeComponent(text)}',
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: TeamakColors.gradPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: TeamakColors.accent.withValues(alpha: 0.55),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: TeamakColors.accent, width: 2),
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
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      fresh
                          ? 'Your application number is'
                          : 'Application number',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // The number is both the applicant's credential and what they
          // quote to us on WhatsApp — one tap copies it.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                // Confirm first: the number is on screen either way, so a
                // platform without a clipboard still gets its message —
                // and a test binding that never answers the channel does
                // not stall the feedback.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${detail.applicationNo} copied'),
                  ),
                );
                Clipboard.setData(
                  ClipboardData(text: detail.applicationNo),
                ).ignore();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: TeamakColors.accent),
                    ),
                    child: Text(
                      detail.applicationNo,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: TeamakColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.copy_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tap the number to copy it',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              // Gold pill on the dark hero: the status reads at a glance,
              // same weight the preview banner gives its own strip.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: TeamakColors.accent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel(status),
                  style: const TextStyle(
                    color: TeamakColors.primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'Submitted ${_stamp(detail.createdAt).split(' ').first}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (fresh) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Keep this number safe. Our team will contact you for '
              'verification before any approval.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ],
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

/// How far the application has moved and what stage comes next — the
/// progress bar investment dashboards put directly under their balance,
/// reading the status as one journey in four steps.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.status});

  final String status;

  ({double progress, int step, String stage, String hint}) get _journey =>
      switch (status) {
        'submitted' => (
            progress: 0.15,
            step: 1,
            stage: 'Submitted',
            hint: 'Received — queued for the team\u2019s first look.',
          ),
        'pending' => (
            progress: 0.4,
            step: 2,
            stage: 'Under review',
            hint: 'Checks underway — keep your phone reachable.',
          ),
        'further_review' => (
            progress: 0.65,
            step: 3,
            stage: 'Further review',
            hint: 'A little more time is needed to finish our checks.',
          ),
        'approved' => (
            progress: 1,
            step: 4,
            stage: 'Approved',
            hint: 'Deposit and handover are next — we will call you.',
          ),
        'not_approved' => (
            progress: 1,
            step: 4,
            stage: 'Not approved',
            hint: 'Not this time — the next intake is always open.',
          ),
        _ => (
            progress: 0.15,
            step: 1,
            stage: statusLabel(status),
            hint: 'We will update this as your application moves.',
          ),
      };

  @override
  Widget build(BuildContext context) {
    final journey = _journey;
    // The bar wears the programme's gold by default: blue once it lands
    // (approved), red when it stops (not approved).
    final barColor = switch (status) {
      'approved' => TeamakColors.primary,
      'not_approved' => TeamakColors.danger,
      _ => TeamakColors.accent,
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Application journey',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Step ${journey.step} of 4',
                  style: const TextStyle(
                    color: TeamakColors.subtle,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: journey.progress,
                minHeight: 8,
                backgroundColor: TeamakColors.surface3,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              journey.stage,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              journey.hint,
              style: const TextStyle(color: TeamakColors.subtle, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

/// The track the applicant chose, shown like an asset card: what machine,
/// what deposit, how long — parsed from the same line the receipts print,
/// so no extra request can make it disagree with the summary below.
class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.programmeId});

  final String programmeId;

  @override
  Widget build(BuildContext context) {
    final full = programmeLabel(programmeId);
    final parts = full.split(' — ');
    if (parts.length < 2) return const SizedBox.shrink();
    final name = parts.first;
    final terms = parts[1].split(' / ');
    final amount = terms.first;
    final duration = terms.length > 1 ? terms[1] : '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Your plan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                // The machine itself, not a generic icon — the same renders
                // the landing page showcases for this tier.
                Container(
                  width: 52,
                  height: 52,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: TeamakColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Image.asset(
                    programmeId.startsWith('maruwa')
                        ? 'assets/slides/tricycle.png'
                        : 'assets/slides/motorcycle.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$amount deposit',
                        style: const TextStyle(
                          color: TeamakColors.subtle,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (duration.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: TeamakColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: TeamakColors.accent),
                    ),
                    child: Text(
                      duration,
                      style: const TextStyle(
                        color: TeamakColors.primaryDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// What the applicant committed to in the funding step: the one-time
/// deposit figure, the date they expect to pay it and how they plan to
/// raise it — their own answers, kept in view while the application is
/// under review.
class _CommitmentCard extends StatelessWidget {
  const _CommitmentCard({required this.application});

  final Map<String, dynamic> application;

  /// The wizard stores the figure either as the programme's deposit number
  /// or as the string form of it; either way it reads back as whole naira.
  int? get _amount {
    final raw = application['amountToCommit'];
    if (raw is num) return raw.toInt();
    final digits = '${raw ?? ''}'.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? null : int.tryParse(digits);
  }

  DateTime? get _due =>
      DateTime.tryParse('${application['expectedDepositDate'] ?? ''}');

  /// The wizard's chips save codes; older records carry the plain words
  /// already. Both read back as one line.
  String? get _sources {
    final raw = application['sourceOfFunds'];
    final labels = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final key = '$item';
        if (key == 'other') {
          final extra = '${application['sourceOfFundsOther'] ?? ''}'.trim();
          labels.add(extra.isEmpty ? 'Other' : extra);
        } else {
          labels.add(_fundSources[key] ?? key);
        }
      }
    } else {
      final text = '${raw ?? ''}'.trim();
      if (text.isNotEmpty) labels.add(text);
    }
    return labels.isEmpty ? null : labels.join(', ');
  }

  static const _fundSources = <String, String>{
    'personal_savings': 'Personal savings',
    'business_income': 'Business income',
    'family_support': 'Family support',
  };

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    final due = _due;
    final sources = _sources;
    // Nothing promised without a figure or a date: records that predate
    // the funding step simply carry no card.
    if (amount == null && due == null) return const SizedBox.shrink();

    final countdown = due == null ? null : depositCountdown(due);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Your commitment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Same gold pill the plan's duration badge wears.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: TeamakColors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: TeamakColors.accent),
                  ),
                  child: const Text(
                    'One-time',
                    style: TextStyle(
                      color: TeamakColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
            if (amount != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                '₦${_group('$amount')}',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: TeamakColors.primaryDark,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'One deposit only — no further payment for the vehicle.',
                style: TextStyle(
                  color: TeamakColors.subtle,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ],
            if (due != null) ...<Widget>[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _FundingRow(
                icon: Icons.event_outlined,
                label: 'Expected deposit date',
                value: displayDate(isoDate(due)),
                chip: countdown,
              ),
            ],
            if (due != null && sources != null) const SizedBox(height: 12),
            if (sources != null)
              _FundingRow(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Source of funds',
                value: sources,
              ),
          ],
        ),
      ),
    );
  }
}

/// One funding fact: icon, label and value, with an optional countdown
/// pill whose fixed width shrinks the text beside it, never the row.
class _FundingRow extends StatelessWidget {
  const _FundingRow({
    required this.icon,
    required this.label,
    required this.value,
    this.chip,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? chip;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 20, color: TeamakColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(
                  color: TeamakColors.subtle,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (chip != null) ...<Widget>[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: TeamakColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chip!,
                        style: const TextStyle(
                          color: TeamakColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
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
    required this.onInvite,
    required this.onSave,
    required this.onTrackAnother,
    this.showTrackAnother = true,
  });

  final VoidCallback onWhatsApp;
  final VoidCallback onInvite;
  final VoidCallback onSave;
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
                  onPressed: onInvite,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Invite a rider'),
                ),
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('Save receipt'),
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

/// Links, device memory and the PIN lock: the account half of a member
/// profile, built from what the dashboard already knows about itself.
class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.applicationNo,
    required this.remembered,
    required this.pin,
    required this.onForget,
    required this.onSetPin,
    required this.onClearPin,
  });

  final String applicationNo;
  final bool remembered;
  final String? pin;
  final VoidCallback onForget;
  final VoidCallback onSetPin;
  final VoidCallback onClearPin;

  /// The applicant's own tracking form with the number pre-filled: the
  /// link a rider saves to their WhatsApp so a new phone opens to it.
  String get _link =>
      Uri.base.resolve('#/dashboard?no=$applicationNo').toString();

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(
      color: TeamakColors.subtle,
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
    );
    const valueStyle = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Account & security',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your links, this device and the lock on it.',
              style: TextStyle(color: TeamakColors.subtle),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.smartphone,
                  size: 20,
                  color: TeamakColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('This device', style: labelStyle),
                      const SizedBox(height: 2),
                      Text(
                        remembered
                            ? 'Remembers $applicationNo'
                            : 'Nothing saved',
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (remembered)
              Padding(
                padding: const EdgeInsets.only(left: 30, top: 2),
                child: TextButton(
                  onPressed: onForget,
                  child: const Text('Forget'),
                ),
              ),
            const SizedBox(height: 10),
            const Text('Tracking link', style: labelStyle),
            const SizedBox(height: 6),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  // Confirm first: a test binding (or a locked-down
                  // browser) that never answers the clipboard channel must
                  // not stall the feedback.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking link copied')),
                  );
                  Clipboard.setData(ClipboardData(text: _link)).ignore();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: TeamakColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: TeamakColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _link,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: TeamakColors.ink,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.link,
                        size: 16,
                        color: TeamakColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Copy it to open your tracking form on another phone — your '
              'number comes filled in, and every device still checks your '
              'phone number.',
              style: TextStyle(
                color: TeamakColors.subtle,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: TeamakColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text('Dashboard PIN', style: labelStyle),
                      const SizedBox(height: 2),
                      Text(
                        pin != null ? 'On for this device' : 'Off',
                        style: valueStyle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (pin == null)
              OutlinedButton(
                onPressed: onSetPin,
                child: const Text('Turn on'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: <Widget>[
                  OutlinedButton(
                    onPressed: onSetPin,
                    child: const Text('Change'),
                  ),
                  TextButton(
                    onPressed: onClearPin,
                    child: const Text('Turn off'),
                  ),
                ],
              ),
            const SizedBox(height: 6),
            const Text(
              'A 4-digit lock for this device only — not your Teamak '
              'account password.',
              style: TextStyle(color: TeamakColors.subtle, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for the four digits twice, so a slip of the finger cannot set a
/// PIN the rider then cannot open with.
class _PinSetupDialog extends StatefulWidget {
  const _PinSetupDialog({required this.change});

  /// True when a lock already exists — the title then promises a change.
  final bool change;

  @override
  State<_PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<_PinSetupDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final first = _pin.text.trim();
    final second = _confirm.text.trim();
    setState(() {
      _error = first.length != 4 || second.length != 4
          ? 'Enter 4 digits in both fields.'
          : first != second
              ? 'PINs do not match.'
              : null;
    });
    if (_error == null) Navigator.of(context).pop(first);
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool showErrors = false,
  }) =>
      TextField(
        controller: controller,
        obscureText: true,
        maxLength: 4,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, letterSpacing: 6),
        decoration: InputDecoration(
          labelText: label,
          counterText: '',
          // One place to read the problem: under the confirm field.
          errorText: showErrors ? _error : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.change ? 'Change your dashboard PIN' : 'Set a dashboard PIN',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _field(_pin, 'New 4-digit PIN'),
          const SizedBox(height: 12),
          _field(_confirm, 'Confirm PIN', showErrors: true),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save PIN')),
      ],
    );
  }
}

/// What a PIN-protected dashboard shows first on this device.
class _PinGate extends StatefulWidget {
  const _PinGate({
    required this.pin,
    required this.onUnlocked,
    required this.onRemovePin,
  });

  final String pin;
  final VoidCallback onUnlocked;
  final VoidCallback onRemovePin;

  @override
  State<_PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<_PinGate> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _unlock() {
    if (_controller.text == widget.pin) {
      widget.onUnlocked();
      return;
    }
    setState(() {
      _error = 'Incorrect PIN — try again.';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: TeamakColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: TeamakColors.accent),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: TeamakColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Dashboard locked',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter the 4-digit PIN set for this device.',
                    style: TextStyle(color: TeamakColors.subtle),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    obscureText: true,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8),
                    decoration: InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _unlock(),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.lock_open_rounded),
                      label: const Text('Unlock'),
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onRemovePin,
                    child: const Text('Forgot PIN? Remove it'),
                  ),
                  const Text(
                    'This PIN locks the dashboard on this device only — '
                    'it is not your Teamak password.',
                    style: TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 12,
                      height: 1.4,
                    ),
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

/// The Section B answers, when the applicant gave them: a ruled-off group
/// under the summary so the account reads like the profile it is.
List<Widget> _riderGroup(Map<String, dynamic> app) {
  final rows = <Widget>[];
  void add(String key, String label, String Function(String) format) {
    final raw = '${app[key] ?? ''}'.trim();
    if (raw.isEmpty) return;
    rows.add(_Row(label: label, value: format(raw)));
  }

  add('dateOfBirth', 'Date of birth', displayDate);
  add('operationType', 'Type of operation', _operationLabel);
  add('ridingExperience', 'Riding experience', _experienceLabel);
  add('vehicleMakeModel', 'Vehicle', (value) => value);
  add('parkRouteOperatingArea', 'Park / route', (value) => value);
  add('averageWorkingDaysPerWeek', 'Working days / week', (value) => value);
  if (rows.isEmpty) return const <Widget>[];

  return <Widget>[
    const SizedBox(height: 12),
    const Divider(height: 1),
    const SizedBox(height: 12),
    const Text(
      'Riding details',
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 2),
    ...rows,
  ];
}

/// Section B codes → the wizard's own words; values already written in
/// readable form pass through untouched.
String _operationLabel(String raw) => switch (raw) {
      'okada' => 'Okada (motorcycle)',
      'maruwa' => 'Maruwa (tricycle)',
      _ => raw,
    };

String _experienceLabel(String raw) => switch (raw) {
      'lt1' => 'Less than 1 year',
      'y1_3' => '1–3 years',
      'y4_6' => '4–6 years',
      'y7_plus' => '7+ years',
      _ => raw,
    };

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

/// Whole days to the deposit date, in the words the funding card's chip
/// reads: nothing once the date has passed — the row still shows the date
/// itself, plainly.
String? depositCountdown(DateTime due, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final days = DateTime(due.year, due.month, due.day)
      .difference(DateTime(ref.year, ref.month, ref.day))
      .inDays;
  return switch (days) {
    0 => 'due today',
    1 => 'due tomorrow',
    > 1 => 'in $days days',
    _ => null,
  };
}

/// The follow-up a status implies, ready to send: an approved rider
/// announces readiness for the deposit and handover, a declined one asks
/// for the reason and the next intake, everyone else simply follows up.
String followUpText(String applicationNo, String status) {
  final head = 'Hello Teamak, I am following up on my application '
      '$applicationNo (${statusLabel(status)}).';
  return switch (status) {
    'approved' => '$head I am ready for the deposit and handover — '
        'please tell me the next step.',
    'not_approved' => '$head Please, can you tell me why, and when '
        'I may apply again?',
    _ => head,
  };
}

/// A plain-text receipt the applicant can keep and forward: what the team
/// holds and where it stands, in tidy label/value lines. The NIN stays
/// out — this file is the one thing on the dashboard meant to leave the
/// device, and it travels to park chairmen and family chats.
String receiptText(ApplicationDetail detail) {
  final app = detail.application;
  String cell(String key) => '${app[key] ?? ''}'.trim();

  final amount = cell('amountToCommit').replaceAll(RegExp(r'[^0-9]'), '');
  final dueDate = cell('expectedDepositDate');
  final lines = <String>[
    'TEAMAK RIDER OWNERSHIP PROGRAMME',
    'Application receipt',
    '',
    '${'Application no:'.padRight(20)}${detail.applicationNo}',
    '${'Submitted:'.padRight(20)}${_stamp(detail.createdAt)}',
    '${'Status:'.padRight(20)}${statusLabel(detail.status)}',
    '${'Programme:'.padRight(20)}${programmeLabel(detail.programmeId)}',
    '${'Deposit amount:'.padRight(20)}'
        '${amount.isEmpty ? '—' : '₦${_group(amount)}'}',
    '${'Deposit date:'.padRight(20)}'
        '${dueDate.isEmpty ? '—' : displayDate(dueDate)}',
    '',
    '${'Applicant:'.padRight(20)}${cell('fullName')}',
    '${'Phone:'.padRight(20)}${cell('phoneNumber')}',
    '${'Area / Community:'.padRight(20)}${cell('areaCommunity')}',
    '${'Park / Association:'.padRight(20)}${cell('parkAssociationName')}',
    '',
    'Questions? Call or WhatsApp +234 802 344 9126 with your',
    'application number.',
    '',
    'Teamak Global Solution',
  ];
  return lines.join('\n');
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
