import 'package:flutter_test/flutter_test.dart';

import 'package:crickflow/core/utils/team_leadership_utils.dart';
import 'package:crickflow/data/models/player_model.dart';
import 'package:crickflow/data/models/team_model.dart';

void main() {
  group('TeamLeadershipUtils.pickNextOwner', () {
    const teamId = 'team1';

    TeamModel team({String? captainId, String? viceCaptainId}) => TeamModel(
          id: teamId,
          name: 'Star Strikers',
          captainId: captainId,
          viceCaptainId: viceCaptainId,
          createdBy: 'owner',
        );

    PlayerModel player(
      String id, {
      DateTime? joined,
    }) =>
        PlayerModel(
          id: id,
          name: id,
          teamJoinedAt: joined,
        );

    test('selects earliest joined member regardless of captain or vc', () {
      final squad = [
        player('newest', joined: DateTime(2024)),
        player('oldest', joined: DateTime(2019)),
        player('vc', joined: DateTime(2023)),
        player('cap', joined: DateTime(2022)),
      ];
      final next = TeamLeadershipUtils.pickNextOwner(
        team(captainId: 'cap', viceCaptainId: 'vc'),
        squad,
      );
      expect(next?.id, 'oldest');
    });

    test('returns null when no other members', () {
      expect(TeamLeadershipUtils.pickNextOwner(team(), []), isNull);
    });
  });

  group('TeamLeadershipUtils.canRemoveMember', () {
    const teamId = 'team1';
    final t = TeamModel(
      id: teamId,
      name: 'Team',
      createdBy: 'owner',
      captainId: 'captain',
      viceCaptainId: 'vc',
    );

    PlayerModel p(String id) => PlayerModel(id: id, name: id);

    test('owner can remove normal member', () {
      expect(
        TeamLeadershipUtils.canRemoveMember(
          actorUid: 'owner',
          team: t,
          target: p('member'),
        ),
        isTrue,
      );
    });

    test('captain cannot remove vice captain', () {
      expect(
        TeamLeadershipUtils.canRemoveMember(
          actorUid: 'captain',
          team: t,
          target: p('vc'),
        ),
        isFalse,
      );
    });

    test('vice captain cannot remove captain', () {
      expect(
        TeamLeadershipUtils.canRemoveMember(
          actorUid: 'vc',
          team: t,
          target: p('captain'),
        ),
        isFalse,
      );
    });
  });
}
