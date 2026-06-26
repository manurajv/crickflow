import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/match_player_snapshot.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../shared/providers/match_squads_provider.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/widgets/match_team_avatar.dart';
import '../../../../shared/widgets/player_cluster_text.dart';

class MatchSquadsTab extends ConsumerWidget {
  const MatchSquadsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final squadsAsync = ref.watch(matchDualSquadsProvider(matchId));

    return squadsAsync.when(
      data: (squads) {
        if (!squads.hasData) {
          return Center(
            child: Padding(
              padding: AppDimens.listPadding,
              child: Text(
                'Squads will appear once selected during match setup.',
                textAlign: TextAlign.center,
                style: TextStyle(color: cf.textSecondary),
              ),
            ),
          );
        }

        final showSubstitutes =
            squads.teamA.hasSubstitutes || squads.teamB.hasSubstitutes;
        final showRestOfTeam =
            squads.teamA.hasRestOfTeam || squads.teamB.hasRestOfTeam;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceLg,
          ),
          children: [
            _TeamHeaderRow(
              teamA: squads.teamA,
              teamB: squads.teamB,
              cf: cf,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _SectionLabel(title: 'PLAYING SQUAD', cf: cf),
            const SizedBox(height: AppDimens.spaceSm),
            _DualSquadRows(
              left: squads.teamA,
              right: squads.teamB,
              playersA: squads.teamA.playing,
              playersB: squads.teamB.playing,
              cf: cf,
            ),
            if (showSubstitutes) ...[
              const SizedBox(height: AppDimens.spaceLg),
              _SectionLabel(title: 'SUBSTITUTES', cf: cf),
              const SizedBox(height: AppDimens.spaceSm),
              _DualSquadRows(
                left: squads.teamA,
                right: squads.teamB,
                playersA: squads.teamA.substitutes,
                playersB: squads.teamB.substitutes,
                cf: cf,
              ),
            ],
            if (showRestOfTeam) ...[
              const SizedBox(height: AppDimens.spaceLg),
              _SectionLabel(title: 'REST OF TEAM', cf: cf),
              const SizedBox(height: AppDimens.spaceSm),
              _DualSquadRows(
                left: squads.teamA,
                right: squads.teamB,
                playersA: squads.teamA.restOfTeam,
                playersB: squads.teamB.restOfTeam,
                cf: cf,
              ),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }
}

class _TeamHeaderRow extends StatelessWidget {
  const _TeamHeaderRow({
    required this.teamA,
    required this.teamB,
    required this.cf,
  });

  final MatchSquadSide teamA;
  final MatchSquadSide teamB;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _TeamHeader(side: teamA, alignEnd: false, cf: cf)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'vs',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cf.textSecondary,
            ),
          ),
        ),
        Expanded(child: _TeamHeader(side: teamB, alignEnd: true, cf: cf)),
      ],
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({
    required this.side,
    required this.alignEnd,
    required this.cf,
  });

  final MatchSquadSide side;
  final bool alignEnd;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final avatar = MatchTeamAvatar(
      name: side.teamName,
      logoUrl: side.teamLogoUrl,
      size: 28,
    );
    final label = Text(
      side.teamName,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: cf.textPrimary,
        height: 1.2,
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment:
          alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: label), const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), Flexible(child: label)],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.cf});

  final String title;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: cf.textSecondary,
        ),
      ),
    );
  }
}

class _DualSquadRows extends StatelessWidget {
  const _DualSquadRows({
    required this.left,
    required this.right,
    required this.playersA,
    required this.playersB,
    required this.cf,
  });

  final MatchSquadSide left;
  final MatchSquadSide right;
  final List<MatchPlayerSnapshot> playersA;
  final List<MatchPlayerSnapshot> playersB;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final rowCount = playersA.length > playersB.length
        ? playersA.length
        : playersB.length;

    return Column(
      children: List.generate(rowCount, (index) {
        final a = index < playersA.length ? playersA[index] : null;
        final b = index < playersB.length ? playersB[index] : null;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: a == null
                    ? const SizedBox.shrink()
                    : _PlayerRow(
                        player: a,
                        side: left,
                        alignEnd: false,
                        cf: cf,
                      ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: cf.border,
              ),
              Expanded(
                child: b == null
                    ? const SizedBox.shrink()
                    : _PlayerRow(
                        player: b,
                        side: right,
                        alignEnd: true,
                        cf: cf,
                      ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PlayerRow extends ConsumerWidget {
  const _PlayerRow({
    required this.player,
    required this.side,
    required this.alignEnd,
    required this.cf,
  });

  final MatchPlayerSnapshot player;
  final MatchSquadSide side;
  final bool alignEnd;
  final CfColors cf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCaptain = side.captainId == player.id;
    final isViceCaptain = side.viceCaptainId == player.id;
    final isWicketKeeper = side.wicketKeeperId == player.id;
    final clustersAsync = ref.watch(playerCricketProfileByIdProvider(player.id));

    final avatar = _SquadPlayerAvatar(
      player: player,
      isCaptain: isCaptain,
      isViceCaptain: isViceCaptain,
      isWicketKeeper: isWicketKeeper,
      cf: cf,
    );

    final text = Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            player.name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: cf.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          ),
          if (player.playingRole.isNotEmpty)
            Text(
              player.playingRole,
              style: TextStyle(fontSize: 11, color: cf.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            ),
          clustersAsync.when(
            data: (_) => PlayerClusterText(
              clusters:
                  clustersAsync.valueOrNull?.clusters ?? const PlayerClusters(),
              showNewPlayerForMissing: true,
              fontSize: 8,
              separatorColor: cf.textMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => PlayerClusterText(
              clusters: const PlayerClusters(),
              showNewPlayerForMissing: true,
              fontSize: 8,
              separatorColor: cf.textMuted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: alignEnd
            ? [text, const SizedBox(width: 8), avatar]
            : [avatar, const SizedBox(width: 8), text],
      ),
    );
  }
}

class _SquadPlayerAvatar extends StatelessWidget {
  const _SquadPlayerAvatar({
    required this.player,
    required this.isCaptain,
    required this.isViceCaptain,
    required this.isWicketKeeper,
    required this.cf,
  });

  final MatchPlayerSnapshot player;
  final bool isCaptain;
  final bool isViceCaptain;
  final bool isWicketKeeper;
  final CfColors cf;

  static const double _radius = 18;

  @override
  Widget build(BuildContext context) {
    const size = _radius * 2;
    final cornerBadges = _cornerBadges();

    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: _radius,
            backgroundColor: CfColors.primaryBlue,
            backgroundImage:
                player.photoUrl != null && player.photoUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(player.photoUrl!)
                    : null,
            child: player.photoUrl == null || player.photoUrl!.isEmpty
                ? Text(
                    _initials(player.name),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          if (cornerBadges.isNotEmpty)
            Positioned(
              right: -2,
              bottom: -2,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < cornerBadges.length; i++)
                    Padding(
                      padding: EdgeInsets.only(left: i == 0 ? 0 : 2),
                      child: cornerBadges[i],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _cornerBadges() {
    final badges = <Widget>[];
    if (isWicketKeeper && (isCaptain || isViceCaptain)) {
      badges.add(
        const _CircleBadge(
          label: 'WK',
          color: CfColors.primaryBlue,
          compact: true,
        ),
      );
    }
    if (isViceCaptain && !isCaptain) {
      badges.add(
        const _CircleBadge(
          label: 'VC',
          color: CfColors.primaryBlue,
          compact: true,
        ),
      );
    }
    if (isCaptain) {
      badges.add(
        const _CircleBadge(label: 'C', color: CfColors.primaryBlue),
      );
    }
    if (isWicketKeeper && !isCaptain && !isViceCaptain) {
      badges.add(
        const _CircleBadge(
          label: 'WK',
          color: CfColors.primaryBlue,
          compact: true,
        ),
      );
    }
    return badges;
  }

  static String _initials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      return words[0].substring(0, words[0].length.clamp(0, 1)).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }
}

class _CircleBadge extends StatelessWidget {
  const _CircleBadge({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final size = compact ? 16.0 : 14.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: cf.surfaceElevated, width: 1.5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 7 : 8,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
