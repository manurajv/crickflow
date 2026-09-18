import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/player_profile_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import '../../player_onboarding/presentation/widgets/country_picker_sheet.dart';
import '../../teams/presentation/utils/team_image_upload.dart';

class SeriesCreateScreen extends ConsumerStatefulWidget {
  const SeriesCreateScreen({super.key, this.initialFamily});

  final OrgFamily? initialFamily;

  @override
  ConsumerState<SeriesCreateScreen> createState() => _SeriesCreateScreenState();
}

class _SeriesCreateScreenState extends ConsumerState<SeriesCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _rules = TextEditingController();
  final _region = TextEditingController();
  final _location = TextEditingController();

  late SeriesKind _kind;
  late OrgFamily _family;
  File? _logoFile;
  File? _coverFile;
  bool _saving = false;
  bool _countryReady = false;
  String _country = '';

  int _maxSquad = 20;
  bool _requireFullName = true;
  bool _requirePlayerId = true;
  bool _requireDob = false;
  bool _requireNationalId = false;
  bool _requirePassport = false;
  bool _requirePhone = false;
  bool _requireAddress = false;
  bool _requirePhoto = false;
  int _winPoints = 2;
  int _lossPoints = 0;
  int _tiePoints = 1;
  int _nrPoints = 1;
  bool _useNrr = true;

  @override
  void initState() {
    super.initState();
    _family = widget.initialFamily ?? OrgFamily.series;
    _kind = _family.defaultKind;
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillCountry());
  }

  Future<void> _prefillCountry() async {
    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    String country = '';
    if (profile != null) {
      country = profile.country.trim().isNotEmpty
          ? profile.country.trim()
          : profile.location.country.trim();
    }
    if (country.isEmpty) {
      try {
        final authUser = ref.read(authStateProvider).value;
        if (authUser != null) {
          final loaded =
              await ref.read(userRepositoryProvider).getUser(authUser.uid);
          if (loaded != null) {
            country = loaded.country.trim().isNotEmpty
                ? loaded.country.trim()
                : loaded.location.country.trim();
          }
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _country = country;
      _countryReady = true;
    });
  }

  Future<void> _pickCountry() async {
    final selected = await showCountryPickerSheet(context);
    if (selected == null || !mounted) return;
    setState(() => _country = selected.name);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _rules.dispose();
    _region.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    await showTeamImageSourceSheet(
      context,
      onSelected: (source) async {
        final file = await pickAndCropTeamImage(
          context,
          kind: TeamImageKind.profile,
          source: source,
          cropTitle: 'Crop logo',
        );
        if (file == null || !mounted) return;
        setState(() => _logoFile = file);
      },
    );
  }

  Future<void> _pickCover() async {
    await showTeamImageSourceSheet(
      context,
      onSelected: (source) async {
        final file = await pickAndCropTeamImage(
          context,
          kind: TeamImageKind.cover,
          source: source,
          cropTitle: 'Crop cover photo',
        );
        if (file == null || !mounted) return;
        setState(() => _coverFile = file);
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_maxSquad < 1 || _maxSquad > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max players per club must be between 1 and 50')),
      );
      return;
    }
    if (!_requireFullName && !_requirePlayerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Require at least Full name or CrickFlow Player ID'),
        ),
      );
      return;
    }
    if (_country.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a country')),
      );
      return;
    }
    final typeLabel = _kind.label;
    setState(() => _saving = true);
    try {
      final profile = ref.read(currentUserProfileProvider).valueOrNull;
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .createSeries({
            'name': _name.text.trim(),
            'description': _description.text.trim(),
            'rulesText': _rules.text.trim(),
            'kind': _kind.name,
            'region': _region.text.trim(),
            'location': _location.text.trim(),
            'country': _country.trim(),
            if (profile?.displayName.isNotEmpty == true)
              'displayName': profile!.displayName,
            'settings': {
              'maxSquadSize': _maxSquad,
              'requireFullName': _requireFullName,
              'requireCrickFlowPlayerId': _requirePlayerId,
              'requireDateOfBirth': _requireDob,
              'requireNationalId': _requireNationalId,
              'requirePassport': _requirePassport,
              'requirePhoneNumber': _requirePhone,
              'requireAddress': _requireAddress,
              'requireProfilePhoto': _requirePhoto,
              'customRequiredFields': <String>[],
              'rankingRules': {
                'winPoints': _winPoints.clamp(0, 100),
                'lossPoints': _lossPoints.clamp(0, 100),
                'tiePoints': _tiePoints.clamp(0, 100),
                'noResultPoints': _nrPoints.clamp(0, 100),
                'bonusPointsEnabled': false,
                'useNetRunRate': _useNrr,
                'useRunDifference': false,
              },
            },
          });
      final id = (result['seriesId'] ?? result['id'])?.toString();
      if (id == null || id.isEmpty) {
        throw StateError('create returned no id');
      }

      var mediaWarning = false;
      try {
        String? logoUrl;
        String? coverUrl;
        final storage = ref.read(storageServiceProvider);
        if (_logoFile != null) {
          logoUrl = await storage.uploadSeriesLogo(id, _logoFile!);
        }
        if (_coverFile != null) {
          coverUrl = await storage.uploadSeriesCover(id, _coverFile!);
        }
        if (logoUrl != null || coverUrl != null) {
          await FirebaseFirestore.instance
              .collection(AppConstants.seriesCollection)
              .doc(id)
              .update({
                'logoUrl': ?logoUrl,
                'coverImageUrl': ?coverUrl,
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }
      } catch (_) {
        // Org already exists — don't fail create because branding upload failed.
        mediaWarning = true;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mediaWarning
                ? '$typeLabel created. Logo/cover could not be uploaded — add them in settings.'
                : '$typeLabel created',
          ),
        ),
      );
      context.go('/series/$id');
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create $typeLabel: ${e.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = error is StateError
            ? error.message
            : 'Something went wrong. Try again.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create $typeLabel: $message')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: AppDimens.spaceMd, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _pointsRow(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('$value'),
        IconButton(
          onPressed: value < 100 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  String? _validateName(String? value) {
    final v = value?.trim() ?? '';
    if (v.length < 3) return 'Enter at least 3 characters';
    if (v.length > 120) return 'Max 120 characters';
    return null;
  }

  String? _validateDescription(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 2000) return 'Max 2000 characters';
    return null;
  }

  String? _validateRules(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 10000) return 'Max 10000 characters';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = _kind.label;
    return Scaffold(
      appBar: CfChromeAppBar(title: Text('Create $typeLabel')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          children: [
            _sectionTitle('Basics'),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(
                labelText: '$typeLabel name',
                prefixIcon: const Icon(Icons.emoji_events_outlined),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              validator: _validateName,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            DropdownButtonFormField<SeriesKind>(
              // ignore: deprecated_member_use
              value: _kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _family.kinds
                  .map(
                    (k) => DropdownMenuItem(
                      value: k,
                      child: Text(k.label),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _kind = v);
              },
              validator: (v) => v == null ? 'Select a type' : null,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Country',
                prefixIcon: const Icon(Icons.public_outlined),
                errorText: _countryReady && _country.isEmpty
                    ? 'Country is required'
                    : null,
              ),
              child: InkWell(
                onTap: _saving ? null : _pickCountry,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          !_countryReady
                              ? 'Loading…'
                              : _country.isEmpty
                                  ? 'Select country'
                                  : '${CricketCountry.byName(_country)?.flag ?? ''} $_country'
                                      .trim(),
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextFormField(
              controller: _region,
              decoration: const InputDecoration(
                labelText: 'Zone / region (optional)',
                hintText: 'e.g. North, West',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
            ),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(
                labelText: 'City / district (optional)',
                hintText: 'e.g. Jaipur, Chandigarh',
              ),
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextFormField(
              controller: _description,
              minLines: 3,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'What this $typeLabel is about',
                alignLabelWithHint: true,
              ),
              validator: _validateDescription,
            ),
            TextFormField(
              controller: _rules,
              minLines: 4,
              maxLines: 8,
              maxLength: 10000,
              decoration: const InputDecoration(
                labelText: 'Rules / playing conditions',
                hintText: 'Formats, eligibility, discipline, ranking notes…',
                alignLabelWithHint: true,
              ),
              validator: _validateRules,
            ),
            _sectionTitle('Branding'),
            Text(
              'Same as teams & tournaments: camera or gallery, then crop (1:1 logo · 16:9 cover).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(_logoFile == null ? 'Logo' : 'Change logo'),
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving ? null : _pickCover,
                    icon: const Icon(Icons.wallpaper_outlined),
                    label: Text(
                      _coverFile == null ? 'Cover image' : 'Change cover',
                    ),
                  ),
                ),
              ],
            ),
            if (_logoFile != null || _coverFile != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              SizedBox(
                height: 96,
                child: Row(
                  children: [
                    if (_logoFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _logoFile!,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (_logoFile != null && _coverFile != null)
                      const SizedBox(width: 8),
                    if (_coverFile != null)
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _coverFile!,
                            height: 96,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            _sectionTitle('Squad'),
            Row(
              children: [
                const Expanded(child: Text('Max players per club')),
                IconButton(
                  onPressed: _maxSquad > 1
                      ? () => setState(() => _maxSquad--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_maxSquad'),
                IconButton(
                  onPressed: _maxSquad < 50
                      ? () => setState(() => _maxSquad++)
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            _sectionTitle('Registration requirements'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Full name'),
              value: _requireFullName,
              onChanged: (v) => setState(() => _requireFullName = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('CrickFlow Player ID'),
              value: _requirePlayerId,
              onChanged: (v) => setState(() => _requirePlayerId = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date of birth'),
              value: _requireDob,
              onChanged: (v) => setState(() => _requireDob = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('National ID (private)'),
              value: _requireNationalId,
              onChanged: (v) => setState(() => _requireNationalId = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Passport (private)'),
              value: _requirePassport,
              onChanged: (v) => setState(() => _requirePassport = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Phone number'),
              value: _requirePhone,
              onChanged: (v) => setState(() => _requirePhone = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Address'),
              value: _requireAddress,
              onChanged: (v) => setState(() => _requireAddress = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Profile photo'),
              value: _requirePhoto,
              onChanged: (v) => setState(() => _requirePhoto = v),
            ),
            _sectionTitle('Club ranking points'),
            _pointsRow('Win', _winPoints, (v) => setState(() => _winPoints = v)),
            _pointsRow(
              'Loss',
              _lossPoints,
              (v) => setState(() => _lossPoints = v),
            ),
            _pointsRow('Tie', _tiePoints, (v) => setState(() => _tiePoints = v)),
            _pointsRow(
              'No result',
              _nrPoints,
              (v) => setState(() => _nrPoints = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use net run rate'),
              value: _useNrr,
              onChanged: (v) => setState(() => _useNrr = v),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_saving ? 'Creating…' : 'Create $typeLabel'),
            ),
            const SizedBox(height: AppDimens.spaceLg),
          ],
        ),
      ),
    );
  }
}
