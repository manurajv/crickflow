import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../data/models/tournament_model.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/providers/tournament_providers.dart';
import '../../../shared/widgets/cf_button.dart';
import '../../../shared/widgets/cf_underlined_field.dart';
import 'widgets/tournament_create/tournament_media_picker.dart';

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
  File? _bannerFile;
  File? _logoFile;
  String? _bannerUrl;
  String? _logoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(TournamentModel tournament) async {
    setState(() => _saving = true);
    try {
      var bannerUrl = _bannerUrl;
      var logoUrl = _logoUrl;
      final storage = ref.read(storageServiceProvider);

      if (_bannerFile != null) {
        bannerUrl = await storage.uploadTournamentBanner(
          tournament.id,
          _bannerFile!,
        );
      }
      if (_logoFile != null) {
        logoUrl = await storage.uploadTournamentLogo(
          tournament.id,
          _logoFile!,
        );
      }

      await ref.read(tournamentRepositoryProvider).updateTournament(
            tournament.copyWith(
              name: tournament.isLocked
                  ? tournament.name
                  : _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              bannerUrl: bannerUrl,
              logoUrl: logoUrl,
            ),
          );
      ref.invalidate(tournamentProvider(widget.tournamentId));
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
    final cf = context.cf;
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
            _bannerUrl = tournament.bannerUrl;
            _logoUrl = tournament.logoUrl;
            _loaded = true;
          }

          return ListView(
            padding: AppDimens.screenPadding,
            children: [
              Text(
                'Branding',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              TournamentMediaPicker(
                bannerFile: _bannerFile,
                logoFile: _logoFile,
                existingBannerUrl: _bannerUrl,
                existingLogoUrl: _logoUrl,
                onBannerPicked: (file) => setState(() => _bannerFile = file),
                onLogoPicked: (file) => setState(() => _logoFile = file),
              ),
              const SizedBox(height: 52),
              Text(
                'Details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              CfUnderlinedField(
                controller: _nameController,
                label: 'Tournament name',
                required: true,
                readOnly: tournament.isLocked,
              ),
              const SizedBox(height: AppDimens.fieldSpacing),
              CfUnderlinedField(
                controller: _descriptionController,
                label: 'Description',
                maxLines: 4,
              ),
              if (tournament.isLocked) ...[
                const SizedBox(height: AppDimens.spaceMd),
                Container(
                  padding: const EdgeInsets.all(AppDimens.spaceSm),
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, size: 18, color: cf.accent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This tournament is locked after completion. '
                          'Only branding and description can be updated.',
                          style: TextStyle(color: cf.textSecondary, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
