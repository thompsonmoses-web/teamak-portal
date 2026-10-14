/// Programme tiers offered by the Teamak Rider Ownership Programme.
library;

class Programme {
  const Programme({
    required this.id,
    required this.label,
    required this.depositNgn,
    required this.months,
    required this.asset,
    required this.summary,
  });

  final String id;
  final String label;
  final int depositNgn;
  final int months;
  final String asset;
  final String summary;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'depositNgn': depositNgn,
        'months': months,
        'asset': asset,
        'summary': summary,
      };

  static const List<Programme> all = <Programme>[
    Programme(
      id: 'okada_650',
      label: 'OKADA OWNERSHIP',
      depositNgn: 650000,
      months: 3,
      asset: '1 brand-new Bajaj motorcycle',
      summary: '₦650,000 one-time deposit → 3 months → 1 brand-new Bajaj motorcycle.',
    ),
    Programme(
      id: 'okada_400',
      label: 'OKADA OWNERSHIP',
      depositNgn: 400000,
      months: 6,
      asset: '1 brand-new Bajaj motorcycle',
      summary: '₦400,000 one-time deposit → 6 months → 1 brand-new Bajaj motorcycle.',
    ),
    Programme(
      id: 'maruwa_2300',
      label: 'MARUWA OWNERSHIP',
      depositNgn: 2300000,
      months: 3,
      asset: '1 Bajaj/approved Maruwa tricycle',
      summary: '₦2,300,000 one-time deposit → 3 months → 1 Bajaj/approved Maruwa tricycle.',
    ),
  ];

  static Programme? byId(String? id) {
    if (id == null) return null;
    for (final programme in all) {
      if (programme.id == id) return programme;
    }
    return null;
  }

  static const Set<String> ids = <String>{'okada_650', 'okada_400', 'maruwa_2300'};
}

/// Application status values and allowed transitions.
class ApplicationStatus {
  static const String submitted = 'submitted';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String notApproved = 'not_approved';
  static const String furtherReview = 'further_review';

  static const Set<String> all = <String>{
    submitted,
    pending,
    approved,
    notApproved,
    furtherReview,
  };

  /// Statuses a staff member may set from the review screen.
  static const Set<String> staffSettable = <String>{
    pending,
    approved,
    notApproved,
    furtherReview,
  };
}
