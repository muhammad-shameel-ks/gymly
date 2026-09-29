/// Inquiry domain model (per GLOSSARY.md).
///
/// An inquiry is a walk-in / call asking about the gym, not yet a member.
/// Name + phone required, optional note. Statuses: new/contacted/joined/lost.
/// Converting an inquiry creates a member (+ usually a first subscription)
/// and marks the inquiry `joined`.
library;

/// Inquiry status values matching the `inquiries.status` column.
enum InquiryStatus {
  /// Freshly added, not yet contacted.
  fresh('new'),

  /// Owner has reached out.
  contacted('contacted'),

  /// Converted to a member ([memberId] links to `members.id`).
  joined('joined'),

  /// Will not convert.
  lost('lost');

  const InquiryStatus(this.value);

  /// Raw DB value.
  final String value;

  /// Parse a DB value; unknown values fall back to [fresh].
  static InquiryStatus fromValue(String value) {
    for (final s in InquiryStatus.values) {
      if (s.value == value) return s;
    }
    return InquiryStatus.fresh;
  }

  /// Next status in the advance flow: new -> contacted -> joined.
  /// `lost` is terminal via the advance flow (set explicitly instead).
  InquiryStatus? get next {
    switch (this) {
      case InquiryStatus.fresh:
        return InquiryStatus.contacted;
      case InquiryStatus.contacted:
        return InquiryStatus.joined;
      case InquiryStatus.joined:
      case InquiryStatus.lost:
        return null;
    }
  }

  /// Label for the advance action button, if any.
  String? get advanceLabel {
    switch (this) {
      case InquiryStatus.fresh:
        return 'Mark contacted';
      case InquiryStatus.contacted:
        return 'Convert to member';
      case InquiryStatus.joined:
      case InquiryStatus.lost:
        return null;
    }
  }
}

/// One row of the `inquiries` table.
class Inquiry {
  const Inquiry({
    required this.id,
    required this.gymId,
    required this.name,
    required this.phone,
    this.note,
    required this.status,
    this.memberId,
    required this.createdAt,
  });

  final String id;
  final String gymId;
  final String name;
  final String phone;
  final String? note;
  final InquiryStatus status;

  /// Set when [status] is [InquiryStatus.joined]: the created member.
  final String? memberId;
  final DateTime createdAt;

  factory Inquiry.fromJson(Map<String, dynamic> json) {
    return Inquiry(
      id: json['id'] as String,
      gymId: json['gym_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      note: json['note'] as String?,
      status: InquiryStatus.fromValue(json['status'] as String? ?? 'new'),
      memberId: json['member_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsert(String gymId) {
    return <String, dynamic>{
      'gym_id': gymId,
      'name': name,
      'phone': phone,
      if (note != null && note!.isNotEmpty) 'note': note,
      'status': status.value,
    };
  }

  Inquiry copyWith({
    String? name,
    String? phone,
    String? note,
    InquiryStatus? status,
    String? memberId,
  }) {
    return Inquiry(
      id: id,
      gymId: gymId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      note: note ?? this.note,
      status: status ?? this.status,
      memberId: memberId ?? this.memberId,
      createdAt: createdAt,
    );
  }
}
