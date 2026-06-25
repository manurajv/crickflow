import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/tournament_join_navigation.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/tournament_providers.dart';
import '../../../../shared/widgets/cf_button.dart';

Future<bool> showTournamentDeleteSheet({
  required BuildContext context,
  required WidgetRef ref,
  required TournamentModel tournament,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    showDragHandle: true,
    builder: (ctx) => _TournamentDeleteSheet(
      tournament: tournament,
      ref: ref,
    ),
  );
  return result ?? false;
}

class _TournamentDeleteSheet extends ConsumerStatefulWidget {
  const _TournamentDeleteSheet({
    required this.tournament,
    required this.ref,
  });

  final TournamentModel tournament;
  final WidgetRef ref;

  @override
  ConsumerState<_TournamentDeleteSheet> createState() =>
      _TournamentDeleteSheetState();
}

class _TournamentDeleteSheetState extends ConsumerState<_TournamentDeleteSheet> {
  var _busy = false;
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _confirmController.dispose();
    super.dispose();
  }

  bool get _nameMatches =>
      _confirmController.text.trim() == widget.tournament.name.trim();

  Future<void> _delete() async {
    final uid = widget.ref.read(authStateProvider).value?.uid;
    if (uid == null) return;

    setState(() => _busy = true);
    try {
      await widget.ref.read(tournamentRepositoryProvider).deleteTournament(
            tournamentId: widget.tournament.id,
            requestingUserId: uid,
          );
      widget.ref.invalidate(tournamentsProvider);
      if (!mounted) return;
      Navigator.pop(context, true);
      if (!context.mounted) return;
      goToMyCricketTournamentsTab(widget.ref, context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament deleted')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final matchCount = widget.tournament.matchIds.length;
    final teamCount = widget.tournament.teamIds.length;

    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Delete tournament?',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'This permanently removes ${widget.tournament.name}, all fixtures, '
            'teams links, officials, analytics, and related community posts. '
            'This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          _DeleteStatRow(
            icon: Icons.groups_outlined,
            label: '$teamCount teams linked',
          ),
          _DeleteStatRow(
            icon: Icons.sports_cricket_outlined,
            label: '$matchCount matches scheduled',
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _confirmController,
            decoration: InputDecoration(
              labelText: 'Type tournament name to confirm',
              hintText: widget.tournament.name,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppDimens.spaceLg),
          CfButton(
            label: _busy ? 'Deleting…' : 'Delete permanently',
            isDanger: true,
            isLoading: _busy,
            onPressed: _busy || !_nameMatches ? null : _delete,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          CfButton(
            label: 'Cancel',
            isOutlined: true,
            onPressed: _busy ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _DeleteStatRow extends StatelessWidget {
  const _DeleteStatRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cf.textMuted),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: cf.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
