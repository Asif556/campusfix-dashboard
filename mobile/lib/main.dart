import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'screens/home_shell.dart';
import 'screens/welcome_screen.dart';
import 'services/session_store.dart';
import 'state/auth_provider.dart';
import 'state/complaints_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SessionStore.instance.init();
  runApp(const CampusFixApp());
}

class CampusFixApp extends StatelessWidget {
  const CampusFixApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..bootstrap()),
        ChangeNotifierProvider(create: (_) => ComplaintsProvider()),
      ],
      child: MaterialApp(
        title: 'CampusFix',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Routes between the loading splash, the welcome/login flow, and the signed-in
/// shell purely off the [AuthProvider] status.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );

    final Widget child = switch (status) {
      AuthStatus.unknown => const _Splash(),
      AuthStatus.unauthenticated => const WelcomeScreen(),
      AuthStatus.authenticated => const HomeShell(),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(status), child: child),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

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
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🎓', style: TextStyle(fontSize: 56)),
              SizedBox(height: 16),
              Text(
                'CampusFix',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
