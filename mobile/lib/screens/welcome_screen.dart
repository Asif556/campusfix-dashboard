import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.gradientHero,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton(
                    tooltip: 'Server settings',
                    icon: const Icon(Icons.settings_outlined,
                        color: Colors.white70),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🎓', style: TextStyle(fontSize: 38)),
                    ),
                    const SizedBox(height: 28),
                    const Text(
                      'UEM CampusFix',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Report campus infrastructure issues, track their progress in '
                      'real time, and confirm the fix — all from your phone.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ..._features(),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LoginScreen()),
                          ),
                          child: Container(
                            height: 54,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.school_outlined,
                                    color: AppColors.primary, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Student Login',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Sign in with your @uem.edu.in or @iem.edu.in account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _features() {
    const items = [
      ('📝', 'Report issues with photos'),
      ('📍', 'Real-time status tracking'),
      ('✅', 'Accept or reopen fixes'),
    ];
    return items
        .map(
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Text(i.$1, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(
                  i.$2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}
