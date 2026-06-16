import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../core/theme/app_colors.dart';

import '../../../../core/theme/app_dimens.dart';

import '../../../../core/utils/cf_player_id_format.dart';

import '../../../../data/models/team_join_request_model.dart';

import '../../../../data/models/team_model.dart';

import '../../../../shared/providers/providers.dart';

import '../../../../shared/providers/team_join_request_provider.dart';

import '../../../../shared/providers/team_players_provider.dart';



/// Leadership panel to accept or reject pending join requests.

class TeamJoinRequestsPanel extends ConsumerWidget {

  const TeamJoinRequestsPanel({

    super.key,

    required this.team,

    required this.resolverUid,

  });



  final TeamModel team;

  final String resolverUid;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final requestsAsync = ref.watch(teamPendingJoinRequestsProvider(team.id));



    return requestsAsync.when(

      data: (requests) {

        if (requests.isEmpty) {

          return const SizedBox.shrink();

        }



        return Padding(

          padding: const EdgeInsets.fromLTRB(

            AppDimens.spaceMd,

            AppDimens.spaceSm,

            AppDimens.spaceMd,

            AppDimens.spaceMd,

          ),

          child: DecoratedBox(

            decoration: BoxDecoration(

              color: AppColors.surfaceElevated,

              borderRadius: BorderRadius.circular(8),

              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),

            ),

            child: Padding(

              padding: const EdgeInsets.all(AppDimens.spaceMd),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [

                  Row(

                    children: [

                      const Icon(Icons.group_add, color: AppColors.gold, size: 20),

                      const SizedBox(width: 8),

                      Expanded(

                        child: Text(

                          'Join requests',

                          style: Theme.of(context).textTheme.titleSmall?.copyWith(

                                fontWeight: FontWeight.w700,

                              ),

                        ),

                      ),

                      _CountBadge(count: requests.length),

                    ],

                  ),

                  const SizedBox(height: AppDimens.spaceSm),

                  ...requests.map(

                    (r) => _JoinRequestRow(

                      team: team,

                      request: r,

                      resolverUid: resolverUid,

                    ),

                  ),

                ],

              ),

            ),

          ),

        );

      },

      loading: () => const Padding(

        padding: EdgeInsets.all(AppDimens.spaceMd),

        child: Center(

          child: SizedBox(

            width: 24,

            height: 24,

            child: CircularProgressIndicator(strokeWidth: 2),

          ),

        ),

      ),

      error: (e, _) => Padding(

        padding: const EdgeInsets.all(AppDimens.spaceMd),

        child: Text(

          'Could not load join requests: $e',

          style: const TextStyle(color: AppColors.accentRed, fontSize: 13),

        ),

      ),

    );

  }

}



class _CountBadge extends StatelessWidget {

  const _CountBadge({required this.count});



  final int count;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),

      decoration: BoxDecoration(

        color: AppColors.accentRed,

        borderRadius: BorderRadius.circular(999),

      ),

      child: Text(

        '$count',

        style: const TextStyle(

          color: Colors.white,

          fontWeight: FontWeight.w700,

          fontSize: 12,

        ),

      ),

    );

  }

}



class _JoinRequestRow extends ConsumerStatefulWidget {

  const _JoinRequestRow({

    required this.team,

    required this.request,

    required this.resolverUid,

  });



  final TeamModel team;

  final TeamJoinRequestModel request;

  final String resolverUid;



  @override

  ConsumerState<_JoinRequestRow> createState() => _JoinRequestRowState();

}



class _JoinRequestRowState extends ConsumerState<_JoinRequestRow> {

  var _busy = false;



  Future<void> _accept() => _resolve(accept: true);



  Future<void> _reject() => _resolve(accept: false);



  Future<void> _resolve({required bool accept}) async {

    setState(() => _busy = true);

    try {

      final repo = ref.read(teamJoinRequestRepositoryProvider);

      if (accept) {

        await repo.acceptRequest(

          team: widget.team,

          request: widget.request,

          resolverUid: widget.resolverUid,

        );

      } else {

        await repo.rejectRequest(

          team: widget.team,

          request: widget.request,

          resolverUid: widget.resolverUid,

        );

      }

      ref.invalidate(teamPendingJoinRequestsProvider(widget.team.id));

      ref.invalidate(teamPlayersProvider(widget.team.id));

      ref.invalidate(allTeamsProvider);

      ref.invalidate(

        userTeamJoinRequestProvider((

          teamId: widget.team.id,

          userId: widget.request.userId,

        )),

      );

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(

            content: Text(

              accept

                  ? '${widget.request.displayName} added to squad'

                  : 'Join request declined',

            ),

          ),

        );

      }

    } catch (e) {

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text('Could not update request: $e')),

        );

      }

    } finally {

      if (mounted) setState(() => _busy = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final request = widget.request;

    final playerId = request.cfPlayerId;

    final idLabel = playerId != null && playerId.isNotEmpty

        ? CfPlayerIdFormat.displayLabel(playerId)

        : null;



    return Container(

      margin: const EdgeInsets.only(top: 8),

      padding: const EdgeInsets.all(AppDimens.spaceSm),

      decoration: BoxDecoration(

        color: AppColors.surface,

        borderRadius: BorderRadius.circular(6),

        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),

      ),

      child: Row(

        children: [

          CircleAvatar(

            radius: 22,

            backgroundColor: AppColors.primaryBlue,

            backgroundImage: request.playerPhotoUrl != null

                ? CachedNetworkImageProvider(request.playerPhotoUrl!)

                : null,

            child: request.playerPhotoUrl == null

                ? Text(

                    request.displayName.isNotEmpty

                        ? request.displayName[0].toUpperCase()

                        : '?',

                    style: const TextStyle(

                      color: Colors.white,

                      fontWeight: FontWeight.w700,

                    ),

                  )

                : null,

          ),

          const SizedBox(width: AppDimens.spaceSm),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  request.displayName,

                  maxLines: 1,

                  overflow: TextOverflow.ellipsis,

                  style: theme.textTheme.titleSmall?.copyWith(

                    fontWeight: FontWeight.w600,

                  ),

                ),

                if (idLabel != null)

                  Text(

                    idLabel,

                    style: theme.textTheme.bodySmall?.copyWith(

                      color: AppColors.textSecondary,

                    ),

                  ),

              ],

            ),

          ),

          if (_busy)

            const Padding(

              padding: EdgeInsets.all(8),

              child: SizedBox(

                width: 20,

                height: 20,

                child: CircularProgressIndicator(strokeWidth: 2),

              ),

            )

          else ...[

            FilledButton.tonal(

              onPressed: _accept,

              style: FilledButton.styleFrom(

                backgroundColor: Colors.green.withValues(alpha: 0.15),

                foregroundColor: Colors.green,

                padding: const EdgeInsets.symmetric(horizontal: 12),

              ),

              child: const Text('Approve'),

            ),

            const SizedBox(width: 6),

            OutlinedButton(

              onPressed: _reject,

              style: OutlinedButton.styleFrom(

                foregroundColor: AppColors.accentRed,

                side: BorderSide(color: AppColors.accentRed.withValues(alpha: 0.6)),

                padding: const EdgeInsets.symmetric(horizontal: 12),

              ),

              child: const Text('Reject'),

            ),

          ],

        ],

      ),

    );

  }

}


