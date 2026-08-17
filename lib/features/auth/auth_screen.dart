import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n_extension.dart';
import '../../core/theme/app_palette.dart';
import '../../l10n/app_localizations.dart';
import '../../services/analytics_service.dart';
import '../../services/auth_service.dart';
import '../../state/app_flow_controller.dart';
import '../../state/progress_controller.dart';
import '../../state/providers.dart';

enum _AuthMode { signIn, signUp }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signIn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    final auth = ref.read(authServiceProvider);
    final analytics = ref.read(analyticsProvider);

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_mode == _AuthMode.signUp) {
        await analytics.logEvent(AnalyticsEvents.signupStarted);
        await auth.signUpWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
        await analytics.logEvent(AnalyticsEvents.signupCompleted);
      } else {
        await auth.signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      await _onAuthenticated();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(l10n, error.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(analyticsProvider).logEvent(AnalyticsEvents.signupStarted);
      await ref.read(authServiceProvider).signInWithGoogle();
      // The OAuth redirect completes asynchronously; the auth state listener in
      // the router takes over from here.
      await _onAuthenticated();
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(l10n, error.failure));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueAsGuest() async {
    await ref.read(appFlowControllerProvider.notifier).completeAuthGate();
  }

  Future<void> _onAuthenticated() async {
    await ref.read(progressControllerProvider.notifier).mergeFromCloud();
    await ref.read(appFlowControllerProvider.notifier).completeAuthGate();
  }

  Future<void> _resetPassword() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = l10n.authEmailRequired);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      messenger.showSnackBar(SnackBar(content: Text(l10n.authResetSent)));
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _messageFor(l10n, error.failure));
    }
  }

  String _messageFor(L10n l10n, AuthFailure failure) {
    switch (failure) {
      case AuthFailure.invalidCredentials:
        return l10n.authErrorInvalid;
      case AuthFailure.emailAlreadyRegistered:
        return l10n.authErrorEmailTaken;
      case AuthFailure.weakPassword:
        return l10n.authErrorWeakPassword;
      case AuthFailure.notConfigured:
        return l10n.authErrorNotConfigured;
      case AuthFailure.network:
      case AuthFailure.unknown:
        return l10n.authErrorNetwork;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.primary, AppPalette.secondary],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text('⚡', style: TextStyle(fontSize: 36)),
                ),
                const SizedBox(height: 24),
                Text(l10n.authWelcomeTitle, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  l10n.authWelcomeBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l10n.authEmail,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.authEmailRequired;
                    if (!text.contains('@') || !text.contains('.')) {
                      return l10n.authEmailInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: l10n.authPassword,
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                  ),
                  validator: (value) {
                    final text = value ?? '';
                    if (text.isEmpty) return l10n.authPasswordRequired;
                    if (text.length < 6) return l10n.authPasswordTooShort;
                    return null;
                  },
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],

                const SizedBox(height: 22),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(isSignUp ? l10n.authSignUp : l10n.authSignIn),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _google,
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 30),
                  label: Text(l10n.authGoogle),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                          _mode = isSignUp ? _AuthMode.signIn : _AuthMode.signUp;
                          _error = null;
                        }),
                  child: Text(
                    isSignUp ? l10n.authSwitchToSignIn : l10n.authSwitchToSignUp,
                  ),
                ),
                if (!isSignUp)
                  TextButton(
                    onPressed: _busy ? null : _resetPassword,
                    child: Text(l10n.authForgotPassword),
                  ),

                const Divider(height: 36),
                TextButton(
                  onPressed: _busy ? null : _continueAsGuest,
                  child: Text(l10n.authGuest),
                ),
                Text(
                  l10n.authGuestNotice,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
