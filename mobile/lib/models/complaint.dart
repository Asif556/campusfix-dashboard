// Client-side model of a serialized complaint (see backend
// `utils/helpers.serialize_complaint`).

class ComplaintLocation {
  final String building;
  final String floor;
  final String room;

  const ComplaintLocation({
    required this.building,
    required this.floor,
    required this.room,
  });

  factory ComplaintLocation.fromJson(Map<String, dynamic>? json) {
    json ??= const {};
    return ComplaintLocation(
      building: (json['building'] ?? '').toString(),
      floor: (json['floor'] ?? '').toString(),
      room: (json['room'] ?? '').toString(),
    );
  }

  String get short {
    final parts = [building, room].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  String get full {
    final parts = [building, floor, room].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }
}

class StatusHistoryEntry {
  final String status;
  final String timestamp; // ISO-8601 string (may be empty)
  final String adminName;
  final String authorityName;
  final String studentName;
  final String reason;

  const StatusHistoryEntry({
    required this.status,
    required this.timestamp,
    required this.adminName,
    required this.authorityName,
    required this.studentName,
    required this.reason,
  });

  factory StatusHistoryEntry.fromJson(Map<String, dynamic> json) =>
      StatusHistoryEntry(
        status: (json['status'] ?? '').toString(),
        timestamp: (json['timestamp'] ?? '').toString(),
        adminName: (json['admin_name'] ?? '').toString(),
        authorityName: (json['authority_name'] ?? '').toString(),
        studentName: (json['student_name'] ?? '').toString(),
        reason: (json['reason'] ?? '').toString(),
      );
}

class AssignedTo {
  final String authorityId;
  final String name;
  final String category;
  final String assignedAt;
  final String assignedBy;

  const AssignedTo({
    required this.authorityId,
    required this.name,
    required this.category,
    required this.assignedAt,
    required this.assignedBy,
  });

  factory AssignedTo.fromJson(Map<String, dynamic> json) => AssignedTo(
        authorityId: (json['authority_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        category: (json['category'] ?? '').toString(),
        assignedAt: (json['assigned_at'] ?? '').toString(),
        assignedBy: (json['assigned_by'] ?? '').toString(),
      );
}

class Complaint {
  final String id;
  final String ticketNumber;
  final String studentEmail;
  final String category;
  final ComplaintLocation location;
  final String description;
  final String status;
  final List<StatusHistoryEntry> statusHistory;
  final String date; // "YYYY-MM-DD"
  final String timestamp; // ISO-8601
  final String? photo; // relative path like /uploads/<name>
  final AssignedTo? assignedTo;
  final String studentFeedback;
  final String reopenReason;

  const Complaint({
    required this.id,
    required this.ticketNumber,
    required this.studentEmail,
    required this.category,
    required this.location,
    required this.description,
    required this.status,
    required this.statusHistory,
    required this.date,
    required this.timestamp,
    required this.photo,
    required this.assignedTo,
    required this.studentFeedback,
    required this.reopenReason,
  });

  bool get isPendingAcceptance => status == 'Pending Acceptance';

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final historyRaw = (json['status_history'] as List?) ?? const [];
    final assignedRaw = json['assignedTo'];
    return Complaint(
      id: (json['_id'] ?? '').toString(),
      ticketNumber: (json['ticket_number'] ?? '').toString(),
      studentEmail: (json['student_email'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      location: ComplaintLocation.fromJson(
          (json['location'] as Map?)?.cast<String, dynamic>()),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'Submitted').toString(),
      statusHistory: historyRaw
          .whereType<Map>()
          .map((e) => StatusHistoryEntry.fromJson(e.cast<String, dynamic>()))
          .toList(),
      date: (json['date'] ?? '').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
      photo: (json['photo'] == null || (json['photo'] as Object?).toString().isEmpty)
          ? null
          : json['photo'].toString(),
      assignedTo: assignedRaw is Map
          ? AssignedTo.fromJson(assignedRaw.cast<String, dynamic>())
          : null,
      studentFeedback: (json['student_feedback'] ?? '').toString(),
      reopenReason: (json['reopen_reason'] ?? '').toString(),
    );
  }

  Complaint copyWith({String? status}) => Complaint(
        id: id,
        ticketNumber: ticketNumber,
        studentEmail: studentEmail,
        category: category,
        location: location,
        description: description,
        status: status ?? this.status,
        statusHistory: statusHistory,
        date: date,
        timestamp: timestamp,
        photo: photo,
        assignedTo: assignedTo,
        studentFeedback: studentFeedback,
        reopenReason: reopenReason,
      );
}
