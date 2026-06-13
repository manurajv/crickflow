import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/scorer_qr_utils.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/scoring_ui_kit.dart';

/// Prompt shown when a user scans a scorer takeover QR / deep link.
class ScorerTakeoverDialog {
  ScorerTakeoverDialog._();

  static Future<void> maybeShow(
    BuildContext context,
    WidgetRef ref,
    ScorerTakeoverPayload payload,
  ) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to take over scoring')),
        );
      }
      return;
    }

    final profile = ref.read(currentUserProfileProvider).valueOrNull;
    final confirmed = await ScoringUiKit.confirmAction(
      context,
      title: 'Take over scoring?',
      message: 'Do you want to take over scoring for this match?',
      confirmLabel: 'Accept',
      cancelLabel: 'Cancel',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(matchRepositoryProvider).acceptScorerTakeover(
            matchId: payload.matchDocumentId,
            newUserId: uid,
            newUserName: profile?.displayName ?? 'Scorer',
            newUserPhoto: profile?.photoUrl,
            ownershipToken: payload.ownershipToken,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now the active scorer')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Takeover failed: $e')),
        );
      }
    }
  }
}
