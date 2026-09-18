import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

/// Links an existing CrickFlow tournament into the Series for approval.
class SeriesProposeTournamentScreen extends ConsumerStatefulWidget {
  const SeriesProposeTournamentScreen({
    super.key,
    required this.seriesId,
    this.clubId,
  });

  final String seriesId;
  final String? clubId;

  @override
  ConsumerState<SeriesProposeTournamentScreen> createState() =>
      _SeriesProposeTournamentScreenState();
}

class _SeriesProposeTournamentScreenState
    extends ConsumerState<SeriesProposeTournamentScreen> {
  final _tournamentId = TextEditingController();
  final _title = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tournamentId.dispose();
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tid = _tournamentId.text.trim();
    if (tid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a tournament ID')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = await ref
          .read(seriesFunctionsServiceProvider)
          .proposeSeriesTournament({
        'seriesId': widget.seriesId,
        'tournamentId': tid,
        'title': _title.text.trim(),
        if (widget.clubId != null) 'clubId': widget.clubId,
      });
      if (!mounted) return;
      final auto = result['autoApproved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? 'Tournament linked as an official fixture'
                : 'Tournament submitted for approval',
          ),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not propose: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myTournaments = ref.watch(myOrganizedTournamentsProvider);

    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Propose Series tournament')),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.spaceLg),
        children: [
          const Text(
            'Link an existing CrickFlow tournament. It stays a normal '
            'tournament; Series approval makes it official for Series rankings.',
          ),
          const SizedBox(height: AppDimens.spaceLg),
          TextFormField(
            controller: _tournamentId,
            decoration: const InputDecoration(
              labelText: 'Tournament ID',
              prefixIcon: Icon(Icons.tag),
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Display title (optional)',
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          myTournaments.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (items) {
              if (items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your tournaments',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  ...items.take(12).map(
                        (t) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(t.name),
                          subtitle: Text(t.id),
                          trailing: TextButton(
                            onPressed: () {
                              _tournamentId.text = t.id;
                              if (_title.text.isEmpty) {
                                _title.text = t.name;
                              }
                              setState(() {});
                            },
                            child: const Text('Use'),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
          const SizedBox(height: AppDimens.spaceLg),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              _saving ? 'Submitting…' : 'Submit for approval',
            ),
          ),
        ],
      ),
    );
  }
}
