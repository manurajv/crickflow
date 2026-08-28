import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/deep_link_handler.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/player_invite_utils.dart';
import '../../../data/models/register_player_models.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import 'register_player_flow_screen.dart';

class PlayerInviteAcceptScreen extends ConsumerStatefulWidget {
  const PlayerInviteAcceptScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<PlayerInviteAcceptScreen> createState() =>
      _PlayerInviteAcceptScreenState();
}

class _PlayerInviteAcceptScreenState
    extends ConsumerState<PlayerInviteAcceptScreen> {
  PlayerInvitePreview? _invite;
  var _loading = true;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final invite =
          await ref.read(registerPlayerRepositoryProvider).getInvite(widget.token);
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _loading = false;
        if (invite == null) {
          _error = 'This invite link is not valid';
        } else if (invite.isExpired) {
          _error = 'This invite has expired';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _signInThenAccept() async {
    DeepLinkHandler.pendingPath = '/invite/${widget.token}';
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _accept() async {
    final invite = _invite;
    if (invite == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(registerPlayerRepositoryProvider).acceptInvite(invite.id);
      ref.invalidate(currentUserProfileProvider);
      if (!mounted) return;
      final profile = await ref.read(currentUserProfileProvider.future);
      if (!mounted) return;
      if (profile?.needsPlayerOnboarding == true) {
        context.go('/player-onboarding');
        return;
      }
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final invite = _invite;
    final phoneHint = invite != null && invite.hasPhone
        ? PlayerInviteUtils.maskPhone(invite.phoneNumber)
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Player invite')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppDimens.listPadding,
              children: [
                if (invite != null) ...[
                  Text(
                    '${invite.invitedByName} invited you to join CrickFlow.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    phoneHint == null
                        ? 'Sign in with Google or your phone to accept.'
                        : 'Sign in with Google or $phoneHint to accept.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
                if (_error != null)
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const SizedBox(height: AppDimens.spaceLg),
                if (invite != null && invite.isPending && !invite.isExpired)
                  CfButton(
                    label: user == null
                        ? 'Sign in to accept'
                        : 'Accept invite',
                    isGold: true,
                    isLoading: _busy,
                    onPressed: _busy
                        ? null
                        : () {
                            if (user == null) {
                              _signInThenAccept();
                            } else {
                              _accept();
                            }
                          },
                  ),
              ],
            ),
    );
  }
}
