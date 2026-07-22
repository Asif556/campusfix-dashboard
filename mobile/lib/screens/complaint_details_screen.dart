import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/env.dart';
import '../core/formatting.dart';
import '../core/theme.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import '../services/session_store.dart';
import '../state/auth_provider.dart';
import '../state/complaints_provider.dart';
import '../widgets/accept_reopen_sheets.dart';
import '../widgets/status_badge.dart';

class _Step {
  final String label;
  final String desc;
  final IconData icon;
  const _Step(this.label, this.desc, this.icon);
}

const _happyPath = [
  _Step('Submitted', 'Complaint registered', Icons.schedule_rounded),
  _Step('Assigned', 'Department assigned', Icons.person_pin_circle_outlined),
  _Step('In Progress', 'Being worked on', Icons.autorenew_rounded),
  _Step('Pending Acceptance', 'Fix ready — awaiting you',
      Icons.warning_amber_rounded),
  _Step('Completed', 'Issue resolved & accepted', Icons.check_circle_outline_rounded),
];

class ComplaintDetailsScreen extends StatefulWidget {
  final String complaintId;
  const ComplaintDetailsScreen({super.key, required this.complaintId});

  @override
  State<ComplaintDetailsScreen> createState() => _ComplaintDetailsScreenState();
}

class _ComplaintDetailsScreenState extends State<ComplaintDetailsScreen> {
  final _service = ComplaintService();
  Complaint? _complaint;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final c = await _service.getComplaint(widget.complaintId);
      if (mounted) setState(() => _complaint = c);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _accept() async {
    final ok = await showAcceptSheet(context, _complaint!);
    if (ok && mounted) {
      setState(() => _complaint = _complaint!.copyWith(status: 'Completed'));
      context.read<ComplaintsProvider>().applyStatus(_complaint!.id, 'Completed');
    }
  }

  Future<void> _reopen() async {
    final ok = await showReopenSheet(context, _complaint!);
    if (ok && mounted) {
      setState(() => _complaint = _complaint!.copyWith(status: 'Reopened'));
      context.read<ComplaintsProvider>().applyStatus(_complaint!.id, 'Reopened');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint Details')),
      body: _error
          ? _ErrorView(onRetry: _load)
          : _complaint == null
              ? const Center(child: CircularProgressIndicator())
              : _buildContent(_complaint!),
    );
  }

  Widget _buildContent(Complaint c) {
    final theme = Theme.of(context);
    final meta = categoryMeta(c.category);
    final photoUrl =
        Env.resolvePhotoUrl(SessionStore.instance.baseUrl, c.photo);
    final myEmail = context.read<AuthProvider>().user?.email;
    final isOwner = myEmail != null && c.studentEmail == myEmail;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero
        if (photoUrl != null)
          GestureDetector(
            onTap: () => _openLightbox(photoUrl, c.category),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(color: AppColors.muted),
                    errorWidget: (_, _, _) => _emojiHero(meta),
                  ),
                  const Positioned(
                    top: 12,
                    right: 12,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      radius: 18,
                      child: Icon(Icons.fullscreen_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _emojiHero(meta, height: 150),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(c.ticketNumber,
                            style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary)),
                      ],
                    ),
                  ),
                  StatusBadge(status: c.status),
                ],
              ),
              const SizedBox(height: 16),
              Text('${c.category} Issue',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              _metaRow(Icons.location_on_outlined, c.location.full),
              if (fmtTimestamp(c.timestamp) != null)
                _metaRow(Icons.calendar_today_outlined,
                    fmtTimestamp(c.timestamp)!),
              _metaRow(
                  Icons.mail_outline_rounded,
                  c.studentEmail.isEmpty
                      ? 'Raised by (not recorded)'
                      : 'Raised by ${c.studentEmail}'),
              const SizedBox(height: 18),
              if (c.isPendingAcceptance && isOwner) ...[
                _ActionBanner(
                  onAccept: _accept,
                  onReopen: _reopen,
                  deadline: c.autoAcceptDeadline,
                ),
                const SizedBox(height: 18),
              ],
              _InfoBlock(
                icon: Icons.info_outline_rounded,
                title: 'Description',
                body: c.description,
              ),
              if (c.studentFeedback.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InfoBlock(
                  icon: Icons.star_outline_rounded,
                  title: 'Your Feedback',
                  body: '"${c.studentFeedback}"',
                  accent: AppColors.statusCompleted,
                  italic: true,
                ),
              ],
              if (c.reopenReason.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InfoBlock(
                  icon: Icons.replay_rounded,
                  title: 'Reopen Reason',
                  body: '"${c.reopenReason}"',
                  accent: AppColors.statusReopened,
                  italic: true,
                ),
              ],
              const SizedBox(height: 24),
              const Text('Status Timeline',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              _Timeline(complaint: c),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metaRow(IconData icon, String text) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: muted)),
          ),
        ],
      ),
    );
  }

  Widget _emojiHero(CategoryMeta meta, {double height = 200}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: meta.gradient,
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(meta.emoji, style: const TextStyle(fontSize: 64)),
    );
  }

  void _openLightbox(String url, String label) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _Lightbox(url: url, label: label),
      ),
    );
  }
}

class _ActionBanner extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onReopen;
  final DateTime? deadline;
  const _ActionBanner({
    required this.onAccept,
    required this.onReopen,
    this.deadline,
  });

  @override
  Widget build(BuildContext context) {
    final amber = AppColors.statusPending;
    final remaining = fmtRemaining(deadline);
    final by = fmtTimestamp(deadline?.toIso8601String());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Action Required',
                        style: TextStyle(
                            color: amber,
                            fontWeight: FontWeight.w800,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'The issue has been marked resolved. Verify and either accept the fix or reopen if the problem persists.',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: amber.withValues(alpha: 0.9)),
                    ),
                    if (remaining != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        by != null
                            ? "⏳ If you don't respond, the fix is auto-accepted $remaining (by $by)."
                            : "⏳ If you don't respond, the fix is auto-accepted $remaining.",
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: amber),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BannerButton(
                  label: 'Accept Fix',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.statusCompleted,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BannerButton(
                  label: 'Reopen Issue',
                  icon: Icons.replay_rounded,
                  color: amber,
                  onTap: onReopen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _BannerButton(
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
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color? accent;
  final bool italic;
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.accent,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = accent ?? theme.colorScheme.primary;
    final bg = accent != null
        ? accent!.withValues(alpha: 0.06)
        : theme.colorScheme.onSurface.withValues(alpha: 0.03);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: (accent ?? theme.dividerColor).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 6),
              Text(title,
                  style:
                      const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.5,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline ─────────────────────────────────────────────────────────────────
class _Timeline extends StatelessWidget {
  final Complaint complaint;
  const _Timeline({required this.complaint});

  List<_Step> get _displaySteps {
    switch (complaint.status) {
      case 'Reopened':
        return [
          ..._happyPath.take(4),
          const _Step('Reopened', 'You reopened the complaint',
              Icons.replay_rounded),
        ];
      case 'Rejected':
        return [
          ..._happyPath.take(2),
          const _Step('Rejected', 'Awaiting re-assignment by admin',
              Icons.cancel_outlined),
        ];
      default:
        return _happyPath;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = _displaySteps;
    final statusIndex = steps.indexWhere((s) => s.label == complaint.status);

    // First timestamp + actor metadata per status, from the history.
    final timestamps = <String, String>{};
    final metaByStatus = <String, StatusHistoryEntry>{};
    for (final h in complaint.statusHistory) {
      if (h.status.isNotEmpty && h.timestamp.isNotEmpty &&
          !timestamps.containsKey(h.status)) {
        timestamps[h.status] = h.timestamp;
      }
      metaByStatus.putIfAbsent(h.status, () => h);
    }
    if (!timestamps.containsKey('Submitted') && complaint.timestamp.isNotEmpty) {
      timestamps['Submitted'] = complaint.timestamp;
    }

    return Column(
      children: [
        for (int i = 0; i < steps.length; i++)
          _buildStep(
            theme,
            steps[i],
            active: i <= statusIndex,
            current: i == statusIndex,
            isLast: i == steps.length - 1,
            timestamp: timestamps[steps[i].label],
            actor: i <= statusIndex
                ? _actorLine(steps[i].label, metaByStatus)
                : null,
          ),
      ],
    );
  }

  String? _actorLine(String label, Map<String, StatusHistoryEntry> meta) {
    switch (label) {
      case 'Submitted':
        return complaint.studentEmail.isNotEmpty
            ? 'Registered by ${complaint.studentEmail}'
            : null;
      case 'Assigned':
        final authority =
            meta['Assigned']?.authorityName ?? complaint.assignedTo?.name ?? '';
        final by = meta['Assigned']?.adminName ??
            complaint.assignedTo?.assignedBy ??
            '';
        final auto = by == 'Auto-assign';
        if (authority.isNotEmpty && auto) return 'Auto-assigned to $authority';
        if (authority.isNotEmpty && by.isNotEmpty) {
          return 'Assigned to $authority by Admin — $by';
        }
        if (authority.isNotEmpty) return 'Assigned to $authority';
        return null;
      case 'In Progress':
        final name = meta['In Progress']?.authorityName ??
            complaint.assignedTo?.name ??
            '';
        return name.isNotEmpty
            ? 'Accepted — being handled by $name'
            : 'Accepted by the authority';
      case 'Pending Acceptance':
        final by = meta['Pending Acceptance']?.authorityName ?? '';
        return by.isNotEmpty
            ? 'Marked resolved by $by'
            : 'Awaiting your confirmation';
      case 'Completed':
        if (meta['Completed']?.autoAccepted == true) {
          return 'Auto-accepted — no response in time';
        }
        final by = meta['Completed']?.studentName ?? '';
        return by.isNotEmpty ? 'Fix accepted by $by' : null;
      case 'Reopened':
        final by = meta['Reopened']?.studentName ?? '';
        return by.isNotEmpty ? 'Reopened by $by' : null;
      case 'Rejected':
        return 'Awaiting re-assignment by admin';
      default:
        return null;
    }
  }

  Widget _buildStep(
    ThemeData theme,
    _Step step, {
    required bool active,
    required bool current,
    required bool isLast,
    String? timestamp,
    String? actor,
  }) {
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: active
                      ? LinearGradient(colors: AppColors.gradientPrimary)
                      : null,
                  color: active
                      ? null
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(13),
                  border: current
                      ? Border.all(
                          color: theme.colorScheme.secondary
                              .withValues(alpha: 0.4),
                          width: 3)
                      : null,
                ),
                child: Icon(step.icon,
                    size: 17,
                    color: active ? Colors.white : muted),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: active
                        ? theme.colorScheme.primary.withValues(alpha: 0.4)
                        : theme.dividerColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? theme.colorScheme.onSurface
                              : muted)),
                  const SizedBox(height: 2),
                  Text(step.desc, style: TextStyle(fontSize: 12, color: muted)),
                  if (actor != null) ...[
                    const SizedBox(height: 3),
                    Text(actor,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7))),
                  ],
                  if (timestamp != null && fmtTimestamp(timestamp) != null) ...[
                    const SizedBox(height: 3),
                    Text(fmtTimestamp(timestamp)!,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.75))),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lightbox ─────────────────────────────────────────────────────────────────
class _Lightbox extends StatelessWidget {
  final String url;
  final String label;
  const _Lightbox({required this.url, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (_, _) => const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.white)),
                  errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: AppColors.destructive, size: 40),
          const SizedBox(height: 12),
          const Text("Couldn't load this complaint",
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('It may have been removed, or the server is unreachable.',
              style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 12),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
