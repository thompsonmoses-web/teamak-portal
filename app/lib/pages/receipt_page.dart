import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/shell.dart';

/// Successful submission payload handed to the receipt screen.
typedef ReceiptDetail = ApplicationDetail;

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.detail});

  final ApplicationDetail detail;

  String _programmeLabel(BuildContext context) {
    final programmeId = detail.programmeId;
    return switch (programmeId) {
      'okada_650' => 'Okada ownership — ₦650,000 / 3 months',
      'okada_400' => 'Okada ownership — ₦400,000 / 6 months',
      'maruwa_2300' => 'Maruwa ownership — ₦2,300,000 / 3 months',
      _ => programmeId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final application = detail.application;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;

    return AppShell(
      title: 'Application receipt',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: EdgeInsets.all(wide ? 32 : 16),
            children: <Widget>[
              Card(
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
                        child: const Icon(
                          Icons.check_rounded,
                          color: TeamakColors.primary,
                          size: 56,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Application received',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your application number is',
                        style: TextStyle(color: TeamakColors.subtle),
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
                      const SizedBox(height: 12),
                      const Text(
                        'Keep this number safe. Our team will contact you for '
                        'verification before any approval.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: TeamakColors.subtle),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Row(label: 'Applicant', value: '${application['fullName']}'),
                      _Row(label: 'Phone', value: '${application['phoneNumber']}'),
                      _Row(label: 'Area / Community', value: '${application['areaCommunity']}'),
                      _Row(label: 'NIN', value: '${application['nin']}'),
                      _Row(label: 'Programme', value: _programmeLabel(context)),
                      _Row(label: 'Park / Association', value: '${application['parkAssociationName']}'),
                      _Row(
                        label: 'Submitted',
                        value: detail.createdAt.replaceAll('T', ' ').substring(
                              0,
                              detail.createdAt.length >= 19 ? 16 : detail.createdAt.length,
                            ),
                      ),
                      _Row(label: 'Status', value: statusLabel(detail.status)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () => printReceipt(context),
                    icon: const Icon(Icons.print),
                    label: const Text('Print receipt'),
                  ),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> printReceipt(BuildContext context) async {
    // Printing is platform specific; fall back to a friendly message on web.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Use your browser\'s print dialog (Ctrl+P) to save this receipt.',
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
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

String statusLabel(String status) => switch (status) {
      'submitted' => 'Submitted',
      'pending' => 'Under review',
      'approved' => 'Approved',
      'not_approved' => 'Not approved',
      'further_review' => 'Further review',
      _ => status,
    };
