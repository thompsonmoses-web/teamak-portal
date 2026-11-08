import 'package:flutter/material.dart';

import '../../theme.dart';

/// Programme id → the short line used in tables and tiles, mirroring the
/// `programmeLabel` the applicant's dashboard prints on receipts.
String programmeSummary(String programmeId) => switch (programmeId) {
  'okada_650' => 'Okada · ₦650,000',
  'okada_400' => 'Okada · ₦400,000',
  'maruwa_2300' => 'Maruwa · ₦2,300,000',
  _ => programmeId,
};

/// The machine a track hands over, so a tile can show an icon that matches.
bool isMaruwa(String programmeId) => programmeId.startsWith('maruwa');

/// Status value → the words both the staff console and the applicant's
/// dashboard use for it.
String statusText(String status) => switch (status) {
  'submitted' => 'Submitted',
  'pending' => 'Under review',
  'approved' => 'Approved',
  'not_approved' => 'Not approved',
  'further_review' => 'Further review',
  _ => status,
};

/// Brand colour for each status, matching the staff review console.
Color statusColour(String status) => switch (status) {
  'approved' => TeamakColors.primary,
  'not_approved' => TeamakColors.danger,
  'further_review' => TeamakColors.accentDark,
  'pending' => Colors.blueGrey,
  _ => TeamakColors.subtle,
};

/// A pill showing an application's stage — the same shape the public
/// dashboard and staff table use, so a status reads identically everywhere.
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colour = statusColour(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        statusText(status),
        style: TextStyle(
          color: colour,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A panel's title: a tinted icon chip, the words, and an optional
/// trailing — the console's shared version of the member dashboard's
/// section cards, so both halves of the product read as one design.
class AdminCardTitle extends StatelessWidget {
  const AdminCardTitle(
    this.title, {
    super.key,
    required this.icon,
    required this.tint,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color tint;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: tint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// One headline number with its label and an icon, used across the console.
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.colour,
    this.caption,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color colour;

  /// An optional small line under the value, e.g. "3 need a decision".
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return Card(
      // The card wears its own colour at a whisper, the chip solid —
      // the row reads as brand tints instead of four white boxes.
      color: colour.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colour.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: colour,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: const TextStyle(
                      color: TeamakColors.subtle,
                      fontSize: 12.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (caption != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      caption!,
                      style: TextStyle(
                        color: colour,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1250000 → ₦1,250,000, without pulling in number formatting for one field.
String naira(int amount) {
  final digits = amount.toString();
  final buffer = StringBuffer('₦');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// '2026-10-02T09:14:00Z' → '2 Oct 2026', tolerating short or empty values.
String shortDate(String iso) {
  if (iso.length < 10) return iso.isEmpty ? '—' : iso;
  final year = iso.substring(0, 4);
  final month = iso.substring(5, 7);
  final day = iso.substring(8, 10);
  const names = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final index = int.tryParse(month);
  final name = (index == null || index < 1 || index > 12)
      ? month
      : names[index - 1];
  return '$day $name $year';
}
