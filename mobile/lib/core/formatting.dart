import 'package:intl/intl.dart';

/// India Standard Time is a fixed UTC+05:30 (no DST), so we can shift a UTC
/// instant by a constant offset and format it — matching the web app's
/// `Asia/Calcutta` display without pulling in a full timezone database.
const Duration _istOffset = Duration(hours: 5, minutes: 30);

/// Format an ISO-8601 timestamp for display in IST, e.g. "22 Jul 2026, 09:41 AM".
/// Returns null for empty/unparseable input.
String? fmtTimestamp(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final ist = dt.toUtc().add(_istOffset);
  return DateFormat('dd MMM yyyy, hh:mm a').format(ist);
}

/// Short date form, e.g. "22 Jul 2026".
String? fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final ist = dt.toUtc().add(_istOffset);
  return DateFormat('dd MMM yyyy').format(ist);
}
