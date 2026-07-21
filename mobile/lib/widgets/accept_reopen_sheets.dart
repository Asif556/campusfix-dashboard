import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/ui_helpers.dart';
import '../models/complaint.dart';
import '../services/complaint_service.dart';
import 'gradient_button.dart';

/// Shows the "Accept Fix" sheet. Resolves to `true` when the fix was accepted.
Future<bool> showAcceptSheet(BuildContext context, Complaint complaint) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActionSheet(complaint: complaint, reopen: false),
  );
  return result ?? false;
}

/// Shows the "Reopen" sheet. Resolves to `true` when the complaint was reopened.
Future<bool> showReopenSheet(BuildContext context, Complaint complaint) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ActionSheet(complaint: complaint, reopen: true),
  );
  return result ?? false;
}

class _ActionSheet extends StatefulWidget {
  final Complaint complaint;
  final bool reopen;
  const _ActionSheet({required this.complaint, required this.reopen});

  @override
  State<_ActionSheet> createState() => _ActionSheetState();
}

class _ActionSheetState extends State<_ActionSheet> {
  final _controller = TextEditingController();
  final _service = ComplaintService();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (widget.reopen && text.isEmpty) {
      showSnack(context, 'Please provide a reason for reopening.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      if (widget.reopen) {
        await _service.reopen(widget.complaint.id, text);
      } else {
        await _service.acceptFix(widget.complaint.id, text);
      }
      if (!mounted) return;
      showSnack(
        context,
        widget.reopen
            ? 'Complaint reopened. Admin has been notified.'
            : 'Fix accepted! Complaint closed.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showSnack(context, e.toString(), error: true);
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reopen = widget.reopen;
    final c = widget.complaint;
    final accent = reopen ? AppColors.statusPending : AppColors.statusCompleted;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              reopen ? 'Reopen Complaint' : 'Accept Fix',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              '${c.ticketNumber} · ${c.category}',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    reopen
                        ? Icons.replay_rounded
                        : Icons.check_circle_outline_rounded,
                    color: accent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reopen
                          ? 'The issue will be marked as Reopened and the admin will be notified to re-assign it.'
                          : "You're confirming that the ${c.category} issue at ${c.location.short} has been resolved.",
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              reopen ? 'Reason for reopening *' : 'Feedback on the fix (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: reopen
                    ? 'What is still unresolved? Describe the issue clearly...'
                    : 'How was the resolution? Was it handled properly?',
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(
              label: reopen ? 'Reopen Issue' : 'Accept & Close',
              icon: reopen
                  ? Icons.replay_rounded
                  : Icons.check_circle_outline_rounded,
              loading: _loading,
              gradient: reopen
                  ? [AppColors.statusPending, AppColors.statusProgress]
                  : null,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
