import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../models/complaint.dart';
import '../state/auth_provider.dart';
import '../state/complaints_provider.dart';
import '../widgets/accept_reopen_sheets.dart';
import '../widgets/dashboard_stat_card.dart';
import 'complaint_details_screen.dart';
import 'home_shell.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<ComplaintsProvider>();
    final name = auth.user?.displayName ?? 'Student';
    final pending = provider.pendingAcceptance;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Hero(name: name),
              const SizedBox(height: 20),
              if (pending.isNotEmpty) ...[
                _PendingCentre(pending: pending),
                const SizedBox(height: 20),
              ],
              _StatsGrid(provider: provider),
              const SizedBox(height: 24),
              Text('Quick Actions',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _QuickAction(
                title: 'Report an Issue',
                subtitle: 'Submit a new infrastructure complaint',
                icon: Icons.report_problem_outlined,
                color: AppColors.statusReopened,
                onTap: () => HomeScope.of(context).goToTab(1),
              ),
              const SizedBox(height: 10),
              _QuickAction(
                title: 'Track Complaints',
                subtitle: 'Monitor your complaint progress',
                icon: Icons.list_alt_rounded,
                color: AppColors.statusAssigned,
                onTap: () => HomeScope.of(context).goToTab(2),
              ),
              const SizedBox(height: 10),
              _QuickAction(
                title: 'Complaint History',
                subtitle: 'View all your past complaints',
                icon: Icons.history_rounded,
                color: AppColors.statusCompleted,
                onTap: () => HomeScope.of(context).goToTab(2),
              ),
              if (provider.error != null && !provider.loading) ...[
                const SizedBox(height: 16),
                _ErrorNote(message: provider.error!, onRetry: provider.refresh),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String name;
  const _Hero({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: AppColors.gradientHero,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFFFDE047), size: 18),
              const SizedBox(width: 6),
              Text('Smart Campus Platform',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Welcome back, $name! 👋',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text("Here's your campus infrastructure overview",
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 13.5)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: () => HomeScope.of(context).goToTab(1),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.report_problem_outlined,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text('Report New Issue',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingCentre extends StatelessWidget {
  final List<Complaint> pending;
  const _PendingCentre({required this.pending});

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.statusPending;
    return Container(
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: amber.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: amber.withValues(alpha: 0.12),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Action Required — ${pending.length} fix${pending.length > 1 ? 'es' : ''} pending your review',
                    style: TextStyle(
                        color: amber, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          for (final c in pending) _PendingRow(complaint: c),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final Complaint complaint;
  const _PendingRow({required this.complaint});

  Future<void> _accept(BuildContext context) async {
    final ok = await showAcceptSheet(context, complaint);
    if (ok && context.mounted) {
      context.read<ComplaintsProvider>().applyStatus(complaint.id, 'Completed');
    }
  }

  Future<void> _reopen(BuildContext context) async {
    final ok = await showReopenSheet(context, complaint);
    if (ok && context.mounted) {
      context.read<ComplaintsProvider>().applyStatus(complaint.id, 'Reopened');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(complaint.ticketNumber,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusPending)),
              const SizedBox(width: 8),
              Text('· ${complaint.category}',
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.7))),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '${complaint.location.short} — Fix ready, please review and confirm',
            style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniButton(
                  label: 'Accept Fix',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.statusCompleted,
                  onTap: () => _accept(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniButton(
                  label: 'Reopen',
                  icon: Icons.replay_rounded,
                  color: AppColors.statusPending,
                  onTap: () => _reopen(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MiniButton(
      {required this.label,
      required this.icon,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ComplaintsProvider provider;
  const _StatsGrid({required this.provider});

  @override
  Widget build(BuildContext context) {
    final s = provider.stats;
    String? totalTrend;
    if (s.totalComplaints > 0) {
      totalTrend = s.monthChange > 0
          ? '+${s.monthChange}% this month'
          : s.monthChange < 0
              ? '${s.monthChange}% this month'
              : 'No change this month';
    }
    // Two rows of two cards. IntrinsicHeight makes both cards in a row match the
    // taller one, and each card sizes to its own content — so a card with a trend
    // line can never overflow a fixed grid cell (regardless of text scale).
    final cards = [
      DashboardStatCard(
        title: 'Total',
        value: '${s.totalComplaints}',
        icon: Icons.assignment_outlined,
        accent: AppColors.primary,
        trend: totalTrend,
      ),
      DashboardStatCard(
        title: 'Pending',
        value: '${s.pendingIssues}',
        icon: Icons.schedule_rounded,
        accent: AppColors.statusSubmitted,
      ),
      DashboardStatCard(
        title: 'In Progress',
        value: '${s.inProgress}',
        icon: Icons.trending_up_rounded,
        accent: AppColors.statusProgress,
      ),
      DashboardStatCard(
        title: 'Resolved',
        value: '${s.resolvedIssues}',
        icon: Icons.check_circle_outline_rounded,
        accent: AppColors.statusCompleted,
        trend: s.totalComplaints > 0
            ? '${s.resolutionRate}% resolution rate'
            : null,
      ),
    ];
    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: a),
              const SizedBox(width: 12),
              Expanded(child: b),
            ],
          ),
        );
    return Column(
      children: [
        row(cards[0], cards[1]),
        const SizedBox(height: 12),
        row(cards[2], cards[3]),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border:
                Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6))),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorNote extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorNote({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.destructive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.destructive.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.destructive, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.destructive)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Exposed so other screens can reuse the same details navigation.
void openComplaintDetails(BuildContext context, String id) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ComplaintDetailsScreen(complaintId: id)),
  );
}
