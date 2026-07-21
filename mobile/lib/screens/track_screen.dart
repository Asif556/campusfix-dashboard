import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/complaint.dart';
import '../state/complaints_provider.dart';
import '../widgets/accept_reopen_sheets.dart';
import '../widgets/complaint_card.dart';
import 'dashboard_screen.dart' show openComplaintDetails;

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  String _filter = 'All';
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Complaint> _apply(List<Complaint> all) {
    final q = _search.toLowerCase();
    return all.where((c) {
      final matchStatus = _filter == 'All' || c.status == _filter;
      final matchSearch = q.isEmpty ||
          c.category.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ComplaintsProvider>();
    final theme = Theme.of(context);
    final filtered = _apply(provider.complaints);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Complaints'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () => provider.refresh(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    hintText: 'Search by category or description...',
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                  ),
                ),
              ),
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: kStatusFilters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = kStatusFilters[i];
                    final selected = _filter == s;
                    return GestureDetector(
                      onTap: () => setState(() => _filter = s),
                      child: Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          gradient: selected
                              ? LinearGradient(colors: AppColors.gradientPrimary)
                              : null,
                          color: selected ? null : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? Colors.transparent
                                : theme.dividerColor.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildBody(provider, filtered),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ComplaintsProvider provider, List<Complaint> filtered) {
    if (provider.loading && !provider.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return _EmptyState(
        loaded: provider.loaded,
        hasError: provider.error != null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final c = filtered[i];
        return Column(
          children: [
            ComplaintCard(
              complaint: c,
              onTap: () => openComplaintDetails(context, c.id),
            ),
            if (c.isPendingAcceptance) _PendingActions(complaint: c),
          ],
        );
      },
    );
  }
}

class _PendingActions extends StatelessWidget {
  final Complaint complaint;
  const _PendingActions({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Expanded(
            child: _ActionChip(
              label: 'Accept Fix',
              icon: Icons.check_circle_outline_rounded,
              color: AppColors.statusCompleted,
              onTap: () async {
                final ok = await showAcceptSheet(context, complaint);
                if (ok && context.mounted) {
                  context
                      .read<ComplaintsProvider>()
                      .applyStatus(complaint.id, 'Completed');
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ActionChip(
              label: 'Reopen',
              icon: Icons.replay_rounded,
              color: AppColors.statusPending,
              onTap: () async {
                final ok = await showReopenSheet(context, complaint);
                if (ok && context.mounted) {
                  context
                      .read<ComplaintsProvider>()
                      .applyStatus(complaint.id, 'Reopened');
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionChip(
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
          padding: const EdgeInsets.symmetric(vertical: 10),
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

class _EmptyState extends StatelessWidget {
  final bool loaded;
  final bool hasError;
  const _EmptyState({required this.loaded, required this.hasError});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ensure the RefreshIndicator can be triggered even when empty.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasError ? Icons.wifi_off_rounded : Icons.inbox_outlined,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  hasError ? "Couldn't load complaints" : 'No complaints found',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    hasError
                        ? 'Pull down to retry once the server is reachable.'
                        : 'Try adjusting your filters, or report a new issue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.55)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
