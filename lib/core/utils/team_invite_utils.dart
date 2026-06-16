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

  static String whatsAppMessage(TeamModel team) {
    // WhatsApp supports *bold* in plain text; avoid markdown elsewhere.
    return shareMessage(team);
  }

  static Future<void> copyLink(TeamModel team) async {
    await Clipboard.setData(ClipboardData(text: inviteLink(team)));
  }

  static Future<void> shareLink(TeamModel team) async {
    await Share.share(shareMessage(team), subject: 'Join ${team.name} on CrickFlow');
  }

  static Future<void> shareWhatsApp(TeamModel team) async {
    final text = Uri.encodeComponent(whatsAppMessage(team));
    final uri = Uri.parse('https://wa.me/?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await shareLink(team);
    }
  }
}
