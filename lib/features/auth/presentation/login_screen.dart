import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/player_profile_constants.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/routing/deep_link_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _verificationId;
  bool _showOtp = false;
  final _otpController = TextEditingController();
  String _dialCode = '+94';

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String get _phoneNumberHint {
    return switch (_dialCode) {
      '+94' => '771234567',
      '+91' => '9876543210',
      '+92' => '3001234567',
      '+880' => '1712345678',
      '+44' => '7911123456',
      '+61' => '412345678',
      '+64' => '211234567',
      '+27' => '821234567',
      '+1' => '2025551234',
      '+971' => '501234567',
      _ => '771234567',
    };
  }

  Future<void> _goAfterAuth(UserModel profile) async {
    ref.invalidate(currentUserProfileProvider);
    if (profile.needsPlayerOnboarding) {
      if (mounted) context.go('/player-onboarding');
      return;
    }
    if (mounted) {
      await PendingAuthAction.runIfAny(ref, context);
    }
    if (!mounted) return;
    final pending = DeepLinkHandler.takePendingPath();
    final route = pending ?? homeRouteForRole(profile.role);
    context.go(route);
  }

  Future<void> _googleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final profile =
          await ref.read(authRepositoryProvider).signInWithGoogle();
      await _goAfterAuth(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOtp() async {
    final phoneRaw = _phoneController.text.trim();
    if (phoneRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your phone number')),
      );
      return;
    }
    final digits = phoneRaw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid phone number')),
      );
      return;
    }

    final phone = '$_dialCode$digits';
    setState(() => _isLoading = true);
    await ref.read(authRepositoryProvider).signInWithPhone(
      phoneNumber: phone,
      codeSent: (verificationId, _) {
        setState(() {
          _verificationId = verificationId;
          _showOtp = true;
          _isLoading = false;
        });
      },
      onError: (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyPhoneAuthError(e.message)),
          ),
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    final code = _otpController.text.trim();
    if (code.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(authRepositoryProvider).verifyPhoneOtp(
            verificationId: _verificationId!,
            smsCode: code,
          );
      await _goAfterAuth(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That code is incorrect or expired. Check your messages and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetPhoneAuth() {
    setState(() {
      _showOtp = false;
      _verificationId = null;
      _otpController.clear();
    });
  }

  String get _formattedPhone {
    final digits = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    return '$_dialCode $digits';
  }

  String _friendlyPhoneAuthError(String? message) {
    if (message == null || message.isEmpty) {
      return 'Phone verification failed. Please try again.';
    }
    final lower = message.toLowerCase();
    if (lower.contains('.web.app') ||
        lower.contains('firebaseapp') ||
        lower.contains('http')) {
      return 'Phone verification failed. Please try again.';
    }
    return message;
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final heroEmphasis = cf.isLight ? Colors.white : CfColors.gold;
    final subtitleColor =
        cf.isLight ? Colors.white.withValues(alpha: 0.85) : cf.textSecondary;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: _isLoading ? null : _handleBack,
                  icon: Icon(Icons.arrow_back, color: heroEmphasis),
                  tooltip: 'Back',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceLg,
                    0,
                    AppDimens.spaceLg,
                    AppDimens.spaceLg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.sports_cricket,
                        size: 56,
                        color: CfColors.gold.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: AppDimens.spaceMd),
                      Text(
                        AppConstants.appName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineLarge?.copyWith(
                          color: heroEmphasis,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        'Score matches, join squads, and stream live.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: subtitleColor,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceXl),
                      Material(
                        color: cf.card,
                        elevation: cf.isLight ? 2 : 0,
                        shadowColor: cf.cardShadow,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceLg),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Sign in',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Use Google or your mobile number to continue.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cf.textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceLg),
                              OutlinedButton.icon(
                                onPressed:
                                    _isLoading && !_showOtp ? null : _googleSignIn,
                                icon: _isLoading && !_showOtp
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cf.textPrimary,
                                        ),
                                      )
                                    : Icon(Icons.g_mobiledata, size: 28),
                                label: const Text('Continue with Google'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(
                                    double.infinity,
                                    AppDimens.buttonHeight,
                                  ),
                                  side: BorderSide(color: cf.border),
                                  foregroundColor: cf.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppDimens.spaceLg),
                              Row(
                                children: [
                                  Expanded(child: Divider(color: cf.border)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppDimens.spaceMd,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: cf.textMuted),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: cf.border)),
                                ],
                              ),
                              const SizedBox(height: AppDimens.spaceLg),
                              if (!_showOtp) ...[
                                Text(
                                  'Phone number',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppDimens.spaceSm),
                                Builder(
                                  builder: (context) {
                                    final countries = [
                                      ...CricketCountry.countriesByDialCode,
                                    ];
                                    if (CricketCountry.byDialCode(_dialCode) ==
                                        null) {
                                      countries.insert(
                                        0,
                                        CricketCountry(
                                          name: 'Other',
                                          code: '',
                                          flag: '🌐',
                                          dialCode: _dialCode,
                                        ),
                                      );
                                    }
                                    return DropdownButtonFormField<String>(
                                      value: _dialCode,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Country',
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 16,
                                        ),
                                      ),
                                      selectedItemBuilder: (_) => countries
                                          .map(
                                            (c) => Align(
                                              alignment: Alignment.centerLeft,
                                              child: _DialCountryLabel(
                                                country: c,
                                                compact: true,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      items: countries
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c.dialCode,
                                              child: _DialCountryLabel(
                                                country: c,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: _isLoading
                                          ? null
                                          : (v) {
                                              if (v != null) {
                                                setState(() => _dialCode = v);
                                              }
                                            },
                                    );
                                  },
                                ),
                                const SizedBox(height: AppDimens.spaceSm),
                                TextField(
                                  controller: _phoneController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Mobile number',
                                    hintText: _phoneNumberHint,
                                    helperText:
                                        'Digits only — no country code',
                                    prefixIcon:
                                        const Icon(Icons.phone_outlined),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 16,
                                    ),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onSubmitted: (_) => _sendOtp(),
                                ),
                                const SizedBox(height: AppDimens.spaceLg),
                                CfButton(
                                  label: 'Send OTP',
                                  icon: Icons.sms_outlined,
                                  isLoading: _isLoading,
                                  isGold: true,
                                  onPressed: _isLoading ? null : _sendOtp,
                                ),
                              ] else ...[
                                Text(
                                  'Enter verification code',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'We sent a 6-digit code to $_formattedPhone. '
                                  'Enter it below to sign in to ${AppConstants.appName}.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cf.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: AppDimens.spaceMd),
                                TextField(
                                  controller: _otpController,
                                  enabled: !_isLoading,
                                  decoration: InputDecoration(
                                    labelText: 'Verification code',
                                    hintText: '6-digit code',
                                    helperText:
                                        'Check your SMS for a message from ${AppConstants.appName}',
                                    prefixIcon:
                                        const Icon(Icons.lock_outline),
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  onSubmitted: (_) => _verifyOtp(),
                                ),
                                const SizedBox(height: AppDimens.spaceMd),
                                CfButton(
                                  label: 'Verify & continue',
                                  isLoading: _isLoading,
                                  isGold: true,
                                  onPressed: _isLoading ? null : _verifyOtp,
                                ),
                                const SizedBox(height: AppDimens.spaceSm),
                                TextButton(
                                  onPressed: _isLoading ? null : _resetPhoneAuth,
                                  child: const Text('Change phone number'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimens.spaceLg),
                      TextButton(
                        onPressed: _isLoading ? null : () => context.go('/home'),
                        style: TextButton.styleFrom(
                          foregroundColor: heroEmphasis,
                        ),
                        child: const Text('Browse without signing in'),
                      ),
                      const SizedBox(height: AppDimens.spaceSm),
                      Text(
                        'Sign in to score matches, manage teams, and stream live.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialCountryLabel extends StatelessWidget {
  const _DialCountryLabel({
    required this.country,
    this.compact = false,
  });

  final CricketCountry country;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);

    if (compact) {
      return Row(
        children: [
          Text(country.flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${country.name} (${country.dialCode})',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Text(country.flag, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            country.name,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          country.dialCode,
          style: theme.textTheme.bodyMedium?.copyWith(color: cf.textSecondary),
        ),
      ],
    );
  }
}
