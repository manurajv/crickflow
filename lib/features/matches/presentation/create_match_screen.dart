import 'package:flutter/material.dart';
import 'package:crickflow/core/theme/app_dimens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../data/models/location_model.dart';
import '../../../data/models/match_model.dart';
import '../../../data/models/match_rules_model.dart';
import '../../../data/models/team_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/location_fields.dart';
import '../../../shared/widgets/match_rules_editor.dart';
import '../../../shared/widgets/team_selector.dart';

class CreateMatchScreen extends ConsumerStatefulWidget {
  const CreateMatchScreen({super.key});

  @override
  ConsumerState<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends ConsumerState<CreateMatchScreen> {
  final _titleController = TextEditingController();
  final _teamANameController = TextEditingController();
  final _teamBNameController = TextEditingController();
  final _venueController = TextEditingController();
  MatchRulesModel _rules = MatchRulesModel.standardT20();
  LocationModel _location = const LocationModel(country: AppConstants.defaultCountry);
  TeamModel? _teamA;
  TeamModel? _teamB;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _teamANameController.dispose();
    _teamBNameController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  String get _teamAName => _teamA?.name ?? _teamANameController.text.trim();
  String get _teamBName => _teamB?.name ?? _teamBNameController.text.trim();

  Future<void> _createMatch() async {
    if (_teamAName.isEmpty || _teamBName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or enter both teams')),
      );
      return;
    }

    var title = _titleController.text.trim();
    if (title.isEmpty) title = '$_teamAName vs $_teamBName';

    setState(() => _isSaving = true);
    final uid = ref.read(authStateProvider).value?.uid;
    final match = MatchModel(
      id: const Uuid().v4(),
      title: title,
      matchType: MatchType.single,
      status: MatchStatus.scheduled,
      teamAId: _teamA?.id,
      teamBId: _teamB?.id,
      teamAName: _teamAName,
      teamBName: _teamBName,
      rules: _rules,
      location: _location,
      venue: _venueController.text.trim(),
      scheduledAt: DateTime.now(),
      createdBy: uid,
    );

    try {
      final id = await ref.read(matchRepositoryProvider).createMatch(match);
      if (mounted) context.go('/match/$id');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create match: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Match')),
      body: teamsAsync.when(
        data: (teams) => ListView(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Match Title (optional)',
                hintText: 'Auto-filled from team names',
              ),
            ),
            const SizedBox(height: 20),
            const Text('Teams',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TeamSelector(
              label: 'Team A',
              teams: teams,
              selectedTeamId: _teamA?.id,
              customName: _teamANameController.text,
              onTeamSelected: (t) {
                setState(() {
                  _teamA = t;
                  if (t != null) _teamANameController.text = t.name;
                });
              },
              onCustomNameChanged: (v) => _teamANameController.text = v,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TeamSelector(
              label: 'Team B',
              teams: teams,
              selectedTeamId: _teamB?.id,
              customName: _teamBNameController.text,
              onTeamSelected: (t) {
                setState(() {
                  _teamB = t;
                  if (t != null) _teamBNameController.text = t.name;
                });
              },
              onCustomNameChanged: (v) => _teamBNameController.text = v,
            ),
            if (teams.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Tip: Create teams under Teams tab for linked squads & stats.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            const SizedBox(height: AppDimens.spaceMd),
            TextField(
              controller: _venueController,
              decoration: const InputDecoration(labelText: 'Venue'),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const Text('Location',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            LocationFields(
              location: _location,
              onChanged: (l) => setState(() => _location = l),
            ),
            const SizedBox(height: AppDimens.spaceLg),
            const Text('Match Rules',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            MatchRulesEditor(
              rules: _rules,
              onChanged: (r) => setState(() => _rules = r),
            ),
            const SizedBox(height: AppDimens.spaceXl),
            CfButton(
              label: 'Create Match',
              icon: Icons.check,
              isGold: true,
              isLoading: _isSaving,
              onPressed: _createMatch,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
