import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the admin panel can permanently delete (server-side cascade).
enum AdminDeleteTarget {
  team('team', 'team'),
  tournament('tournament', 'tournament'),
  organization('series', 'organization'),
  match('match', 'match');

  const AdminDeleteTarget(this.wire, this.label);

  /// Value sent to the `adminDeleteEntity` callable.
  final String wire;
  final String label;

  /// Shown in the confirm dialog so the admin knows exactly what goes.
  List<String> get impact => switch (this) {
        AdminDeleteTarget.team => const [
            'The team, its join requests and invites, followers and pictures.',
            'Players stay on CrickFlow; the team is removed from their profiles.',
            'The team is removed from tournaments that listed it.',
            'Played matches stay in players\' history (career stats unchanged).',
            'The team owner, captain and vice-captain get a notification.',
          ],
        AdminDeleteTarget.tournament => const [
            'The tournament, its groups, rounds, points table, officials, sponsors, '
                'members, team requests, rules, posts and pictures.',
            'Fixtures that never started are deleted.',
            'Started or completed matches are kept as normal matches so '
                'career stats stay correct.',
            'The organizer and tournament admins get a notification.',
          ],
        AdminDeleteTarget.organization => const [
            'The organization with its admins, clubs, registrations, memberships, '
                'approvals, competitions, rankings, announcements, audit log and pictures.',
            'Its tournaments are deleted (started matches are kept).',
            'Org teams become normal teams again (they are not deleted).',
            'The owner, org admins and org team owners get a notification.',
          ],
        AdminDeleteTarget.match => const [
            'The match with its ball-by-ball events, overlay, media and digest.',
            'It is removed from its tournament fixture list.',
            'If it was completed, career stats already counted from it are '
                'NOT reversed.',
            'The match creator gets a notification.',
          ],
      };
}

class AdminDeleteResult {
  const AdminDeleteResult(this.raw);
  final Map<String, dynamic> raw;

  int get notified => (raw['notified'] as List?)?.length ?? 0;
  int get matchesKept => (raw['matchesKept'] as num?)?.toInt() ?? 0;

  String summary(AdminDeleteTarget target) {
    final parts = <String>['${_cap(target.label)} deleted permanently'];
    if (notified > 0) parts.add('$notified notified');
    if (matchesKept > 0) parts.add('$matchesKept played match(es) kept');
    return parts.join(' · ');
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class AdminDeleteService {
  AdminDeleteService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<AdminDeleteResult> deletePermanently({
    required AdminDeleteTarget target,
    required String id,
    String? reason,
  }) async {
    final res = await _functions
        .httpsCallable(
          'adminDeleteEntity',
          options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
        )
        .call<Map<String, dynamic>>({
      'type': target.wire,
      'id': id,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
    return AdminDeleteResult(Map<String, dynamic>.from(res.data));
  }
}

final adminDeleteServiceProvider = Provider<AdminDeleteService>(
  (ref) => AdminDeleteService(),
);
