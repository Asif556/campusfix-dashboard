import 'package:flutter/foundation.dart';

import '../models/complaint.dart';
import '../models/dashboard_stats.dart';
import '../services/complaint_service.dart';

/// Shared source of truth for the student's complaints + dashboard stats, so the
/// dashboard, tracking list, and report form all reflect the same data.
class ComplaintsProvider extends ChangeNotifier {
  final _service = ComplaintService();

  List<Complaint> complaints = [];
  DashboardStats stats = const DashboardStats();
  bool loading = false;
  bool loaded = false;
  String? error;

  List<Complaint> get pendingAcceptance =>
      complaints.where((c) => c.isPendingAcceptance).toList();

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await Future.wait([
        _service.getComplaints(),
        _service.getDashboard(),
      ]);
      complaints = res[0] as List<Complaint>;
      stats = res[1] as DashboardStats;
      loaded = true;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Create a complaint, then refresh so lists/stats reflect it. Returns the id.
  Future<String> create({
    required String category,
    required String building,
    required String floor,
    required String room,
    required String description,
    String? photoPath,
  }) async {
    final id = await _service.createComplaint(
      category: category,
      building: building,
      floor: floor,
      room: room,
      description: description,
      photoPath: photoPath,
    );
    await refresh();
    return id;
  }

  /// Optimistically patch a complaint's status locally (after accept/reopen),
  /// then refresh stats in the background.
  void applyStatus(String id, String status) {
    complaints = complaints
        .map((c) => c.id == id ? c.copyWith(status: status) : c)
        .toList();
    notifyListeners();
    refresh();
  }

  void reset() {
    complaints = [];
    stats = const DashboardStats();
    loaded = false;
    error = null;
    loading = false;
    notifyListeners();
  }
}
