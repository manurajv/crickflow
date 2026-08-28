import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../core/utils/cf_player_id_format.dart';
import '../../../core/utils/phone_auth_utils.dart';
import '../../../core/utils/player_invite_utils.dart';
import '../../../data/models/register_player_models.dart';
import '../../../data/repositories/register_player_repository.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';

final registerPlayerRepositoryProvider =
    Provider<RegisterPlayerRepository>((ref) => RegisterPlayerRepository());

class RegisterPlayerFlowScreen extends ConsumerStatefulWidget {
  const RegisterPlayerFlowScreen({
    super.key,
    this.args = const RegisterPlayerArgs(),
  });

  final RegisterPlayerArgs args;

  @override
  ConsumerState<RegisterPlayerFlowScreen> createState() =>
      _RegisterPlayerFlowScreenState();
}

enum _Stage { compose, existing, share }

class _RegisterPlayerFlowScreenState
    extends ConsumerState<RegisterPlayerFlowScreen> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();

  String _dialCode = '+94';
  _Stage _stage = _Stage.compose;
  /// Phone = number + either Google/phone accept; Google = link-only (Google or any phone).
  var _mode = PlayerInviteType.either;
  var _busy = false;
  String? _error;
  ExistingPlayerMatch? _existing;
  PlayerInviteCreated? _invite;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _e164 => PhoneAuthUtils.toE164(
        dialCode: _dialCode,
        nationalNumber: _phoneController.text,
      );

  String get _playerName => _nameController.text.trim();

  bool get _needsPhone => _mode != PlayerInviteType.google;

  Future<void> _createInvite() async {
    FocusScope.of(context).unfocus();
    if (_busy) return;

    if (_needsPhone &&
        !PhoneAuthUtils.isValidNationalNumber(_phoneController.text)) {
      setState(() => _error = 'Enter a valid mobile number');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repo = ref.read(registerPlayerRepositoryProvider);
      if (_needsPhone) {
        final existing = await repo.lookupByPhone(_e164);
        if (!mounted) return;
        if (existing != null) {
          setState(() {
            _existing = existing;
            _stage = _Stage.existing;
            _busy = false;
          });
          return;
        }
      }

      final invite = await repo.createInvite(
        phoneE164: _needsPhone ? _e164 : null,
        displayName: _playerName.isEmpty ? null : _playerName,
        inviteType: _mode,
      );
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _stage = _Stage.share;
        _busy = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists' && _needsPhone) {
        try {
          final existing =
              await ref.read(registerPlayerRepositoryProvider).lookupByPhone(_e164);
          if (!mounted) return;
          if (existing != null) {
            setState(() {
              _existing = existing;
              _stage = _Stage.existing;
              _busy = false;
              _error = null;
            });
            return;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.message ?? 'Could not create the invite';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  void _doneAfterInvite() {
    if (widget.args.popWithPlayer) {
      context.pop('invited');
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          switch (_stage) {
            _Stage.compose => 'Invite a player',
            _Stage.existing => 'Player already registered',
            _Stage.share => 'Share invite link',
          },
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: switch (_stage) {
          _Stage.compose => _buildCompose(cf),
          _Stage.existing => _buildExisting(cf),
          _Stage.share => _buildShare(cf),
        },
      ),
    );
  }

  Widget _buildCompose(CfColors cf) {
    final countries = [...CricketCountry.countriesByDialCode];
    if (CricketCountry.byDialCode(_dialCode) == null) {
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

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Text(
          'Share a link. The player can join with Google or their phone — both work.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        SegmentedButton<PlayerInviteType>(
          segments: const [
            ButtonSegment(
              value: PlayerInviteType.either,
              label: Text('Mobile number'),
              icon: Icon(Icons.phone_outlined),
            ),
            ButtonSegment(
              value: PlayerInviteType.google,
              label: Text('Google / link'),
              icon: Icon(Icons.account_circle_outlined),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: _busy
              ? null
              : (next) {
                  setState(() {
                    _mode = next.first;
                    _error = null;
                  });
                },
        ),
        const SizedBox(height: AppDimens.spaceMd),
        Text(
          _mode == PlayerInviteType.google
              ? 'No phone needed. They open the link and sign in with Google (phone also works).'
              : 'Enter their number. They can still accept with Google or that phone OTP.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textMuted,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        if (_needsPhone) ...[
          DropdownButtonFormField<String>(
            value: _dialCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Country',
              prefixIcon: Icon(Icons.public_outlined),
            ),
            items: countries
                .map(
                  (c) => DropdownMenuItem(
                    value: c.dialCode,
                    child: Text(
                      '${c.flag}  ${c.name} (${c.dialCode})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy
                ? null
                : (v) {
                    if (v != null) setState(() => _dialCode = v);
                  },
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _phoneController,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Mobile number',
              hintText: PhoneAuthUtils.hintForDialCode(_dialCode),
              helperText: 'Digits only — no country code',
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _createInvite(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        TextField(
          controller: _nameController,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Name (optional)',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppDimens.spaceLg),
        CfButton(
          label: 'Create invite link',
          icon: Icons.link,
          isGold: true,
          isLoading: _busy,
          onPressed: _busy ? null : _createInvite,
        ),
      ],
    );
  }

  Widget _buildShare(CfColors cf) {
    final invite = _invite;
    if (invite == null) return const SizedBox.shrink();
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final targetLine = _needsPhone
        ? 'Share this link with $_e164. They can join with Google or that phone — no SMS is sent from your device.'
        : 'Share this link. They can join with Google (or phone) on the app or web.';
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Text(
          targetLine,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        SelectableText(
          invite.url,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.link,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        CfButton(
          label: 'Share via WhatsApp',
          icon: Icons.chat,
          isGold: true,
          onPressed: () => PlayerInviteUtils.shareWhatsApp(
            invite,
            playerName: _playerName.isEmpty ? null : _playerName,
            registrarName: profile?.displayName ?? profile?.name,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        CfButton(
          label: 'Share',
          icon: Icons.share_outlined,
          isOutlined: true,
          onPressed: () => PlayerInviteUtils.shareLink(
            invite,
            playerName: _playerName.isEmpty ? null : _playerName,
            registrarName: profile?.displayName ?? profile?.name,
          ),
        ),
        const SizedBox(height: AppDimens.spaceSm),
        CfButton(
          label: 'Copy link',
          icon: Icons.copy,
          isOutlined: true,
          onPressed: () async {
            await PlayerInviteUtils.copyLink(invite);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invite link copied')),
            );
          },
        ),
        const SizedBox(height: AppDimens.spaceLg),
        Text(
          'Same-day match play without an account still uses Walk-in.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cf.textMuted,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        CfButton(
          label: 'Done',
          onPressed: _doneAfterInvite,
        ),
      ],
    );
  }

  Widget _buildExisting(CfColors cf) {
    final existing = _existing;
    if (existing == null) return const SizedBox.shrink();
    return ListView(
      padding: AppDimens.listPadding,
      children: [
        Text(
          'This mobile number already has a CrickFlow account.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: cf.textSecondary,
              ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            backgroundImage: existing.photoUrl != null
                ? CachedNetworkImageProvider(existing.photoUrl!)
                : null,
            child: existing.photoUrl == null
                ? Text(
                    existing.displayName.isNotEmpty
                        ? existing.displayName[0].toUpperCase()
                        : '?',
                  )
                : null,
          ),
          title: Text(existing.displayName),
          subtitle: Text(
            existing.playerId != null && existing.playerId!.isNotEmpty
                ? CfPlayerIdFormat.displayLabel(existing.playerId)
                : 'Registered player',
          ),
        ),
        const SizedBox(height: AppDimens.spaceLg),
        if (widget.args.popWithPlayer)
          CfButton(
            label: 'Select player',
            isGold: true,
            onPressed: () async {
              final player = await ref
                  .read(playerRepositoryProvider)
                  .getPlayer(existing.playerDocId);
              if (!mounted) return;
              context.pop(player);
            },
          )
        else
          CfButton(
            label: 'View player',
            isGold: true,
            onPressed: () => context.push('/player/${existing.playerDocId}'),
          ),
        const SizedBox(height: AppDimens.spaceSm),
        CfButton(
          label: 'Cancel',
          isOutlined: true,
          onPressed: () => context.pop(),
        ),
      ],
    );
  }
}
