import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/env.dart';
import '../core/theme.dart';
import '../core/ui_helpers.dart';
import '../services/session_store.dart';
import '../widgets/gradient_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _url =
      TextEditingController(text: SessionStore.instance.baseUrl);
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final url = _url.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (c) => c != null && c < 500,
      ));
      final res = await dio.get('${Env.originFrom(url)}/');
      final ok = res.statusCode == 200;
      setState(() {
        _testOk = ok;
        _testResult = ok
            ? 'Connected — the CampusFix API is reachable.'
            : 'Server responded with ${res.statusCode}. Check the address.';
      });
    } catch (_) {
      setState(() {
        _testOk = false;
        _testResult =
            'Could not reach the server. Make sure the backend is running and '
            'the address is correct.';
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      await SessionStore.instance.setBaseUrl(null); // reset to default
    } else {
      var normalized = url;
      // Nudge users toward the full API path if they entered a bare origin.
      if (!normalized.contains('/campusfix/api')) {
        normalized =
            '${normalized.replaceAll(RegExp(r'/+$'), '')}${Env.apiSuffix}';
      }
      await SessionStore.instance.setBaseUrl(normalized);
      _url.text = normalized;
    }
    if (mounted) {
      showSnack(context, 'Server address saved.');
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _resetDefault() async {
    await SessionStore.instance.setBaseUrl(null);
    setState(() => _url.text = SessionStore.instance.baseUrl);
    if (mounted) showSnack(context, 'Reset to the default server address.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'The app talks to the CampusFix backend at this address. '
                      'Point it at your running server — use your machine\'s LAN '
                      'IP for a physical phone (e.g. http://192.168.1.5:5000).',
                      style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.75)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('API Base URL',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link_rounded, size: 20),
                hintText: 'http://10.0.2.2:5000/campusfix/api',
              ),
            ),
            const SizedBox(height: 6),
            Text('Default for this device: ${Env.defaultBaseUrl}',
                style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.wifi_tethering_rounded, size: 18),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_testOk
                          ? AppColors.statusCompleted
                          : AppColors.destructive)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testOk
                          ? Icons.check_circle_outline_rounded
                          : Icons.error_outline_rounded,
                      size: 18,
                      color: _testOk
                          ? AppColors.statusCompleted
                          : AppColors.destructive,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(_testResult!,
                          style: TextStyle(
                              fontSize: 12.5,
                              color: _testOk
                                  ? AppColors.statusCompleted
                                  : AppColors.destructive)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: 'Save',
              icon: Icons.save_outlined,
              onPressed: _save,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _resetDefault,
              child: const Text('Reset to default'),
            ),
          ],
        ),
      ),
    );
  }
}
