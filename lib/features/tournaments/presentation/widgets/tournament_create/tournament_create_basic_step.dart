import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/location_model.dart';
import '../../../../../data/models/tournament/tournament_create_draft.dart';
import '../../../../../data/models/tournament/tournament_setup_meta.dart';
import '../../../../../features/matches/presentation/models/ground_pick_result.dart';
import '../../../../../features/matches/presentation/widgets/ground_search_field.dart';
import '../../../../../shared/widgets/cf_underlined_field.dart';
import '../../../../../shared/widgets/start_match_ui.dart';
import 'tournament_create_ui.dart';
import 'tournament_media_picker.dart';

class TournamentCreateBasicStep extends ConsumerStatefulWidget {
  const TournamentCreateBasicStep({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final TournamentCreateDraft draft;
  final ValueChanged<TournamentCreateDraft> onChanged;

  @override
  ConsumerState<TournamentCreateBasicStep> createState() =>
      _TournamentCreateBasicStepState();
}

class _TournamentCreateBasicStepState
    extends ConsumerState<TournamentCreateBasicStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _groundInputController;
  late final TextEditingController _organizerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nameController = TextEditingController(text: d.name);
    _cityController = TextEditingController(text: d.city);
    _groundInputController = TextEditingController();
    _organizerController = TextEditingController(text: d.organizerName);
    _phoneController = TextEditingController(text: d.organizerPhone);
    _emailController = TextEditingController(text: d.organizerEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _groundInputController.dispose();
    _organizerController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _patch(TournamentCreateDraft Function(TournamentCreateDraft) fn) {
    widget.onChanged(fn(widget.draft));
  }

  void _syncControllersFromDraft(TournamentCreateDraft d) {
    void set(TextEditingController controller, String value) {
      if (controller.text != value) controller.text = value;
    }

    set(_cityController, d.city);
    set(_organizerController, d.organizerName);
    set(_phoneController, d.organizerPhone);
    set(_emailController, d.organizerEmail);
  }

  void _addGround(String name, {LocationModel? location}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final existing = widget.draft.grounds
        .map((g) => g.trim().toLowerCase())
        .toSet();
    if (existing.contains(trimmed.toLowerCase())) {
      _groundInputController.clear();
      return;
    }

    _groundInputController.clear();
    _patch((d) {
      var nextLocation = d.location;
      var nextCity = d.city;
      if (location != null) {
        nextCity = location.city.isNotEmpty ? location.city : d.city;
        if (location.city.isNotEmpty) {
          _cityController.text = location.city;
        }
        nextLocation = d.location.copyWith(
          country: location.country.isNotEmpty
              ? location.country
              : d.location.country,
          stateProvince: location.stateProvince,
          city: nextCity,
        );
      }
      return d.copyWith(
        grounds: [...d.grounds, trimmed],
        city: nextCity,
        location: nextLocation,
      );
    });
  }

  void _removeGround(String name) {
    _patch((d) => d.copyWith(
          grounds: d.grounds.where((g) => g != name).toList(),
        ));
  }

  void _applyGroundLocation(LocationModel loc) {
    _addGround(_groundInputController.text, location: loc);
  }

  Future<void> _pickGroundOnMap() async {
    final result = await context.push<GroundPickResult>(
      '/match/create/pick-ground',
      extra: {
        'location': widget.draft.location,
        'groundName': _groundInputController.text.trim(),
      },
    );
    if (result == null || !mounted) return;
    final loc = result.location.copyWith(
      latitude: result.coords?.latitude ?? result.location.latitude,
      longitude: result.coords?.longitude ?? result.location.longitude,
    );
    _addGround(result.groundName, location: loc);
  }

  @override
  void didUpdateWidget(covariant TournamentCreateBasicStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllersFromDraft(widget.draft);
  }

  Future<void> _pickDate({required bool start}) async {
    final initial = start
        ? widget.draft.startDate
        : widget.draft.endDate ?? widget.draft.startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    _patch((d) => d.copyWith(
          startDate: start ? picked : d.startDate,
          endDate: start ? d.endDate : picked,
        ));
  }

  String _dateLabel(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('dd MMM yyyy').format(dt);
  }

  Widget _buildGroundsSection(TournamentCreateDraft d) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (d.grounds.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: d.grounds.map((ground) {
              return InputChip(
                label: Text(ground),
                onDeleted: () => _removeGround(ground),
                deleteIconColor: cf.textSecondary,
              );
            }).toList(),
          ),
          const SizedBox(height: AppDimens.spaceSm),
        ],
        GroundSearchField(
          controller: _groundInputController,
          onVenueChanged: (_) {},
          onLocationResolved: _applyGroundLocation,
          onPickOnMap: _pickGroundOnMap,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _addGround(_groundInputController.text),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add ground'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final d = widget.draft;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceXl + 24,
        AppDimens.spaceMd,
        AppDimens.spaceXl,
      ),
      children: [
        TournamentMediaPicker(
          bannerFile: d.bannerLocalFile,
          logoFile: d.logoLocalFile,
          thumbnailFile: d.thumbnailLocalFile,
          thumbnailAspect: d.thumbnailAspect,
          onBannerPicked: (f) => _patch((x) => x.copyWith(bannerLocalFile: f)),
          onLogoPicked: (f) => _patch((x) => x.copyWith(logoLocalFile: f)),
          onThumbnailPicked: (file, aspect) => _patch(
            (x) => x.copyWith(
              thumbnailLocalFile: file,
              thumbnailAspect: aspect,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceXl + 16),
        CfUnderlinedField(
          controller: _nameController,
          label: 'Tournament / series name',
          required: true,
          onChanged: (v) => _patch((x) => x.copyWith(name: v)),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _cityController,
          label: 'City',
          required: true,
          onChanged: (v) => _patch((x) => x.copyWith(
                city: v,
                location: x.location.copyWith(city: v),
              )),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        const TournamentCreateSectionLabel(label: 'Grounds', required: true),
        _buildGroundsSection(d),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _organizerController,
          label: 'Organiser name',
          required: true,
          onChanged: (v) => _patch((x) => x.copyWith(organizerName: v)),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _phoneController,
          label: 'Organiser number',
          required: true,
          keyboardType: TextInputType.phone,
          onChanged: (v) => _patch((x) => x.copyWith(organizerPhone: v)),
        ),
        const SizedBox(height: AppDimens.fieldSpacing),
        CfUnderlinedField(
          controller: _emailController,
          label: 'Organiser email',
          keyboardType: TextInputType.emailAddress,
          onChanged: (v) => _patch((x) => x.copyWith(organizerEmail: v)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '*Get updated with CrickFlow offers and help videos on mail.*',
            style: TextStyle(
              fontSize: 11,
              color: cf.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Tournament dates', required: true),
        Row(
          children: [
            Expanded(
              child: CfPickerField(
                label: 'Start date',
                required: true,
                value: _dateLabel(d.startDate),
                onTap: () => _pickDate(start: true),
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: CfPickerField(
                label: 'End date',
                required: true,
                value: _dateLabel(d.endDate),
                onTap: () => _pickDate(start: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Tournament category', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TournamentCategory.values.map((c) {
            return TournamentChoiceChip(
              label: tournamentCategoryLabel(c),
              selected: d.category == c,
              onTap: () => _patch((x) => x.copyWith(category: c)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Select ball type', required: true),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            CricketBallType.tennis,
            CricketBallType.leather,
          ].map((ball) {
            final label = ball == CricketBallType.leather ? 'Leather' : 'Tennis';
            final selected = ball == CricketBallType.leather
                ? d.ballType == CricketBallType.leather
                : d.ballType != CricketBallType.leather;
            return TournamentChoiceChip(
              label: label,
              selected: selected,
              onTap: () => _patch((x) => x.copyWith(
                    ballType: ball,
                    ballTypeOther: false,
                  )),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Pitch type'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PitchType.values.map((p) {
            final label = p.name.toUpperCase();
            return TournamentChoiceChip(
              label: label,
              selected: d.pitchType == p,
              onTap: () => _patch((x) => x.copyWith(pitchType: p)),
            );
          }).toList(),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        const TournamentCreateSectionLabel(label: 'Match type', required: true),
        const SizedBox(height: 8),
        TournamentCricketMatchTypePicker(
          selected: d.cricketMatchType,
          onSelected: (type) =>
              _patch((x) => x.copyWith(cricketMatchType: type)),
        ),
        const SizedBox(height: AppDimens.spaceMd),
        StartMatchCard(
          child: Column(
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Do you need more teams for your tournament?'),
                value: d.needMoreTeams,
                onChanged: (v) =>
                    _patch((x) => x.copyWith(needMoreTeams: v ?? false)),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Do you need officials? (e.g. Umpire, Scorer)'),
                value: d.needOfficials,
                onChanged: (v) =>
                    _patch((x) => x.copyWith(needOfficials: v ?? false)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
