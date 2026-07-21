import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/ui_helpers.dart';
import '../services/api_client.dart';
import '../state/auth_provider.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onLoggedIn() {
    // Auth status just flipped to authenticated → the root gate now renders the
    // home shell; drop the pushed login/welcome routes to reveal it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back to home'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Header card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.gradientHero,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.school_outlined,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Student Login',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use your official campus account',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tab selector
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.6)),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabs,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.gradientPrimary),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  labelStyle: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w700),
                  tabs: const [
                    Tab(text: 'OTP Login'),
                    Tab(text: 'Password'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Tab content — sized to content via IndexedStack + AnimatedSize
              _TabHost(
                controller: _tabs,
                children: [
                  _OtpTab(onLoggedIn: _onLoggedIn),
                  _PasswordTab(onLoggedIn: _onLoggedIn),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders the active tab child at its natural height (TabBarView needs a bounded
/// height, which fights a scroll view; this shows one child at a time instead).
class _TabHost extends StatefulWidget {
  final TabController controller;
  final List<Widget> children;
  const _TabHost({required this.controller, required this.children});

  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() {
    if (widget.controller.indexIsChanging) return;
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      alignment: Alignment.topCenter,
      child: widget.children[widget.controller.index],
    );
  }
}

// ── OTP tab ──────────────────────────────────────────────────────────────────
class _OtpTab extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const _OtpTab({required this.onLoggedIn});

  @override
  State<_OtpTab> createState() => _OtpTabState();
}

class _OtpTabState extends State<_OtpTab> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();

  bool _otpSent = false;
  bool _sending = false;
  bool _verifying = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _email.text.trim().toLowerCase();
    if (!isAllowedStudentEmail(email)) {
      showSnack(context, 'Please use your @uem.edu.in or @iem.edu.in email address',
          error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      final res = await context.read<AuthProvider>().sendOtp(email);
      _otp.clear();
      setState(() => _otpSent = true);
      _startCooldown(res.resendAfter);
      if (mounted) {
        showSnack(context, 'OTP sent to your email');
        _otpFocus.requestFocus();
      }
    } catch (e) {
      if (e is ApiException && e.retryAfter != null) {
        _startCooldown(e.retryAfter!);
      }
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final email = _email.text.trim().toLowerCase();
    final otp = _otp.text.trim();
    if (otp.length != 6) {
      showSnack(context, 'Please enter the 6-digit OTP sent to your email',
          error: true);
      return;
    }
    setState(() => _verifying = true);
    try {
      await context.read<AuthProvider>().verifyOtp(email, otp);
      if (mounted) widget.onLoggedIn();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _changeEmail() {
    setState(() {
      _otpSent = false;
      _otp.clear();
      _cooldown = 0;
    });
    _timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('otp'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _email,
          enabled: !_otpSent,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            hintText: 'yourname@uem.edu.in',
          ),
        ),
        if (_otpSent) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('🔒 Email locked',
                  style: TextStyle(
                      fontSize: 11,
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              GestureDetector(
                onTap: _changeEmail,
                child: Text('Change email',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _OtpBoxes(controller: _otp, focusNode: _otpFocus),
          const SizedBox(height: 20),
          GradientButton(
            label: _verifying ? 'Verifying...' : 'Verify OTP & Login',
            icon: Icons.login_rounded,
            loading: _verifying,
            onPressed: _verify,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed:
                (_sending || _verifying || _cooldown > 0) ? null : _sendOtp,
            child: Text(
              _cooldown > 0
                  ? 'Resend OTP in ${_cooldown}s'
                  : (_sending ? 'Resending...' : 'Resend OTP'),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          GradientButton(
            label: _sending ? 'Sending OTP...' : 'Send OTP',
            icon: Icons.mail_outline_rounded,
            loading: _sending,
            onPressed: _sendOtp,
          ),
          const SizedBox(height: 14),
          Text(
            'No password required — we email a one-time code to your official '
            'campus address.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ],
    );
  }
}

/// Six digit boxes backed by a hidden text field (tap anywhere to focus).
class _OtpBoxes extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _OtpBoxes({required this.controller, required this.focusNode});

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.controller.text;
    return GestureDetector(
      onTap: () => widget.focusNode.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final filled = i < value.length;
              final current = i == value.length;
              return Container(
                width: 46,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: filled
                      ? LinearGradient(colors: AppColors.gradientPrimary)
                      : null,
                  color: filled ? null : theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: current
                        ? theme.colorScheme.primary
                        : theme.dividerColor,
                    width: current ? 2 : 1.2,
                  ),
                ),
                child: Text(
                  filled ? value[i] : '',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: filled ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.number,
                autofocus: true,
                maxLength: 6,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password tab (login + register) ──────────────────────────────────────────
class _PasswordTab extends StatefulWidget {
  final VoidCallback onLoggedIn;
  const _PasswordTab({required this.onLoggedIn});

  @override
  State<_PasswordTab> createState() => _PasswordTabState();
}

class _PasswordTabState extends State<_PasswordTab> {
  bool _register = false;
  bool _loading = false;
  bool _obscure = true;

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim().toLowerCase();
    final password = _password.text;
    if (!isAllowedStudentEmail(email)) {
      showSnack(context, 'Please use your @uem.edu.in or @iem.edu.in email address',
          error: true);
      return;
    }
    if (_register && _name.text.trim().isEmpty) {
      showSnack(context, 'Please enter your name', error: true);
      return;
    }
    if (password.length < 6) {
      showSnack(context, 'Password must be at least 6 characters', error: true);
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    try {
      if (_register) {
        await auth.register(_name.text.trim(), email, password);
        // Auto sign-in after a successful registration.
        await auth.passwordLogin(email, password);
      } else {
        await auth.passwordLogin(email, password);
      }
      if (mounted) widget.onLoggedIn();
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey('password'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_register) ...[
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              hintText: 'Full name',
            ),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
            hintText: 'yourname@uem.edu.in',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _password,
          obscureText: _obscure,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
            hintText: 'Password (min 6 characters)',
            suffixIcon: IconButton(
              icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 18),
        GradientButton(
          label: _register ? 'Create Account' : 'Sign In',
          icon: _register ? Icons.person_add_alt_1_rounded : Icons.login_rounded,
          loading: _loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: () => setState(() => _register = !_register),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                children: [
                  TextSpan(
                      text: _register
                          ? 'Already have an account? '
                          : "Don't have an account? "),
                  TextSpan(
                    text: _register ? 'Sign in' : 'Register',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
