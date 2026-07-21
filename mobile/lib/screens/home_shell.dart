import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/complaints_provider.dart';
import 'dashboard_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'track_screen.dart';

/// Lets descendants switch the active bottom-nav tab (e.g. dashboard → report).
class HomeScope extends InheritedWidget {
  final void Function(int index) goToTab;
  const HomeScope({super.key, required this.goToTab, required super.child});

  static HomeScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HomeScope>();
    assert(scope != null, 'HomeScope not found in the widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(HomeScope oldWidget) => false;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Load the student's data as soon as the shell mounts.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ComplaintsProvider>().refresh();
    });
  }

  void _goToTab(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HomeScope(
      goToTab: _goToTab,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: const [
            DashboardScreen(),
            ReportScreen(),
            TrackScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _goToTab,
          backgroundColor: theme.colorScheme.surface,
          indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.14),
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Report',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined),
              selectedIcon: Icon(Icons.list_alt_rounded),
              label: 'Track',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
