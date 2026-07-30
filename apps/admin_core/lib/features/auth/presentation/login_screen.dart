import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_card.dart';
import '../../audit/providers/audit_providers.dart';
import '../../users/models/admin_audit_log.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _prefsLoaded = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _restorePrefs();
    _completeRedirectIfNeeded();
  }

  Future<void> _restorePrefs() async {
    final prefs = ref.read(sessionPreferencesProvider);
    final remember = await prefs.getRememberMe();
    final email = await prefs.getRememberedEmail();
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (email != null) _email.text = email;
      _prefsLoaded = true;
    });
  }

  Future<void> _completeRedirectIfNeeded() async {
    try {
      await ref.read(authServiceProvider).completeGoogleRedirectIfAny();
    } catch (_) {
      // Ignore — no pending redirect.
    }
    if (!mounted) return;
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithEmail(
        email: _email.text,
        password: _password.text,
        rememberMe: _rememberMe,
      );
      if (!mounted) return;
      await ref.read(sessionPreferencesProvider).saveRememberedEmail(
            rememberMe: _rememberMe,
            email: _email.text,
          );
      await auth.refreshIdToken(forceRefresh: true);
      if (!mounted) return;
      final user = auth.currentUser;
      if (user != null) {
        await ref.read(auditLoggerProvider).logAuthEvent(
              action: AdminAuditActions.adminLoginSuccess,
              uid: user.uid,
              email: user.email ?? _email.text.trim(),
              status: AuditStatus.success,
            );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapAuthError(e));
      await ref.read(auditLoggerProvider).logAuthEvent(
            action: AdminAuditActions.adminLoginFailed,
            uid: 'unknown',
            email: _email.text.trim(),
            reason: e.code,
            status: AuditStatus.failed,
            severity: AuditSeverity.high,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _googleLoading = true;
      _error = null;
      _info = null;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.signInWithGoogle(rememberMe: _rememberMe);
      if (!mounted) return;
      await ref.read(sessionPreferencesProvider).saveRememberedEmail(
            rememberMe: _rememberMe,
            email: auth.currentUser?.email ?? _email.text,
          );
      await auth.refreshIdToken(forceRefresh: true);
      if (!mounted) return;
      final user = auth.currentUser;
      if (user != null) {
        await ref.read(auditLoggerProvider).logAuthEvent(
              action: AdminAuditActions.adminLoginSuccess,
              uid: user.uid,
              email: user.email ?? '',
              status: AuditStatus.success,
              metadata: const {'method': 'google'},
            );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        // User cancelled — no error toast.
      } else {
        setState(() => _error = _mapAuthError(e));
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('redirect started')) {
        setState(() => _info = 'Continuing Google sign-in…');
      } else {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter your email above to reset your password.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      setState(() => _info = 'Password reset email sent to $email');
      await ref.read(auditLoggerProvider).logAuthEvent(
            action: AdminAuditActions.adminPasswordResetRequested,
            uid: 'unknown',
            email: email,
            severity: AuditSeverity.warning,
          );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _mapAuthError(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    return switch (e.code) {
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'Invalid email or password.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Try again later.',
      'network-request-failed' => 'Network error. Check your connection.',
      'popup-blocked' => 'Pop-up blocked. Allow pop-ups and try again.',
      _ => e.message ?? 'Sign-in failed.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final appType = ref.watch(adminAppTypeProvider);
    final colors = context.adminColors;
    final busy = _loading || _googleLoading;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors.isLight
                ? const [
                    Color(0xFFF4F6FA),
                    Color(0xFFE3F2FD),
                    Color(0xFFFFF8E1),
                  ]
                : const [
                    Color(0xFF0A0E17),
                    Color(0xFF141B2D),
                    Color(0xFF0A0E17),
                  ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 280),
                opacity: _prefsLoaded ? 1 : 0.6,
                child: CfCard(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/crickflow-logo.png',
                            package: 'crickflow_admin_core',
                            height: 64,
                            errorBuilder: (_, _, _) => Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AdminColors.primaryBlue,
                                    AdminColors.gold,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'CF',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to CrickFlow ${appType.displayName}',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: colors.textSecondary,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _email,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!v.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _password,
                          enabled: !busy,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              onPressed: busy
                                  ? null
                                  : () => setState(() => _obscure = !_obscure),
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => busy ? null : _submit(),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              onChanged: busy
                                  ? null
                                  : (v) => setState(
                                        () => _rememberMe = v ?? true,
                                      ),
                            ),
                            const Text('Remember me'),
                            const Spacer(),
                            TextButton(
                              onPressed: busy ? null : _forgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ],
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          _Banner(message: _error!, isError: true),
                        ],
                        if (_info != null) ...[
                          const SizedBox(height: 8),
                          _Banner(message: _info!, isError: false),
                        ],
                        const SizedBox(height: 16),
                        CfButton(
                          label: 'Sign in',
                          expanded: true,
                          isLoading: _loading,
                          onPressed: busy ? null : _submit,
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: Divider(color: colors.border)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(color: colors.textMuted),
                              ),
                            ),
                            Expanded(child: Divider(color: colors.border)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: busy ? null : _google,
                          icon: _googleLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.g_mobiledata, size: 22),
                          label: Text(
                            _googleLoading
                                ? 'Signing in…'
                                : 'Continue with Google',
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Authorized personnel only · ${appType.hostHint}',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.textMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.adminColors;
    final color = isError ? colors.error : colors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
