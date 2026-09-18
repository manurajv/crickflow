import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../data/models/series/series.dart';
import '../../../shared/providers/series_providers.dart';
import '../../../shared/widgets/cf_chrome_app_bar.dart';

class SeriesProposeMatchScreen extends ConsumerStatefulWidget {
  const SeriesProposeMatchScreen({
    super.key,
    required this.seriesId,
    this.clubId,
  });

  final String seriesId;
  final String? clubId;

  @override
  ConsumerState<SeriesProposeMatchScreen> createState() =>
      _SeriesProposeMatchScreenState();
}

class _SeriesProposeMatchScreenState
    extends ConsumerState<SeriesProposeMatchScreen> {
  final _title = TextEditingController();
  String? _clubAId;
  String? _clubBId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clubAId = widget.clubId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _submit(List<SeriesClubModel> clubs) async {
    if (_clubAId == null || _clubBId == null || _clubAId == _clubBId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select two different clubs')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final aName = clubs.firstWhere((c) => c.id == _clubAId).name;
      final bName = clubs.firstWhere((c) => c.id == _clubBId).name;
      final result =
          await ref.read(seriesFunctionsServiceProvider).proposeSeriesMatch({
            'seriesId': widget.seriesId,
            'clubAId': _clubAId,
            'clubBId': _clubBId,
            'title': _title.text.trim().isEmpty
                ? '$aName vs $bName'
                : _title.text.trim(),
            'createMatchDraft': true,
          });
      if (!mounted) return;
      final matchId = result['matchId']?.toString();
      final auto = result['autoApproved'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auto
                ? (matchId != null && matchId.isNotEmpty
                    ? 'Official fixture created'
                    : 'Match approved and added to fixtures')
                : (matchId != null && matchId.isNotEmpty
                    ? 'Draft match created · pending approval'
                    : 'Match submitted for approval'),
          ),
        ),
      );
      if (matchId != null && matchId.isNotEmpty) {
        context.push('/match/$matchId');
      } else {
        context.pop();
      }
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
    final clubsAsync = ref.watch(clubsForSeriesProvider(widget.seriesId));
    return Scaffold(
      appBar: const CfChromeAppBar(title: Text('Propose Series match')),
      body: clubsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (clubs) {
          final approved =
              clubs.where((c) => c.status == SeriesClubStatus.approved).toList();
          if (approved.length < 2) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(AppDimens.spaceLg),
                child: Text(
                  'Need at least two approved clubs to propose a match.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            children: [
              TextFormField(
                controller: _title,
                decoration: const InputDecoration(
                  labelText: 'Match title (optional)',
                ),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _clubAId,
                decoration: const InputDecoration(labelText: 'Club A'),
                items: approved
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _clubAId = v),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _clubBId,
                decoration: const InputDecoration(labelText: 'Club B'),
                items: approved
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _clubBId = v),
              ),
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton.icon(
                onPressed: _saving ? null : () => _submit(approved),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(
                  _saving ? 'Submitting…' : 'Submit for Super Admin approval',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
