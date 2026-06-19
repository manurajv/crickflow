import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/team_model.dart';
import 'cf_team_id_format.dart';
import 'deep_link_utils.dart';

/// Team invite link text and share helpers for WhatsApp / system share sheet.
class TeamInviteUtils {
  TeamInviteUtils._();

  static String inviteLink(TeamModel team) {
    final base = DeepLinkUtils.httpsTeamUri(team.id);
    if (team.teamCode == null || team.teamCode!.isEmpty) {
      return base.toString();
    }
    return base
        .replace(
          queryParameters: {
            'code': CfTeamIdFormat.normalize(team.teamCode!),
          },
        )
        .toString();
  }

  static String shareMessage(TeamModel team) {
    final link = inviteLink(team);
    final codeLine = team.teamCode != null && team.teamCode!.isNotEmpty
        ? 'Team ID: ${CfTeamIdFormat.displayLabel(team.teamCode)}\n'
        : '';
    return 'You\'re invited to join *${team.name}* on CrickFlow!\n'
        '$codeLine'
        'Tap the link to open the team in the app:\n'
        '$link';
  }

  static Future<void> copyLink(TeamModel team) async {
    await Clipboard.setData(ClipboardData(text: inviteLink(team)));
  }

  static Future<void> shareLink(TeamModel team) async {
    await Share.share(
      shareMessage(team),
      subject: 'Join ${team.name} on CrickFlow',
    );
  }

  /// Opens WhatsApp with the same invite text pre-filled so the user can pick
  /// a contact and send without pasting.
  static Future<void> shareWhatsApp(TeamModel team) async {
    final message = shareMessage(team);
    final encoded = Uri.encodeComponent(message);

    final targets = [
      Uri.parse('whatsapp://send?text=$encoded'),
      Uri.parse('https://api.whatsapp.com/send?text=$encoded'),
      Uri.parse('https://wa.me/?text=$encoded'),
    ];

    for (final uri in targets) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return;
      } catch (_) {
        // Try next scheme / host.
      }
    }

    await shareLink(team);
  }
}
