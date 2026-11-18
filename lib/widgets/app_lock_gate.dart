import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../providers/app_settings.dart';
import '../utils/auth_error_message.dart';
import 'app_card.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  DateTime? _backgroundAt;
  bool _locked = true;
  bool _authenticating = false;
  bool _authUnavailable = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final settings = context.read<AppSettings>();
      final elapsed = _backgroundAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;
      if (settings.appLockEnabled &&
          elapsed >= const Duration(minutes: 1) &&
          !_locked) {
        setState(() {
          _locked = true;
          _error = null;
        });
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;
    if (!context.read<AppSettings>().appLockEnabled) {
      setState(() => _locked = false);
      return;
    }
    setState(() {
      _authenticating = true;
      _error = null;
    });
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Verifikasi untuk membuka Flowly',
        biometricOnly: false,
      );
      if (mounted && authenticated) {
        setState(() {
          _locked = false;
          _authUnavailable = false;
        });
      }
    } on LocalAuthException catch (error) {
      if (!mounted) return;
      final unavailable =
          error.code == LocalAuthExceptionCode.noCredentialsSet ||
          error.code == LocalAuthExceptionCode.noBiometricsEnrolled ||
          error.code == LocalAuthExceptionCode.noBiometricHardware;
      setState(() {
        _authUnavailable = unavailable;
        _error = authErrorMessage(error);
      });
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  Future<void> _disableUnavailableLock() async {
    await context.read<AppSettings>().setAppLockEnabled(false);
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    if (!settings.appLockEnabled) {
      if (_locked) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _locked = false);
        });
      }
      return widget.child;
    }
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 38,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Flowly terkunci',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Verifikasi untuk melanjutkan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _authUnavailable
                                      ? Icons.info_outline_rounded
                                      : Icons.help_outline_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _authenticating ? null : _unlock,
                            icon: _authenticating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.fingerprint_rounded),
                            label: Text(
                              _authenticating
                                  ? 'Menunggu verifikasi...'
                                  : 'Buka Flowly',
                            ),
                          ),
                        ),
                        if (_authUnavailable) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _disableUnavailableLock,
                            child: const Text('Matikan kunci aplikasi'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
