import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/auth_provider.dart';
import '../state/complaints_provider.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final stats = context.watch<ComplaintsProvider>().stats;
    final name = user?.displayName ?? 'Student';
    final email = user?.email ?? '';
    final initials = _initials(name);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.gradientHero,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(email,
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('🎓 Student',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Total',
                    value: '${stats.totalComplaints}',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Resolved',
                    value: '${stats.resolvedIssues}',
                    color: AppColors.statusCompleted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    label: 'Pending',
                    value: '${stats.pendingIssues}',
                    color: AppColors.statusSubmitted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _MenuTile(
              icon: Icons.dns_outlined,
              title: 'Server Settings',
              subtitle: 'Configure the backend address',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            _MenuTile(
              icon: Icons.info_outline_rounded,
              title: 'About CampusFix',
              subtitle: 'UEM/IEM complaint management',
              onTap: () => _showAbout(context),
            ),
            const SizedBox(height: 8),
            _MenuTile(
              icon: Icons.logout_rounded,
              title: 'Log Out',
              subtitle: 'Sign out of this device',
              destructive: true,
              onTap: () => _confirmLogout(context),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'CampusFix',
      applicationVersion: '1.0.0',
      applicationLegalese:
          '© 2026 UEM CampusFix · University of Engineering & Management',
      children: const [
        SizedBox(height: 12),
        Text(
          'Report campus infrastructure issues, track their progress, and '
          'confirm fixes — for UEM/IEM students.',
        ),
      ],
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.destructive),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<ComplaintsProvider>().reset();
      await context.read<AuthProvider>().logout();
    }
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        destructive ? AppColors.destructive : theme.colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: theme.dividerColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: destructive ? 0.1 : 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.55))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
