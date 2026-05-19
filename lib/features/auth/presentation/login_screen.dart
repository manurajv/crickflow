import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routing/deep_link_handler.dart';
import '../../../core/theme/app_colors.dart';
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

  Future<void> _goAfterAuth(UserModel profile) async {
    final pending = DeepLinkHandler.takePendingPath();
    final route = pending ?? homeRouteForRole(profile.role);
    if (mounted) context.go(route);
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
    final phone = _phoneController.text.trim();
    if (!phone.startsWith('+')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Use international format: +94...')),
      );
      return;
    }
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
          SnackBar(content: Text(e.message ?? 'Phone auth failed')),
        );
      },
    );
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null) return;
    setState(() => _isLoading = true);
    try {
      final profile = await ref.read(authRepositoryProvider).verifyPhoneOtp(
            verificationId: _verificationId!,
            smsCode: _otpController.text.trim(),
          );
      await _goAfterAuth(profile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Icon(Icons.sports_cricket, size: 64, color: AppColors.gold),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Score matches, join squads, and stream live — one account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CfButton(
                          label: 'Continue with Google',
                          icon: Icons.g_mobiledata,
                          isLoading: _isLoading && !_showOtp,
                          onPressed: _googleSignIn,
                        ),
                        const SizedBox(height: 24),
                        const Row(children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('OR'),
                          ),
                          Expanded(child: Divider()),
                        ]),
                        const SizedBox(height: 24),
                        if (!_showOtp) ...[
                          TextField(
                            controller: _phoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone (+94...)',
                              prefixIcon: Icon(Icons.phone),
                            ),
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          CfButton(
                            label: 'Send OTP',
                            icon: Icons.sms,
                            isLoading: _isLoading,
                            isOutlined: true,
                            onPressed: _sendOtp,
                          ),
                        ] else ...[
                          TextField(
                            controller: _otpController,
                            decoration: const InputDecoration(
                              labelText: 'Enter OTP',
                              prefixIcon: Icon(Icons.pin),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          CfButton(
                            label: 'Verify OTP',
                            isLoading: _isLoading,
                            isGold: true,
                            onPressed: _verifyOtp,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Spectator-only mode can be enabled later in Profile → App mode.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
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
