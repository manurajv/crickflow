import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/tournament/tournament_create_draft.dart';
import '../../../../../data/models/tournament/tournament_setup_meta.dart';
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
    this.onPickGroundOnMap,
  });

  final TournamentCreateDraft draft;
  final ValueChanged<TournamentCreateDraft> onChanged;
  final VoidCallback? onPickGroundOnMap;

  @override
  ConsumerState<TournamentCreateBasicStep> createState() =>
      _TournamentCreateBasicStepState();
}

class _TournamentCreateBasicStepState
    extends ConsumerState<TournamentCreateBasicStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _groundController;
  late final TextEditingController _organizerController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    _nameController = TextEditingController(text: d.name);
    _cityController = TextEditingController(text: d.city);
    _groundController = TextEditingController(text: d.ground);
    _organizerController = TextEditingController(text: d.organizerName);
    _phoneController = TextEditingController(text: d.organizerPhone);
    _emailController = TextEditingController(text: d.organizerEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _groundController.dispose();
    _organizerController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _patch(TournamentCreateDraft Function(TournamentCreateDraft) fn) {
    widget.onChanged(fn(widget.draft));
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
          onBannerPicked: (f) => _patch((x) => x.copyWith(bannerLocalFile: f)),
          onLogoPicked: (f) => _patch((x) => x.copyWith(logoLocalFile: f)),
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
        GroundSearchField(
          controller: _groundController,
          onVenueChanged: (v) => _patch((x) => x.copyWith(ground: v)),
          onLocationResolved: (loc) => _patch((x) => x.copyWith(
                location: x.location.copyWith(
                  country: loc.country.isNotEmpty ? loc.country : x.location.country,
                  stateProvince: loc.stateProvince,
                  city: loc.city.isNotEmpty ? loc.city : x.location.city,
                ),
                city: loc.city.isNotEmpty ? loc.city : x.city,
              )),
          onPickOnMap: widget.onPickGroundOnMap ?? () {},
        ),
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
            style: TextStyle(fontSize: 11, color: cf.textMuted, fontStyle: FontStyle.italic),
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TournamentMatchFormat.values.map((f) {
            return TournamentChoiceChip(
              label: tournamentMatchFormatLabel(f),
              selected: d.matchFormat == f,
              onTap: () => _patch((x) => x.copyWith(matchFormat: f)),
            );
          }).toList(),
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
