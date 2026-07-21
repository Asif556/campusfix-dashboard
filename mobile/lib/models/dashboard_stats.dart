/// Aggregate counts for the student's dashboard (see backend `routes/dashboard`).
class DashboardStats {
  final int totalComplaints;
  final int pendingIssues;
  final int inProgress;
  final int resolvedIssues;
  final int monthChange; // percentage, may be negative
  final int resolutionRate; // percentage

  const DashboardStats({
    this.totalComplaints = 0,
    this.pendingIssues = 0,
    this.inProgress = 0,
    this.resolvedIssues = 0,
    this.monthChange = 0,
    this.resolutionRate = 0,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return DashboardStats(
      totalComplaints: asInt(json['totalComplaints']),
      pendingIssues: asInt(json['pendingIssues']),
      inProgress: asInt(json['inProgress']),
      resolvedIssues: asInt(json['resolvedIssues']),
      monthChange: asInt(json['monthChange']),
      resolutionRate: asInt(json['resolutionRate']),
    );
  }
}
