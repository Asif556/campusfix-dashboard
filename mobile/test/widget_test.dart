// Unit tests for CampusFix mobile helpers.

import 'package:flutter_test/flutter_test.dart';

import 'package:campusfix_mobile/core/constants.dart';
import 'package:campusfix_mobile/core/env.dart';
import 'package:campusfix_mobile/models/complaint.dart';

void main() {
  group('student email validation', () {
    test('accepts campus domains', () {
      expect(isAllowedStudentEmail('a.b@uem.edu.in'), isTrue);
      expect(isAllowedStudentEmail('X@IEM.EDU.IN'), isTrue);
    });
    test('rejects non-campus domains', () {
      expect(isAllowedStudentEmail('a@gmail.com'), isFalse);
      expect(isAllowedStudentEmail(''), isFalse);
    });
  });

  group('photo url resolution', () {
    const base = 'http://10.0.2.2:5000/campusfix/api';
    test('resolves relative upload path against the origin', () {
      expect(
        Env.resolvePhotoUrl(base, '/uploads/abc.jpg'),
        'http://10.0.2.2:5000/campusfix/uploads/abc.jpg',
      );
    });
    test('passes through absolute urls', () {
      expect(
        Env.resolvePhotoUrl(base, 'https://cdn/x.png'),
        'https://cdn/x.png',
      );
    });
    test('returns null for empty', () {
      expect(Env.resolvePhotoUrl(base, null), isNull);
      expect(Env.resolvePhotoUrl(base, ''), isNull);
    });
  });

  group('complaint parsing', () {
    test('parses a serialized complaint payload', () {
      final c = Complaint.fromJson({
        '_id': '1',
        'ticket_number': 'CF-202607-ABCDE',
        'student_email': 's@uem.edu.in',
        'category': 'Water',
        'location': {'building': 'B1', 'floor': '2', 'room': '2.1'},
        'description': 'Leak',
        'status': 'Pending Acceptance',
        'status_history': [
          {'status': 'Submitted', 'timestamp': '2026-07-22T00:00:00+00:00'}
        ],
        'photo': '/uploads/x.jpg',
      });
      expect(c.ticketNumber, 'CF-202607-ABCDE');
      expect(c.location.full, 'B1, 2, 2.1');
      expect(c.isPendingAcceptance, isTrue);
      expect(c.statusHistory.length, 1);
    });
  });
}
