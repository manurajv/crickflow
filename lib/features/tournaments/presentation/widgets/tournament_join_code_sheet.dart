import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';

class TournamentJoinCodeSheet extends ConsumerStatefulWidget {
  const TournamentJoinCodeSheet({super.key});

  @override
  ConsumerState<TournamentJoinCodeSheet> createState() =>
      _TournamentJoinCodeSheetState();
}

class _TournamentJoinCodeSheetState extends ConsumerState<TournamentJoinCodeSheet> {
  final _controller = TextEditingController();
  var _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tournament =
          await ref.read(tournamentRepositoryProvider).findByCode(code);
      if (!mounted) return;
      if (tournament == null) {
        setState(() {
          _loading = false;
          _error = 'No tournament found for code $code';
        });
        return;
      }
      Navigator.pop(context);
      context.push('/tournaments/${tournament.id}');
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDimens.spaceMd,
        right: AppDimens.spaceMd,
        top: AppDimens.spaceLg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDimens.spaceLg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Join tournament',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            'Enter the tournament code shared by the organizer.',
            style: TextStyle(color: cf.textSecondary),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            decoration: InputDecoration(
              labelText: 'Tournament code',
              hintText: 'ABC2026',
              errorText: _error,
            ),
            onSubmitted: (_) => _lookup(),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          CfButton(
            label: _loading ? 'Looking up…' : 'Find tournament',
            isGold: true,
            isLoading: _loading,
            onPressed: _loading ? null : _lookup,
          ),
        ],
      ),
    );
  }
}
