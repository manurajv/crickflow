import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/scorer_qr_utils.dart';
import '../../../shared/providers/providers.dart';
import 'widgets/scorer_takeover_dialog.dart';
import '../../../core/theme/cf_colors.dart';

/// Entry point when a user scans a scorer takeover QR code.
class ScorerTakeoverScreen extends ConsumerStatefulWidget {
  const ScorerTakeoverScreen({
    super.key,
    required this.matchId,
    required this.ownershipToken,
  });

  final String matchId;
  final String ownershipToken;

  @override
  ConsumerState<ScorerTakeoverScreen> createState() =>
      _ScorerTakeoverScreenState();
}

class _ScorerTakeoverScreenState extends ConsumerState<ScorerTakeoverScreen> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runTakeover());
  }

  Future<void> _runTakeover() async {
    if (_handled || !mounted) return;
    _handled = true;

    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to take over scoring')),
        );
        context.go('/login');
      }
      return;
    }

    if (widget.ownershipToken.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid QR code')),
        );
        context.go('/match/${widget.matchId}');
      }
      return;
    }

    await ScorerTakeoverDialog.maybeShow(
      context,
      ref,
      ScorerTakeoverPayload(
        matchDocumentId: widget.matchId,
        ownershipToken: widget.ownershipToken,
      ),
    );

    if (mounted) {
      context.go('/match/${widget.matchId}/score');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Scaffold(
      backgroundColor: cf.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}
