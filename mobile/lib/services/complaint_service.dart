import 'package:dio/dio.dart';

import '../models/complaint.dart';
import '../models/dashboard_stats.dart';
import 'api_client.dart';

/// Student-scoped complaint operations. The backend derives ownership from the
/// bearer token, so none of these need to pass a student email.
class ComplaintService {
  final _dio = ApiClient.instance.dio;

  Future<DashboardStats> getDashboard() async {
    try {
      final res = await _dio.get('/dashboard');
      return DashboardStats.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<List<Complaint>> getComplaints() async {
    try {
      final res = await _dio.get('/complaints');
      final list = (res.data as List?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => Complaint.fromJson(e.cast<String, dynamic>()))
          .toList();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<Complaint> getComplaint(String id) async {
    try {
      final res = await _dio.get('/complaints/$id');
      return Complaint.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  /// Create a complaint. [photoPath] is an optional local image file path.
  Future<String> createComplaint({
    required String category,
    required String building,
    required String floor,
    required String room,
    required String description,
    String? photoPath,
  }) async {
    try {
      final map = <String, dynamic>{
        'category': category,
        'building': building,
        'floor': floor,
        'room': room,
        'description': description,
      };
      if (photoPath != null && photoPath.isNotEmpty) {
        // The backend accepts only png/jpg/jpeg/gif/webp (validated by filename
        // extension). Fall back to jpg for anything else (e.g. iOS HEIC).
        const allowed = {'png', 'jpg', 'jpeg', 'gif', 'webp'};
        var ext = photoPath.contains('.')
            ? photoPath.split('.').last.toLowerCase()
            : 'jpg';
        if (!allowed.contains(ext)) ext = 'jpg';
        map['photo'] = await MultipartFile.fromFile(
          photoPath,
          filename: 'complaint.$ext',
        );
      }
      final res = await _dio.post(
        '/complaints',
        data: FormData.fromMap(map),
      );
      final data = (res.data as Map).cast<String, dynamic>();
      return (data['_id'] ?? '').toString();
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> acceptFix(String complaintId, String feedback) async {
    try {
      await _dio.post('/complaints/$complaintId/accept',
          data: {'feedback': feedback});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }

  Future<void> reopen(String complaintId, String reason) async {
    try {
      await _dio.post('/complaints/$complaintId/reopen',
          data: {'reason': reason});
    } catch (e) {
      throw ApiClient.toApiException(e);
    }
  }
}
