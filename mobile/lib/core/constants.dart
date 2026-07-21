import 'package:flutter/material.dart';

/// Single source of truth for complaint categories and statuses — mirrors the
/// web app's `src/lib/constants.ts` so both clients speak the same vocabulary.

class CategoryMeta {
  final String label;
  final String emoji;
  final List<Color> gradient; // full-strength gradient used on hero/details

  const CategoryMeta(this.label, this.emoji, this.gradient);
}

/// Ordered category list shown in the report form (matches CATEGORIES on web).
const List<CategoryMeta> kCategories = [
  CategoryMeta('Electricity', '⚡', [Color(0xFFF59E0B), Color(0xFFEAB308)]),
  CategoryMeta('Water', '💧', [Color(0xFF3B82F6), Color(0xFF06B6D4)]),
  CategoryMeta('Internet', '📡', [Color(0xFF8B5CF6), Color(0xFFA855F7)]),
  CategoryMeta('Furniture', '🪑', [Color(0xFFF97316), Color(0xFFF59E0B)]),
  CategoryMeta('Cleanliness', '🧹', [Color(0xFF10B981), Color(0xFF22C55E)]),
  CategoryMeta('Infrastructure', '🏗️', [Color(0xFF64748B), Color(0xFF6B7280)]),
];

const String kDefaultCategory = 'Infrastructure';

CategoryMeta categoryMeta(String category) {
  return kCategories.firstWhere(
    (c) => c.label == category,
    orElse: () =>
        kCategories.firstWhere((c) => c.label == kDefaultCategory),
  );
}

String categoryEmoji(String category) => categoryMeta(category).emoji;

/// All complaint statuses, in lifecycle order.
const List<String> kStatuses = [
  'Submitted',
  'Assigned',
  'In Progress',
  'Pending Acceptance',
  'Reopened',
  'Rejected',
  'Completed',
];

/// Status options for filter UIs, prefixed with the "All" pseudo-filter.
const List<String> kStatusFilters = ['All', ...kStatuses];

/// Official student email domains accepted by the backend.
const List<String> kAllowedStudentDomains = ['@uem.edu.in', '@iem.edu.in'];

bool isAllowedStudentEmail(String email) {
  final e = email.trim().toLowerCase();
  return kAllowedStudentDomains.any(e.endsWith);
}
