import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/routing/deep_link_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/match_permissions.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/auth_intent_provider.dart';
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
      final role = ref.read(signUpRoleProvider);
      final profile = await ref
          .read(authRepositoryProvider)
          .signInWithGoogle(intendedRole: role);
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
      final role = ref.read(signUpRoleProvider);
      final profile = await ref.read(authRepositoryProvider).verifyPhoneOtp(
            verificationId: _verificationId!,
            smsCode: _otpController.text.trim(),
            intendedRole: role,
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

  Widget _rolePicker() {
    final selected = ref.watch(signUpRoleProvider);

    Widget chip(UserRole role, String label, IconData icon) {
      final isSelected = selected == role;
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: isSelected ? Colors.black : null),
                const SizedBox(height: 4),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11)),
              ],
            ),
            selected: isSelected,
            selectedColor: AppColors.gold,
            onSelected: (_) =>
                ref.read(signUpRoleProvider.notifier).state = role,
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(UserRole.organizer, 'Scorer /\nOrganizer', Icons.scoreboard),
        chip(UserRole.player, 'Player', Icons.sports),
        chip(UserRole.viewer, 'Viewer', Icons.visibility),
      ],
    );
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
                  'Professional cricket scoring for Sri Lanka',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                const Text(
                  'I am signing in as',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                _rolePicker(),
                const SizedBox(height: 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
