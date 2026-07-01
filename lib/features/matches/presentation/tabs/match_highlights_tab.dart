import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../widgets/match_highlights_list.dart';

class MatchHighlightsTab extends ConsumerWidget {
  const MatchHighlightsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MatchHighlightsList(
      matchId: matchId,
      padding: AppDimens.listPadding,
    );
  }
}
