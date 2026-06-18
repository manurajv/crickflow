import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../data/repositories/scoring_issue_report_repository.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/cf_button.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

class FacingProblemSheet extends ConsumerStatefulWidget {
  const FacingProblemSheet({super.key, required this.matchId});

  final String matchId;

  static Future<void> show(BuildContext context, {required String matchId}) {
    return ScoringUiKit.showSheet<void>(
      context,
      isScrollControlled: true,
      builder: (_) => FacingProblemSheet(matchId: matchId),
    );
  }

  @override
  ConsumerState<FacingProblemSheet> createState() => _FacingProblemSheetState();
}

class _FacingProblemSheetState extends ConsumerState<FacingProblemSheet> {
  String _issueType = 'app';
  final _descriptionCtrl = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = ref.read(authStateProvider).value?.uid;
    if (uid == null) return;
    setState(() => _submitting = true);
    try {
      await ScoringIssueReportRepository().submitReport(
        matchId: widget.matchId,
        reportedBy: uid,
        issueType: _issueType,
        description: _descriptionCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppDimens.spaceMd,
          right: AppDimens.spaceMd,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppDimens.spaceMd,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScoringSheetHeader(title: 'Facing Problem'),
            DropdownButtonFormField<String>(
              value: _issueType,
              decoration: const InputDecoration(labelText: 'Issue type'),
              items: const [
                DropdownMenuItem(value: 'app', child: Text('App issue')),
                DropdownMenuItem(
                  value: 'scoring',
                  child: Text('Scoring issue'),
                ),
                DropdownMenuItem(
                  value: 'internet',
                  child: Text('Internet issue'),
                ),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _issueType = v);
              },
            ),
            const SizedBox(height: AppDimens.spaceSm),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'What went wrong?',
              ),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            CfButton(
              label: _submitting ? 'Submitting…' : 'Submit Report',
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
