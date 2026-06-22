import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../trophy_kind_detail_screen.dart';

class ProfileTrophiesTab extends StatelessWidget {
  const ProfileTrophiesTab({super.key, required this.trophies});

  final List<PlayerTrophy> trophies;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final total = trophies.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Text(
            total == 0
                ? 'No match awards yet'
                : '$total career ${total == 1 ? 'award' : 'awards'}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cf.textSecondary,
                ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: AppDimens.listPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
              mainAxisSpacing: AppDimens.spaceSm,
              crossAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 0.85,
            ),
            itemCount: PlayerTrophyKind.profileKinds.length,
            itemBuilder: (_, i) {
              final kind = PlayerTrophyKind.profileKinds[i];
              final earned =
                  trophies.where((t) => t.kind == kind).toList(growable: false);
              return _TrophyKindTile(
                kind: kind,
                count: earned.length,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TrophyKindDetailScreen(
                        kind: kind,
                        trophies: earned,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrophyKindTile extends StatelessWidget {
  const _TrophyKindTile({
    required this.kind,
    required this.count,
    required this.onTap,
  });

  final PlayerTrophyKind kind;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final unlocked = count > 0;
    const tierColor = Color(0xFFD4AF37);

    return Opacity(
      opacity: unlocked ? 1 : 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            decoration: cfCardDecoration(context).copyWith(
              border: Border.all(
                color: unlocked
                    ? tierColor.withValues(alpha: 0.5)
                    : cf.border,
              ),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceSm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(kind.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  kind.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const Spacer(),
                Text(
                  unlocked ? '$count ${count == 1 ? 'time' : 'times'}' : 'Not yet',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: unlocked ? cf.accent : cf.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
