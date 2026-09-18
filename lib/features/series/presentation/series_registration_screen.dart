import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/series_registration_fields.dart';

/// Collects Series registration fields from [SeriesSettingsModel], then optionally
/// submits a club join request.
class SeriesRegistrationScreen extends ConsumerStatefulWidget {
  const SeriesRegistrationScreen({
    super.key,
    required this.seriesId,
    this.clubId,
    this.afterJoin = false,
  });

  final String seriesId;
  final String? clubId;
  final bool afterJoin;

  @override
  ConsumerState<SeriesRegistrationScreen> createState() =>
      _SeriesRegistrationScreenState();
}

class _SeriesRegistrationScreenState
    extends ConsumerState<SeriesRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _playerId = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _nationalId = TextEditingController();
  final _passport = TextEditingController();
  DateTime? _dob;
  String? _profilePhotoUrl;
  String? _nationalIdDocUrl;
  String? _passportDocUrl;
  bool _saving = false;

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(currentUserProfileProvider).valueOrNull;
      if (user == null) return;
      if (_fullName.text.isEmpty) {
        _fullName.text = user.displayName.isNotEmpty
            ? user.displayName
            : user.name;
      }
      if (_playerId.text.isEmpty && (user.playerId?.isNotEmpty ?? false)) {
        _playerId.text = user.playerId!;
      }
      if (_phone.text.isEmpty && user.effectiveMobile.isNotEmpty) {
        _phone.text = user.effectiveMobile;
      }
      _profilePhotoUrl ??= user.photoUrl;
    });
  }

  Future<void> _submit(SeriesSettingsModel settings) async {
    if (!_formKey.currentState!.validate()) return;
    if (settings.requireDateOfBirth && _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date of birth is required')),
      );
      return;
    }
    if (settings.requireProfilePhoto &&
        (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo is required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .submitSeriesRegistration({
            'seriesId': widget.seriesId,
            if (widget.clubId != null) 'clubId': widget.clubId,
            'fullName': _fullName.text.trim(),
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
      if (widget.afterJoin && widget.clubId != null) {
        await ref.read(seriesFunctionsServiceProvider).submitPlayerJoinRequest({
          'seriesId': widget.seriesId,
          'clubId': widget.clubId,
          'registrationId': result['registrationId'],
          'displayName': _fullName.text.trim(),
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.afterJoin
                ? 'Registration and join request submitted'
                : 'Registration submitted for approval',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seriesAsync = ref.watch(seriesByIdProvider(widget.seriesId));
    return seriesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: const CfChromeAppBar(title: Text('Registration')),
        body: Center(child: Text('$e')),
      ),
      data: (series) {
        if (series == null) {
          return const Scaffold(
            body: Center(child: Text('Series not found')),
          );
        }
        final s = series.settings;
        return Scaffold(
          appBar: CfChromeAppBar(
            title: Text(
              widget.afterJoin ? 'Register & join' : 'Series registration',
            ),
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.spaceLg),
              children: [
                Text(
                  'Fill the details required by ${series.name}. '
                  'ID numbers and document photos stay private to organization admins.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppDimens.spaceLg),
                SeriesRegistrationFields(
                  settings: s,
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
                ),
                const SizedBox(height: AppDimens.spaceLg),
                FilledButton.icon(
                  onPressed: _saving ? null : () => _submit(s),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Submitting…' : 'Submit'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
