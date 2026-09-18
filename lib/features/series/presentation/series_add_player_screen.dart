import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../data/models/user_model.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_registration_fields.dart';

/// Search result → fill org-required details / docs → add to club squad.
class SeriesAddPlayerScreen extends ConsumerStatefulWidget {
  const SeriesAddPlayerScreen({
    super.key,
    required this.seriesId,
    required this.clubId,
    required this.player,
  });

  final String seriesId;
  final String clubId;
  final UserModel player;

  @override
  ConsumerState<SeriesAddPlayerScreen> createState() =>
      _SeriesAddPlayerScreenState();
}

class _SeriesAddPlayerScreenState extends ConsumerState<SeriesAddPlayerScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _playerId;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _nationalId;
  late final TextEditingController _passport;
  DateTime? _dob;
  String? _profilePhotoUrl;
  String? _nationalIdDocUrl;
  String? _passportDocUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.player;
    _fullName = TextEditingController(
      text: p.name.isNotEmpty
          ? p.name
          : (p.displayName.isNotEmpty ? p.displayName : ''),
    );
    _playerId = TextEditingController(text: p.playerId ?? '');
    _phone = TextEditingController(text: p.effectiveMobile);
    _address = TextEditingController();
    _nationalId = TextEditingController();
    _passport = TextEditingController();
    _profilePhotoUrl = p.photoUrl;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _playerId.dispose();
    _phone.dispose();
    _address.dispose();
    _nationalId.dispose();
    _passport.dispose();
    super.dispose();
  }

  Future<void> _submit(SeriesModel series, SeriesRole role) async {
    if (!_formKey.currentState!.validate()) return;
    final s = series.settings;
    if (s.requireDateOfBirth && _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required')),
      );
      return;
    }
    if (s.requireProfilePhoto &&
        (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result =
          await ref.read(seriesFunctionsServiceProvider).submitPlayerAddRequest({
        'seriesId': widget.seriesId,
        'clubId': widget.clubId,
        'userId': widget.player.id,
        'playerDocId': widget.player.id,
        'fullName': _fullName.text.trim(),
        'displayName': _fullName.text.trim(),
        'crickFlowPlayerId': _playerId.text.trim(),
        'phoneNumber': _phone.text.trim(),
        'address': _address.text.trim(),
        if (_dob != null) 'dateOfBirth': _dob!.toIso8601String(),
        if (_nationalId.text.trim().isNotEmpty)
          'nationalId': _nationalId.text.trim(),
        if (_passport.text.trim().isNotEmpty)
          'passportNumber': _passport.text.trim(),
        if (_profilePhotoUrl != null) 'profilePhotoUrl': _profilePhotoUrl,
        if (_nationalIdDocUrl != null) 'nationalIdDocUrl': _nationalIdDocUrl,
        if (_passportDocUrl != null) 'passportDocUrl': _passportDocUrl,
      });
      if (!mounted) return;
      final auto = result['autoApproved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? '${_fullName.text.trim()} added to the squad'
                : 'Add-player request submitted for organization approval',
          ),
        ),
      );
      context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add player: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final seriesAsync = ref.watch(seriesByIdProvider(widget.seriesId));
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    final isManager =
        role == SeriesRole.superAdmin || role == SeriesRole.seriesAdmin;
    final playerLabel = widget.player.displayName.isNotEmpty
        ? widget.player.displayName
        : (widget.player.name.isNotEmpty ? widget.player.name : 'Player');

    return seriesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: const CfChromeAppBar(title: Text('Add player')),
        body: Center(child: Text('$e')),
      ),
      data: (series) {
        if (series == null) {
          return const Scaffold(
            body: Center(child: Text('Organization not found')),
          );
        }
        return Scaffold(
          backgroundColor: cf.background,
          appBar: const CfChromeAppBar(title: Text('Add player')),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundImage: (widget.player.photoUrl == null ||
                            widget.player.photoUrl!.isEmpty)
                        ? null
                        : NetworkImage(widget.player.photoUrl!),
                    child: (widget.player.photoUrl == null ||
                            widget.player.photoUrl!.isEmpty)
                        ? Text(
                            playerLabel.isNotEmpty
                                ? playerLabel[0].toUpperCase()
                                : '?',
                          )
                        : null,
                  ),
                  title: Text(playerLabel),
                  subtitle: Text(
                    isManager
                        ? 'Will be added to the squad immediately'
                        : 'Requires organization admin approval',
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  'Complete the details required by ${series.name}. '
                  'ID numbers and document photos are visible only to organization admins.',
                  style: TextStyle(color: cf.textSecondary),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                SeriesRegistrationFields(
                  settings: series.settings,
                  seriesId: widget.seriesId,
                  fullName: _fullName,
                  playerId: _playerId,
                  phone: _phone,
                  address: _address,
                  nationalId: _nationalId,
                  passport: _passport,
                  dob: _dob,
                  onDobChanged: (d) => setState(() => _dob = d),
                  profilePhotoUrl: _profilePhotoUrl,
                  nationalIdDocUrl: _nationalIdDocUrl,
                  passportDocUrl: _passportDocUrl,
                  onProfilePhotoUrl: (u) =>
                      setState(() => _profilePhotoUrl = u),
                  onNationalIdDocUrl: (u) =>
                      setState(() => _nationalIdDocUrl = u),
                  onPassportDocUrl: (u) => setState(() => _passportDocUrl = u),
                  showOptionalEmptyFields: true,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(series, role),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isManager ? Icons.person_add : Icons.send_outlined),
                  label: Text(
                    _saving
                        ? 'Saving…'
                        : (isManager ? 'Add to squad' : 'Submit for approval'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
