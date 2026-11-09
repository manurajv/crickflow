import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';
import 'widgets/org_permissions_section.dart';
import 'widgets/series_owner_section.dart';

class SeriesSettingsScreen extends ConsumerStatefulWidget {
  const SeriesSettingsScreen({super.key, required this.seriesId});
  final String seriesId;

  @override
  ConsumerState<SeriesSettingsScreen> createState() =>
      _SeriesSettingsScreenState();
}

class _SeriesSettingsScreenState extends ConsumerState<SeriesSettingsScreen> {
  bool _initialized = false;
  bool _saving = false;
  final _rules = TextEditingController();

  late int _maxSquad;
  late bool _requireFullName;
  late bool _requirePlayerId;
  late bool _requireDob;
  late bool _requireNationalId;
  late bool _requirePassport;
  late bool _requirePhone;
  late bool _requireAddress;
  late bool _requirePhoto;
  late int _winPoints;
  late int _lossPoints;
  late int _tiePoints;
  late int _nrPoints;
  late bool _useNrr;

  // Snapshot for dirty tracking
  String _rulesSaved = '';
  int _maxSquadSaved = 0;
  bool _requireFullNameSaved = false;
  bool _requirePlayerIdSaved = false;
  bool _requireDobSaved = false;
  bool _requireNationalIdSaved = false;
  bool _requirePassportSaved = false;
  bool _requirePhoneSaved = false;
  bool _requireAddressSaved = false;
  bool _requirePhotoSaved = false;
  int _winPointsSaved = 0;
  int _lossPointsSaved = 0;
  int _tiePointsSaved = 0;
  int _nrPointsSaved = 0;
  bool _useNrrSaved = false;

  @override
  void dispose() {
    _rules.dispose();
    super.dispose();
  }

  bool get isDirty =>
      _rules.text.trim() != _rulesSaved ||
      _maxSquad != _maxSquadSaved ||
      _requireFullName != _requireFullNameSaved ||
      _requirePlayerId != _requirePlayerIdSaved ||
      _requireDob != _requireDobSaved ||
      _requireNationalId != _requireNationalIdSaved ||
      _requirePassport != _requirePassportSaved ||
      _requirePhone != _requirePhoneSaved ||
      _requireAddress != _requireAddressSaved ||
      _requirePhoto != _requirePhotoSaved ||
      _winPoints != _winPointsSaved ||
      _lossPoints != _lossPointsSaved ||
      _tiePoints != _tiePointsSaved ||
      _nrPoints != _nrPointsSaved ||
      _useNrr != _useNrrSaved;

  void _hydrate(SeriesModel series) {
    if (_initialized) return;
    final s = series.settings;
    _maxSquad = s.maxSquadSize;
    _requireFullName = s.requireFullName;
    _requirePlayerId = s.requireCrickFlowPlayerId;
    _requireDob = s.requireDateOfBirth;
    _requireNationalId = s.requireNationalId;
    _requirePassport = s.requirePassport;
    _requirePhone = s.requirePhoneNumber;
    _requireAddress = s.requireAddress;
    _requirePhoto = s.requireProfilePhoto;
    _winPoints = s.rankingRules.winPoints;
    _lossPoints = s.rankingRules.lossPoints;
    _tiePoints = s.rankingRules.tiePoints;
    _nrPoints = s.rankingRules.noResultPoints;
    _useNrr = s.rankingRules.useNetRunRate;
    _rules.text = series.rulesText;
    _captureSaved();
    _rules.addListener(() => setState(() {}));
    _initialized = true;
  }

  void _captureSaved() {
    _rulesSaved = _rules.text.trim();
    _maxSquadSaved = _maxSquad;
    _requireFullNameSaved = _requireFullName;
    _requirePlayerIdSaved = _requirePlayerId;
    _requireDobSaved = _requireDob;
    _requireNationalIdSaved = _requireNationalId;
    _requirePassportSaved = _requirePassport;
    _requirePhoneSaved = _requirePhone;
    _requireAddressSaved = _requireAddress;
    _requirePhotoSaved = _requirePhoto;
    _winPointsSaved = _winPoints;
    _lossPointsSaved = _lossPoints;
    _tiePointsSaved = _tiePoints;
    _nrPointsSaved = _nrPoints;
    _useNrrSaved = _useNrr;
  }

  Future<void> _save() async {
    if (!isDirty || _saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(seriesFunctionsServiceProvider)
          .updateSeriesSettings(
            seriesId: widget.seriesId,
            settings: {
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
                'winPoints': _winPoints,
                'lossPoints': _lossPoints,
                'tiePoints': _tiePoints,
                'noResultPoints': _nrPoints,
                'bonusPointsEnabled': false,
                'useNetRunRate': _useNrr,
                'useRunDifference': false,
              },
            },
          );
      await FirebaseFirestore.instance
          .collection(AppConstants.seriesCollection)
          .doc(widget.seriesId)
          .update({
            'rulesText': _rules.text.trim(),
            'updatedAt': DateTime.now().toIso8601String(),
          });
      if (!mounted) return;
      setState(_captureSaved);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmLeave() async {
    if (!isDirty) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved settings. Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final seriesAsync = ref.watch(seriesByIdProvider(widget.seriesId));
    final role = ref.watch(mySeriesRoleProvider(widget.seriesId));
    return seriesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (series) {
        if (series == null) {
          return const Scaffold(body: Center(child: Text('Series not found')));
        }
        if (role != SeriesRole.superAdmin) {
          return Scaffold(
            appBar: const CfChromeAppBar(title: Text('Settings')),
            body: const Center(
              child: Text('Only the Series Super Admin can edit settings'),
            ),
          );
        }
        _hydrate(series);
        final dirty = isDirty;
        return PopScope(
          canPop: !dirty,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final nav = GoRouter.of(context);
            _confirmLeave().then((ok) {
              if (ok && mounted) nav.pop();
            });
          },
          child: Scaffold(
            appBar: const CfChromeAppBar(title: Text('Series settings')),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('org_settings_save_fab'),
              heroTag: 'org_settings_save_fab',
              backgroundColor: dirty && !_saving
                  ? cf.fabBackground
                  : cf.fabBackground.withValues(alpha: 0.45),
              foregroundColor: cf.fabForeground,
              onPressed: dirty && !_saving ? _save : null,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cf.fabForeground,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Saving…' : 'Save settings'),
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                AppDimens.spaceLg,
                AppDimens.spaceLg,
                AppDimens.spaceLg + 88,
              ),
              children: [
                OrgPermissionsSection(seriesId: widget.seriesId),
                Text('Rules', style: Theme.of(context).textTheme.titleMedium),
                TextField(
                  controller: _rules,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Rules / playing conditions',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text('Squad', style: Theme.of(context).textTheme.titleMedium),
                Row(
                  children: [
                    const Expanded(child: Text('Maximum squad size')),
                    IconButton(
                      onPressed: _maxSquad > 1
                          ? () => setState(() => _maxSquad--)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('$_maxSquad'),
                    IconButton(
                      onPressed: () => setState(() => _maxSquad++),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  'Registration requirements',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  title: const Text('Full name'),
                  value: _requireFullName,
                  onChanged: (v) => setState(() => _requireFullName = v),
                ),
                SwitchListTile(
                  title: const Text('CrickFlow Player ID'),
                  value: _requirePlayerId,
                  onChanged: (v) => setState(() => _requirePlayerId = v),
                ),
                SwitchListTile(
                  title: const Text('Date of birth'),
                  value: _requireDob,
                  onChanged: (v) => setState(() => _requireDob = v),
                ),
                SwitchListTile(
                  title: const Text('National ID (private)'),
                  value: _requireNationalId,
                  onChanged: (v) => setState(() => _requireNationalId = v),
                ),
                SwitchListTile(
                  title: const Text('Passport (private)'),
                  value: _requirePassport,
                  onChanged: (v) => setState(() => _requirePassport = v),
                ),
                SwitchListTile(
                  title: const Text('Phone number'),
                  value: _requirePhone,
                  onChanged: (v) => setState(() => _requirePhone = v),
                ),
                SwitchListTile(
                  title: const Text('Address'),
                  value: _requireAddress,
                  onChanged: (v) => setState(() => _requireAddress = v),
                ),
                SwitchListTile(
                  title: const Text('Profile photo'),
                  value: _requirePhoto,
                  onChanged: (v) => setState(() => _requirePhoto = v),
                ),
                const Divider(),
                Text(
                  'Team ranking points',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                _pointsRow(
                  'Win',
                  _winPoints,
                  (v) => setState(() => _winPoints = v),
                ),
                _pointsRow(
                  'Loss',
                  _lossPoints,
                  (v) => setState(() => _lossPoints = v),
                ),
                _pointsRow(
                  'Tie',
                  _tiePoints,
                  (v) => setState(() => _tiePoints = v),
                ),
                _pointsRow(
                  'No result',
                  _nrPoints,
                  (v) => setState(() => _nrPoints = v),
                ),
                SwitchListTile(
                  title: const Text('Use net run rate'),
                  value: _useNrr,
                  onChanged: (v) => setState(() => _useNrr = v),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                const Divider(),
                const SizedBox(height: AppDimens.spaceSm),
                SeriesOwnerSection(series: series),
                const SizedBox(height: AppDimens.spaceLg),
              ],
            ),
          ),
        );
      },
    );
  }

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
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
