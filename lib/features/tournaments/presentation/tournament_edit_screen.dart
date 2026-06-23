import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/cf_button.dart';

class TournamentEditScreen extends ConsumerStatefulWidget {
  const TournamentEditScreen({super.key, required this.tournamentId});

  final String tournamentId;

  @override
  ConsumerState<TournamentEditScreen> createState() =>
      _TournamentEditScreenState();
}

class _TournamentEditScreenState extends ConsumerState<TournamentEditScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  var _loaded = false;
  var _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(TournamentModel tournament) async {
    setState(() => _saving = true);
    try {
      await ref.read(tournamentRepositoryProvider).updateTournament(
            tournament.copyWith(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
            ),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tournamentAsync = ref.watch(tournamentProvider(widget.tournamentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit tournament')),
      body: tournamentAsync.when(
        data: (tournament) {
          if (tournament == null) {
            return const Center(child: Text('Tournament not found'));
          }
          if (!_loaded) {
            _nameController.text = tournament.name;
            _descriptionController.text = tournament.description;
            _loaded = true;
          }
          return ListView(
            padding: AppDimens.screenPadding,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              CfButton(
                label: 'Save changes',
                isGold: true,
                isLoading: _saving,
                onPressed: _saving ? null : () => _save(tournament),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
