/// Data models mirroring the Teamak API payloads.
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

  factory Programme.fromJson(Map<String, dynamic> json) => Programme(
        id: '${json['id']}',
        label: '${json['label']}',
        depositNgn: (json['depositNgn'] as num?)?.toInt() ?? 0,
        months: (json['months'] as num?)?.toInt() ?? 0,
        asset: '${json['asset']}',
        summary: '${json['summary']}',
      );

  String get depositLabel => '₦${groupDigits(depositNgn)}';

  /// Formats [amount] with thousands separators, e.g. `650,000`.
  static String groupDigits(int amount) {
    final digits = amount.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class StaffSession {
  const StaffSession({required this.token, required this.username, required this.fullName, required this.role});

  final String token;
  final String username;
  final String fullName;
  final String role;

  factory StaffSession.fromJson(Map<String, dynamic> json) {
    final staff = json['staff'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return StaffSession(
      token: '${json['token']}',
      username: '${staff['username']}',
      fullName: '${staff['fullName']}',
      role: '${staff['role']}',
    );
  }
}

class ApplicationSummary {
  const ApplicationSummary({
    required this.id,
    required this.applicationNo,
    required this.status,
    required this.fullName,
    required this.phoneNumber,
    required this.programmeId,
    required this.areaCommunity,
    required this.createdAt,
    required this.verificationStatus,
  });

  final String id;
  final String applicationNo;
  final String status;
  final String fullName;
  final String phoneNumber;
  final String programmeId;
  final String areaCommunity;
  final String createdAt;
  final String? verificationStatus;

  factory ApplicationSummary.fromJson(Map<String, dynamic> json) {
    final official = json['official'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ApplicationSummary(
      id: '${json['id']}',
      applicationNo: '${json['applicationNo']}',
      status: '${json['status']}',
      fullName: '${json['fullName']}',
      phoneNumber: '${json['phoneNumber']}',
      programmeId: '${json['programmeId']}',
      areaCommunity: '${json['areaCommunity']}',
      createdAt: '${json['createdAt']}',
      verificationStatus: official['verificationStatus']?.toString(),
    );
  }
}

class ApplicationDetail {
  const ApplicationDetail({
    required this.id,
    required this.applicationNo,
    required this.status,
    required this.programmeId,
    required this.createdAt,
    required this.application,
    required this.official,
    required this.events,
    required this.documents,
  });

  final String id;
  final String applicationNo;
  final String status;
  final String programmeId;
  final String createdAt;
  final Map<String, dynamic> application;
  final Map<String, dynamic> official;
  final List<dynamic> events;
  final List<dynamic> documents;

  factory ApplicationDetail.fromJson(Map<String, dynamic> json) =>
      ApplicationDetail(
        id: '${json['id']}',
        applicationNo: '${json['applicationNo']}',
        status: '${json['status']}',
        programmeId: '${json['programmeId']}',
        createdAt: '${json['createdAt']}',
        application:
            Map<String, dynamic>.from(json['application'] as Map? ?? const {}),
        official: Map<String, dynamic>.from(json['official'] as Map? ?? const {}),
        events: (json['events'] as List?) ?? const [],
        documents: (json['documents'] as List?) ?? const [],
      );
}

class ApplicationListResult {
  const ApplicationListResult({
    required this.total,
    required this.results,
    required this.counts,
  });

  final int total;
  final List<ApplicationSummary> results;
  final Map<String, dynamic> counts;

  factory ApplicationListResult.fromJson(Map<String, dynamic> json) =>
      ApplicationListResult(
        total: (json['total'] as num?)?.toInt() ?? 0,
        results: ((json['results'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => ApplicationSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        counts: Map<String, dynamic>.from(json['counts'] as Map? ?? const {}),
      );
}

/// A message sent through the public contact form.
class ContactMessage {
  const ContactMessage({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.subject,
    required this.message,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String phone;
  final String email;
  final String subject;
  final String message;
  final String createdAt;

  factory ContactMessage.fromJson(Map<String, dynamic> json) => ContactMessage(
        id: (json['id'] as num?)?.toInt() ?? 0,
        name: '${json['name'] ?? ''}',
        phone: '${json['phone'] ?? ''}',
        email: '${json['email'] ?? ''}',
        subject: '${json['subject'] ?? ''}',
        message: '${json['message'] ?? ''}',
        createdAt: '${json['createdAt'] ?? ''}',
      );
}
