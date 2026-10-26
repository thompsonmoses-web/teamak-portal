import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';
import '../../theme.dart';
import 'admin_shell.dart';

/// The registered details riders see on the public site, and the account
/// signed in right now.
///
/// This is a read-only view, deliberately: the company details come from the
/// signed-off registration, and the programme terms come from the price list
/// the apply wizard quotes. Editing either would put the portal at odds with
/// the paper form, so they live in one place in the code instead.
class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final staff = session.staff;

    return AdminShell(
      session: session,
      currentPath: '/admin/settings',
      title: 'Settings',
      child: ListView(
        padding: EdgeInsets.all(wide ? 26 : 16),
        children: <Widget>[
          const AdminPageHeader(
            title: 'Settings',
            subtitle: 'The registered details riders see, and your own account.',
          ),
          const SizedBox(height: 18),
          _InfoCard(
            title: 'Company',
            icon: Icons.business_outlined,
            rows: <(String, String)>[
              ('Registered name', 'Teamak Global Solution Limited'),
              ('Registration', 'RC No. 9907312'),
              ('Office', 'Solution Gospel Complex, Aba Opa, Ojoo, Ibadan'),
              ('Phone', '+234 802 344 9126'),
              ('Programme', 'Rider Ownership — Ibadan & Environs'),
              ('Tagline', 'Ride with Dignity. Own Your Future.'),
            ],
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Programme terms',
            icon: Icons.motorcycle_outlined,
            rows: <(String, String)>[
              ('Okada ownership', '₦650,000 one-time deposit · 3 months'),
              ('Okada ownership', '₦400,000 one-time deposit · 6 months'),
              ('Maruwa ownership', '₦2,300,000 one-time deposit · 3 months'),
              ('Vehicle', '1 brand-new Bajaj motorcycle or approved Maruwa tricycle'),
              (
                'Further payment',
                'None — the deposit covers the machine under the '
                    'ownership offer, subject to approval and the final agreement.',
              ),
            ],
            note:
                'These are the figures on the signed-off application form. '
                'They are quoted automatically by the apply wizard, the '
                'applicant dashboard and every receipt.',
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Your account',
            icon: Icons.account_circle_outlined,
            rows: <(String, String)>[
              ('Name', staff?.fullName ?? '—'),
              ('Username', '@${staff?.username ?? '—'}'),
              (
                'Role',
                staff?.role == 'admin'
                    ? 'Administrator — full access, including the team'
                    : 'Reviewer — applications and messages',
              ),
            ],
            footer: OutlinedButton.icon(
              onPressed: () => context.go('/admin/staff'),
              icon: const Icon(Icons.badge_outlined),
              label: const Text('Manage the team'),
            ),
          ),
          const SizedBox(height: 16),
          const _InfoCard(
            title: 'Support',
            icon: Icons.support_agent_outlined,
            rows: <(String, String)>[
              ('Rider line', '+234 802 344 9126 (call or WhatsApp)'),
              ('Hours', 'Monday to Saturday, office hours'),
              (
                'Where riders apply',
                'Public site — the same portal riders see, without this console.',
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.rows,
    this.note,
    this.footer,
  });

  final String title;
  final IconData icon;
  final List<(String, String)> rows;
  final String? note;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: TeamakColors.primary),
                const SizedBox(width: 10),
                // Flexible so a long title wraps instead of pushing the card
                // past a narrow screen's edge.
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: _SettingRow(label: label, value: value),
              ),
            if (note != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: TeamakColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: TeamakColors.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  note!,
                  style: const TextStyle(
                    color: TeamakColors.accentDark,
                    height: 1.5,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (footer != null) ...<Widget>[const SizedBox(height: 12), footer!],
          ],
        ),
      ),
    );
  }
}

/// Label + value, stacked on a phone so a long address wraps rather than
/// being squeezed into a fixed column.
class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 640;
    final labelWidget = Text(
      label,
      style: const TextStyle(color: TeamakColors.subtle),
    );
    final valueWidget = Text(
      value,
      style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4),
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          labelWidget,
          const SizedBox(height: 2),
          valueWidget,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(width: 150, child: labelWidget),
        Expanded(child: valueWidget),
      ],
    );
  }
}
