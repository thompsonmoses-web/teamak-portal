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
    this.prefillPhone,
  });

  final ApiClient api;

  /// Freshly submitted application from the wizard; null when opened cold.
  final ApplicationDetail? detail;

  /// Carried by a shared tracking link so the form opens with the number
  /// already filled in — the phone check still happens on every device.
  final String? prefillNumber;

  /// Demo showcase links only: the route drops this on real builds, so
  /// the pair check can never be skipped by a crafted URL there.
  final String? prefillPhone;

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

  /// When the record on screen was last pulled from the API.
  DateTime? _checkedAt;

  /// Which rail entry is lit — the section it last jumped to.
  String _navId = 'overview';

  /// One key per real section card, so the desktop rail can scroll the
  /// page to it. Every entry the rail offers exists as a card below;
  /// nothing is navigable that is not on the screen.
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{
    'overview': GlobalKey(),
    'journey': GlobalKey(),
    'plan': GlobalKey(),
    'handover': GlobalKey(),
    'history': GlobalKey(),
    'support': GlobalKey(),
    'account': GlobalKey(),
  };

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
    } else if (widget.prefillPhone != null &&
        (widget.prefillNumber ?? '').isNotEmpty) {
      // A demo showcase link carries the whole pair, so a shared demo URL
      // opens the record it names with no typing. Only demo builds pass a
      // phone at all — the route drops it on real builds — and the pair
      // is still checked, against the API: a wrong pair falls back to the
      // form with both fields filled and the answer on screen.
      _phone.text = widget.prefillPhone!;
      // Silent-loading before the first frame: the spinner shows, never a
      // flash of the form. The fetch waits for that frame to finish, and
      // a device lock is honoured before the record is drawn.
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final prefs = await SharedPreferences.getInstance();
          _pin = prefs.getString(_pinKey);
          _pinUnlocked = _pin == null;
        } catch (_) {
          // No storage, no lock.
        }
        if (!mounted) return;
        await _track(
          applicationNo: widget.prefillNumber!,
          phone: widget.prefillPhone!,
        );
      });
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
      // A forgotten device still opens links that carry their pair.
      _number.text = widget.prefillNumber ?? '';
      _phone.text = widget.prefillPhone ?? '';
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
        _error =
            'We could not load your saved application — '
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
        _checkedAt = DateTime.now();
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
        _error =
            'Could not reach the server. Check your connection and '
            'try again.';
      });
    }
  }

  /// Pulls the record again — the same pair, a fresh answer. The old
  /// data stays on screen if the network refuses.
  Future<void> _refresh() async {
    final detail = _detail;
    if (detail == null || _loading) return;
    setState(() => _loading = true);
    try {
      final fresh = await widget.api.trackApplication(
        applicationNo: detail.applicationNo,
        phone: '${detail.application['phoneNumber'] ?? ''}',
      );
      if (!mounted) return;
      setState(() {
        _detail = fresh;
        _loading = false;
        _checkedAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not refresh — showing the last details loaded.'),
        ),
      );
    }
  }

  /// Lights the tapped rail entry and brings its section into view. The
  /// body builds eagerly, so every anchor has a context to scroll to.
  void _jumpTo(String id) {
    setState(() => _navId = id);
    final anchor = _anchors[id]?.currentContext;
    if (anchor == null) return;
    Scrollable.ensureVisible(
      anchor,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.05,
    );
  }

  /// The member's first initial, for the rail and top-bar avatars.
  String get _initial {
    final name = '${_detail?.application['fullName'] ?? ''}'.trim();
    return name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
  }

  /// Signing out only drops this device's pointer — the application stays
  /// with Teamak — so the confirmation says exactly that, and the same
  /// forget the form offers does the work.
  Future<void> _confirmSignOut() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out of this device?'),
        content: const Text(
          'Your application stays with Teamak — this device just stops '
          'remembering it. You can track it again with your number and '
          'your phone number.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) await _forget();
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
    final locked = detail != null && !_pinUnlocked && _pin != null;

    // The loaded, unlocked dashboard wears the reference's app shell on a
    // desktop — member rail, white top bar, tinted canvas. The tracking
    // form, the loading spinner and the PIN lock keep the site chrome:
    // they are ways in, not the overview itself.
    if (detail != null && !locked && MediaQuery.sizeOf(context).width >= 1024) {
      return _buildFrame(detail);
    }

    return AppShell(
      title: 'Application dashboard',
      child: detail != null
          ? locked
                ? _buildPinGate()
                : _dashboardBody(context, detail)
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

  /// The desktop chrome: a fixed member rail, a white top bar and the
  /// overview on its tinted canvas — the layout the reference screenshots
  /// show, built only from navigation this page really has.
  Widget _buildFrame(ApplicationDetail detail) => Scaffold(
    body: Row(
      children: <Widget>[
        _SideNav(
          detail: detail,
          selected: _navId,
          onSelect: _jumpTo,
          onSignOut: _confirmSignOut,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _TopBar(
                loading: _loading,
                onRefresh: _refresh,
                initial: _initial,
              ),
              Expanded(child: _dashboardBody(context, detail)),
            ],
          ),
        ),
      ],
    ),
  );

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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search),
                        label: Text(
                          _loading ? 'Searching…' : 'Track application',
                        ),
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

  /// The overview itself — greeting, numbers, banner and every card — on
  /// the tinted canvas the reference uses. One eagerly built scroll body,
  /// so the desktop rail's jump-to-section always finds its anchor.
  Widget _dashboardBody(BuildContext context, ApplicationDetail detail) {
    final application = detail.application;
    final official = detail.official;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;
    // The wizard handed this page over in the same visit, so the header can
    // greet the applicant as a fresh submission.
    final fresh = widget.detail != null;

    return Container(
      color: _dashboardCanvas,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                KeyedSubtree(
                  key: _anchors['overview'],
                  child: _OverviewHeader(detail: detail, fresh: fresh),
                ),
                const SizedBox(height: 18),
                _StatStrip(detail: detail),
                const SizedBox(height: 16),
                // What is happening right now sits directly under the numbers,
                // before the deeper cards — the reference layout's order.
                _NextStepsCard(
                  status: detail.status,
                  phone: _value(application, 'phoneNumber'),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _anchors['journey'],
                  child: _JourneyCard(status: detail.status),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _anchors['plan'],
                  child: _PlanCard(programmeId: detail.programmeId),
                ),
                const SizedBox(height: 20),
                _CommitmentCard(application: application),
                const SizedBox(height: 20),
                // The approved rider's forward view — money and timing for
                // the handover — sits beside the commitment it pays into.
                if (detail.status == 'approved') ...<Widget>[
                  KeyedSubtree(
                    key: _anchors['handover'],
                    child: _HandoverCard(
                      official: official,
                      onReady: _chatOnWhatsApp,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                KeyedSubtree(
                  key: _anchors['history'],
                  child: _ProgressCard(detail: detail),
                ),
                if (_PreparationCard.appliesTo(application)) ...<Widget>[
                  const SizedBox(height: 20),
                  _PreparationCard(application: application),
                ],
                if (_hasOutcome(official)) ...<Widget>[
                  const SizedBox(height: 20),
                  _OutcomeCard(official: official, status: detail.status),
                ],
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _anchors['support'],
                  child: _QuickActionsCard(
                    onWhatsApp: _chatOnWhatsApp,
                    onInvite: _inviteRider,
                    onSave: _saveReceipt,
                    onTrackAnother: _forget,
                    showTrackAnother: !fresh,
                  ),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(
                  key: _anchors['account'],
                  child: _AccountCard(
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
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 24 : 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            const Expanded(
                              child: Text(
                                'Your application',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (_checkedAt != null)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  'Checked ${_clock(_checkedAt!)}',
                                  style: const TextStyle(
                                    color: TeamakColors.subtle,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: _loading ? null : _refresh,
                              iconSize: 20,
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Refresh',
                              icon: _loading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _Row(
                          label: 'Applicant',
                          value: _value(application, 'fullName'),
                        ),
                        _Row(
                          label: 'Phone',
                          value: _value(application, 'phoneNumber'),
                        ),
                        _Row(
                          label: 'Area / Community',
                          value: _value(application, 'areaCommunity'),
                        ),
                        _Row(label: 'NIN', value: _value(application, 'nin')),
                        _Row(
                          label: 'Programme',
                          value: programmeLabel(detail.programmeId),
                        ),
                        _Row(
                          label: 'Park / Association',
                          value: _value(application, 'parkAssociationName'),
                        ),
                        _Row(
                          label: 'Submitted',
                          value: _stamp(detail.createdAt),
                        ),
                        _Row(
                          label: 'Status',
                          value: statusLabel(detail.status),
                        ),
                        ..._riderGroup(application),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Receipt saved — $filename')));
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
    text:
        'Riders wanted: apply for the Teamak Rider Ownership '
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

/// The overview canvas — the reference's soft tint, in Teamak blue: on it
/// the white cards read as cards instead of dissolving into the page.
const Color _dashboardCanvas = Color(0xFFEDF3FC);

/// The desktop rail: who is signed in, where to jump to, and the way out.
/// Every entry scrolls a real card of this page into view — the rail
/// navigates within one page, exactly like the reference layout, and
/// offers no destination the dashboard does not contain.
class _SideNav extends StatelessWidget {
  const _SideNav({
    required this.detail,
    required this.selected,
    required this.onSelect,
    required this.onSignOut,
  });

  final ApplicationDetail detail;
  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onSignOut;

  /// MAIN — the overview's own sections, in the order they appear.
  static const List<(String, IconData, String)> _main =
      <(String, IconData, String)>[
        ('overview', Icons.dashboard_outlined, 'Overview'),
        ('journey', Icons.route_outlined, 'Journey'),
        ('plan', Icons.directions_bike_outlined, 'My plan'),
        ('history', Icons.timeline_outlined, 'Status history'),
      ];

  /// ACCOUNT — what this page lets the member do.
  static const List<(String, IconData, String)> _account =
      <(String, IconData, String)>[
        ('support', Icons.support_agent_outlined, 'Support'),
        ('account', Icons.settings_outlined, 'Account'),
      ];

  /// The status dot: brand blue while it moves, gold while it waits, red
  /// once it stops — the reference's live dot, in Teamak's colours.
  Color get _dot => switch (detail.status) {
    'approved' => TeamakColors.primary,
    'not_approved' => TeamakColors.danger,
    _ => TeamakColors.accent,
  };

  @override
  Widget build(BuildContext context) {
    final name = '${detail.application['fullName'] ?? ''}'.trim();
    final initial = name.isEmpty ? '' : name.substring(0, 1).toUpperCase();
    // Handover is a real card only on an approved record, so the rail
    // offers the jump only then.
    final entries = <(String, IconData, String)>[
      ..._main,
      if (detail.status == 'approved')
        ('handover', Icons.local_shipping_outlined, 'Handover'),
    ];

    return Container(
      width: 264,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: TeamakColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // At normal window heights the rail fits whole and stays a plain
          // column — which keeps the overview's own scroll view first in
          // the tree. Only a short window scrolls the rail itself.
          final bounded = constraints.hasBoundedHeight;
          final fits = !bounded || constraints.maxHeight >= 680;
          final column = Column(
            mainAxisSize: bounded && fits ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: <Widget>[
                    _RailLogo(),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'TEAMAK GLOBAL\nSOLUTIONS',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          height: 1.15,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // The member chip: avatar, name, the number they quote to
              // us, and the live status dot.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Row(
                  children: <Widget>[
                    _Avatar(initial: initial, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            name.isEmpty ? 'Applicant' : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            detail.applicationNo,
                            style: const TextStyle(
                              color: TeamakColors.subtle,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _dot,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const _RailSection('MAIN'),
              for (final entry in entries)
                _RailItem(entry: entry, selected: selected, onSelect: onSelect),
              const _RailSection('ACCOUNT'),
              for (final entry in _account)
                _RailItem(entry: entry, selected: selected, onSelect: onSelect),
              if (bounded && fits) const Spacer(),
              const SizedBox(height: 12),
              const Divider(height: 1),
              _SignOutTile(onSignOut: onSignOut),
            ],
          );
          if (fits) return column;
          return SingleChildScrollView(child: column);
        },
      ),
    );
  }
}

/// One caps heading in the rail's navigation.
class _RailSection extends StatelessWidget {
  const _RailSection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: TeamakColors.subtle,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// One jump in the rail: the lit entry wears the brand tint, the rest
/// stay quiet ink — the reference's active pill, in Teamak's palette.
class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.entry,
    required this.selected,
    required this.onSelect,
  });

  final (String, IconData, String) entry;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final on = selected == entry.$1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: on
            ? TeamakColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => onSelect(entry.$1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  entry.$2,
                  size: 20,
                  color: on ? TeamakColors.primary : TeamakColors.subtle,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.$3,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                      color: on ? TeamakColors.primaryDark : TeamakColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The way out — dropping this device's pointer, after a confirmation
/// that says the application itself stays put.
class _SignOutTile extends StatelessWidget {
  const _SignOutTile({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    // Its own transparent Material: the rail's white background would
    // otherwise swallow the tile's ink splash.
    return Material(
      color: Colors.transparent,
      child: ListTile(
        leading: const Icon(
          Icons.logout_rounded,
          size: 20,
          color: TeamakColors.subtle,
        ),
        title: const Text(
          'Sign out',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: onSignOut,
      ),
    );
  }
}

/// The member's first initial in a circle — gold-ringed where the
/// reference rings its avatar, plain beside the name in the rail.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, this.size = 40, this.ring = false});

  final String initial;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: TeamakColors.primary,
        border: Border.all(
          color: ring ? TeamakColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: initial.isEmpty
          ? Icon(Icons.person_rounded, color: Colors.white, size: size * 0.5)
          : Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.4,
              ),
            ),
    );
  }
}

class _RailLogo extends StatelessWidget {
  const _RailLogo();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: TeamakColors.primary.withValues(alpha: 0.06),
        padding: const EdgeInsets.all(3),
        child: Image.asset(
          'assets/teamak_logo.png',
          height: 30,
          width: 30,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

/// The reference's top bar: page title left, round controls right — ours
/// carries only the real ones: refresh, and the member's avatar.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.loading,
    required this.onRefresh,
    required this.initial,
  });

  final bool loading;
  final VoidCallback onRefresh;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TeamakColors.border)),
      ),
      child: Row(
        children: <Widget>[
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: TeamakColors.ink,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: loading ? null : onRefresh,
            tooltip: 'Refresh',
            icon: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
            style: IconButton.styleFrom(
              fixedSize: const Size(40, 40),
              backgroundColor: Colors.white,
              foregroundColor: TeamakColors.ink,
              side: const BorderSide(color: TeamakColors.border),
              shape: const CircleBorder(),
            ),
          ),
          const SizedBox(width: 12),
          _Avatar(initial: initial, size: 40, ring: true),
        ],
      ),
    );
  }
}

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
    final answered = _items
        .where((item) => application.containsKey(item.$1))
        .toList();

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

/// The reference layout's opening — a greeting, a two-tone headline and
/// one line of orientation, unboxed so the page reads as a member
/// overview rather than a receipt.
class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({required this.detail, required this.fresh});

  final ApplicationDetail detail;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    final name = '${detail.application['fullName'] ?? ''}'.trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    // The returning applicant is greeted by name; a fresh submission is
    // welcomed into the same journey.
    final lead = firstName.isEmpty
        ? (fresh ? 'Welcome' : 'Welcome back')
        : fresh
        ? 'Welcome, '
        : 'Welcome back, ';

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Greeting: a gray lead-in with the member's name in brand
          // blue — the reference's coloured name, in Teamak's palette.
          // Wrap, not Row: a long name drops to its own line at 320px
          // instead of pushing past the edge.
          Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                lead,
                style: const TextStyle(
                  color: TeamakColors.subtle,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (firstName.isNotEmpty)
                Text(
                  firstName,
                  style: const TextStyle(
                    color: TeamakColors.primary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // The headline: the programme leads in ink, the coloured word
          // is the view itself — the same two-tone construction as the
          // reference's "Your … Overview".
          Text.rich(
            TextSpan(
              children: <TextSpan>[
                const TextSpan(
                  text: 'Your Teamak ',
                  style: TextStyle(
                    color: TeamakColors.ink,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const TextSpan(
                  text: 'Overview',
                  style: TextStyle(
                    color: TeamakColors.primary,
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            fresh
                ? 'Keep this number safe. Our team will contact you for '
                      'verification before any approval.'
                : 'Track your application from submission to rider '
                      'ownership.',
            style: const TextStyle(
              color: TeamakColors.subtle,
              fontSize: 14,
              height: 1.5,
            ),
          ),
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
    final lastTo = events.isEmpty ? null : '${events.last['toStatus'] ?? ''}';
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
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

    final countdown = due == null ? null : dueCountdown(due);

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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
/// The four numbers the reference layout leads with — status, the number
/// the applicant quotes to us, when they applied, and what comes next —
/// as white cards with a tinted icon, an uppercase label and a bold
/// value. Nothing is invented: a figure the record does not hold is
/// simply not drawn.
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
    final kpis = <_Kpi>[
      _Kpi(
        icon: switch (detail.status) {
          'approved' => Icons.verified_rounded,
          'not_approved' => Icons.cancel_rounded,
          'further_review' => Icons.search_rounded,
          _ => Icons.hourglass_top_rounded,
        },
        tint: TeamakColors.primary,
        label: 'APPLICATION STATUS',
        value: statusLabel(detail.status),
        valueColor: TeamakColors.primary,
      ),
      _Kpi(
        icon: Icons.badge_rounded,
        tint: TeamakColors.accent,
        label: 'APPLICATION NUMBER',
        value: detail.applicationNo,
        copy: detail.applicationNo,
      ),
      _Kpi(
        icon: Icons.event_rounded,
        tint: TeamakColors.primaryDark,
        label: 'SUBMITTED',
        value: _stamp(detail.createdAt).split(' ').first,
      ),
      _Kpi(
        icon: Icons.flag_rounded,
        tint: TeamakColors.accent,
        label: 'NEXT MILESTONE',
        value: _milestone,
        valueColor: TeamakColors.accentDark,
      ),
    ];

    Widget card(_Kpi kpi) {
      final box = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: TeamakColors.border),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: TeamakColors.primary.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                // The reference's circular icon chip — solid brand tint
                // with a white glyph, alternating blue and gold down the
                // row.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kpi.tint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(kpi.icon, color: Colors.white, size: 22),
                ),
                const Spacer(),
                // A copy glyph on the number card — the affordance the
                // old hero gave its own tap-to-copy chip.
                if (kpi.copy != null)
                  Icon(Icons.copy_rounded, size: 15, color: TeamakColors.dim),
              ],
            ),
            const SizedBox(height: 12),
            // Labels are allowed to wrap to two lines, the way the
            // reference's longest label does; IntrinsicHeight keeps the
            // cards in a row the same height regardless.
            Text(
              kpi.label,
              style: const TextStyle(
                color: TeamakColors.subtle,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                kpi.value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: kpi.valueColor ?? TeamakColors.ink,
                ),
              ),
            ),
          ],
        ),
      );

      // The number is both the applicant's credential and what they
      // quote to us on WhatsApp — one tap copies it, feedback first so a
      // platform without a clipboard still gets its message.
      if (kpi.copy == null) return box;
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('${kpi.copy} copied')));
            Clipboard.setData(ClipboardData(text: kpi.copy!)).ignore();
          },
          child: box,
        ),
      );
    }

    Widget pair(_Kpi first, _Kpi second) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: card(first)),
          const SizedBox(width: 12),
          Expanded(child: card(second)),
        ],
      ),
    );

    // Two cards per row on a phone; one row of four on anything wider.
    if (wide) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < kpis.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: card(kpis[i])),
            ],
          ],
        ),
      );
    }
    return Column(
      children: <Widget>[
        pair(kpis[0], kpis[1]),
        const SizedBox(height: 12),
        pair(kpis[2], kpis[3]),
      ],
    );
  }
}

/// One KPI card: a tinted icon, an uppercase label, a bold value, and an
/// optional value to copy when the card is tapped.
class _Kpi {
  const _Kpi({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    this.valueColor,
    this.copy,
  });

  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final Color? valueColor;
  final String? copy;
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
/// The approved rider's forward view: what the team has recorded for the
/// handover and one tap to say they are ready. Every figure here is a
/// staff answer — when nothing is recorded yet, the card waits with the
/// rider instead of inventing a date or an amount.
class _HandoverCard extends StatelessWidget {
  const _HandoverCard({required this.official, required this.onReady});

  final Map<String, dynamic> official;
  final VoidCallback onReady;

  bool _present(String key) =>
      official[key] != null && '${official[key]}'.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hasDelivery = _present('expectedDeliveryDate');
    final delivery = hasDelivery
        ? displayDate('${official['expectedDeliveryDate']}')
        : null;
    final due = hasDelivery
        ? DateTime.tryParse('${official['expectedDeliveryDate']}')
        : null;
    final countdown = due == null ? null : dueCountdown(due);
    final amount = _present('approvedAmount')
        ? '₦${_group('${official['approvedAmount']}')}'
        : null;

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
                    'Your handover',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                // Same gold pill the commitment card wears, counting to
                // the delivery instead of the deposit.
                if (countdown != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: TeamakColors.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      countdown,
                      style: const TextStyle(
                        color: TeamakColors.accentDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (delivery != null)
              _Row(label: 'Expected delivery', value: delivery)
            else
              const Text(
                'Our team will confirm your delivery date — keep your phone '
                'reachable.',
                style: TextStyle(color: TeamakColors.subtle, height: 1.5),
              ),
            if (amount != null) ...<Widget>[
              const SizedBox(height: 6),
              _Row(label: 'Approved amount', value: amount),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                ),
                onPressed: onReady,
                icon: const Icon(Icons.chat_rounded),
                label: const Text("Tell them I'm ready"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _hasOutcome(Map<String, dynamic> official) => const <String>[
  'verificationDate',
  'approvedProgrammeId',
  'approvedAmount',
  'expectedDeliveryDate',
].any((key) => official[key] != null && '${official[key]}'.isNotEmpty);

class _OutcomeCard extends StatelessWidget {
  const _OutcomeCard({required this.official, required this.status});

  final Map<String, dynamic> official;

  /// Once approved, the forward-looking figures move to the handover
  /// card — this record card keeps only what has already happened.
  final String status;

  bool _present(String key) =>
      official[key] != null && '${official[key]}'.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isApproved = status == 'approved';
    final rows = <(String, String)>[
      if (_present('verificationDate'))
        ('Verification date', displayDate('${official['verificationDate']}')),
      if (_present('approvedProgrammeId'))
        (
          'Approved programme',
          programmeLabel('${official['approvedProgrammeId']}'),
        ),
      if (!isApproved && _present('approvedAmount'))
        ('Approved amount', '₦${_group('${official['approvedAmount']}')}'),
      if (!isApproved && _present('expectedDeliveryDate'))
        (
          'Expected delivery',
          displayDate('${official['expectedDeliveryDate']}'),
        ),
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
            for (final (label, value) in rows) _Row(label: label, value: value),
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

    // The reference's status banner: a tinted icon chip beside a bold
    // line and its explanation — what is happening right now, sitting
    // directly under the numbers.
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: TeamakColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                switch (status) {
                  'approved' => Icons.verified_rounded,
                  'not_approved' => Icons.cancel_rounded,
                  'further_review' => Icons.search_rounded,
                  _ => Icons.hourglass_top_rounded,
                },
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
                    copy.title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: TeamakColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.body,
                    style: const TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
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
              OutlinedButton(onPressed: onSetPin, child: const Text('Turn on'))
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
  }) => TextField(
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
  return text.length >= 16
      ? text.substring(0, 16)
      : (text.isEmpty ? '—' : text);
}

/// 14:05 → `14:05` — the clock time the record on screen was checked.
String _clock(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

/// 650000 → 650,000, without pulling in number formatting for one field.
String _group(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Whole days to a due date, in the words the chips read: nothing once
/// the date has passed — the row still shows the date itself, plainly.
/// The commitment card counts to the deposit; the handover card counts
/// to the delivery.
String? dueCountdown(DateTime due, {DateTime? now}) {
  final ref = now ?? DateTime.now();
  final days = DateTime(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime(ref.year, ref.month, ref.day)).inDays;
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
  final head =
      'Hello Teamak, I am following up on my application '
      '$applicationNo (${statusLabel(status)}).';
  return switch (status) {
    'approved' =>
      '$head I am ready for the deposit and handover — '
          'please tell me the next step.',
    'not_approved' =>
      '$head Please, can you tell me why, and when '
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
