/**
 * Single source of truth for complaint categories and statuses.
 *
 * Previously these lists were copy-pasted across ReportComplaint, ComplaintCard,
 * ComplaintDetails, AdminDashboard and TrackComplaints — adding a category or
 * status meant editing 4–5 files and silently breaking whichever was missed.
 * Everything category/status-shaped now imports from here.
 */

export const CATEGORIES = [
  'Electricity',
  'Water',
  'Internet',
  'Furniture',
  'Cleanliness',
  'Infrastructure',
] as const;

export type Category = (typeof CATEGORIES)[number];

export const DEFAULT_CATEGORY: Category = 'Infrastructure';

/**
 * Per-category presentation. `softGradient` is the translucent variant used on
 * cards; `solidGradient` is the full-strength variant used on the detail hero.
 * (softGradient is simply solidGradient at /20 and /10 opacity.)
 */
export const CATEGORY_META: Record<string, { emoji: string; softGradient: string; solidGradient: string }> = {
  Electricity:    { emoji: '⚡',   softGradient: 'from-amber-500/20 to-yellow-500/10', solidGradient: 'from-amber-500 to-yellow-500' },
  Water:          { emoji: '💧',   softGradient: 'from-blue-500/20 to-cyan-500/10',    solidGradient: 'from-blue-500 to-cyan-500' },
  Internet:       { emoji: '📡',   softGradient: 'from-violet-500/20 to-purple-500/10', solidGradient: 'from-violet-500 to-purple-500' },
  Furniture:      { emoji: '🪑',   softGradient: 'from-orange-500/20 to-amber-500/10',  solidGradient: 'from-orange-500 to-amber-500' },
  Cleanliness:    { emoji: '🧹',   softGradient: 'from-emerald-500/20 to-green-500/10', solidGradient: 'from-emerald-500 to-green-500' },
  Infrastructure: { emoji: '🏗️', softGradient: 'from-slate-500/20 to-gray-500/10',   solidGradient: 'from-slate-500 to-gray-500' },
};

/** Emoji for a category, falling back to the default category's emoji. */
export const categoryEmoji = (category: string): string =>
  (CATEGORY_META[category] ?? CATEGORY_META[DEFAULT_CATEGORY]).emoji;

// ── Statuses ──────────────────────────────────────────────────────────────────
export const STATUSES = [
  'Submitted',
  'Assigned',
  'In Progress',
  'Pending Acceptance',
  'Reopened',
  'Rejected',
  'Completed',
] as const;

export type Status = (typeof STATUSES)[number];

/** Status options for filter UIs, prefixed with the "All" pseudo-filter. */
export const STATUS_FILTERS = ['All', ...STATUSES] as const;
