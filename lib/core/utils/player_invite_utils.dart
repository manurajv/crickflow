import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/register_player_models.dart';
import 'deep_link_utils.dart';

class PlayerInviteUtils {
  PlayerInviteUtils._();

  static String publicUrl(String inviteId) =>
      DeepLinkUtils.playerInviteUri(inviteId).toString();

  static String shareMessage({
    required String url,
    String? playerName,
    String? registrarName,
    bool phoneTarget = false,
  }) {
    final who = (playerName != null && playerName.trim().isNotEmpty)
        ? playerName.trim()
        : 'you';
    final from = (registrarName != null && registrarName.trim().isNotEmpty)
        ? ' ${registrarName.trim()} invited'
        : ' You\'re invited';
    final how = phoneTarget
        ? 'Open the link and join with Google or your mobile number'
        : 'Open the link and join with Google (or phone)';
    return '$from $who to join CrickFlow.\n'
        '$how:\n'
        '$url';
  }

  static Future<void> copyLink(PlayerInviteCreated invite) async {
    await Clipboard.setData(ClipboardData(text: invite.url));
  }

  static Future<void> shareLink(
    PlayerInviteCreated invite, {
    String? playerName,
    String? registrarName,
  }) async {
    await Share.share(
      shareMessage(
        url: invite.url,
        playerName: playerName,
        registrarName: registrarName,
        phoneTarget: invite.inviteType != PlayerInviteType.google,
      ),
      subject: 'Join CrickFlow',
    );
  }

  static Future<void> shareWhatsApp(
    PlayerInviteCreated invite, {
    String? playerName,
    String? registrarName,
  }) async {
    final message = shareMessage(
      url: invite.url,
      playerName: playerName,
      registrarName: registrarName,
      phoneTarget: invite.inviteType != PlayerInviteType.google,
    );
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
      } catch (_) {}
    }
    await shareLink(
      invite,
      playerName: playerName,
      registrarName: registrarName,
    );
  }

  static String maskPhone(String e164) {
    final digits = e164.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 6) return e164;
    final last = digits.substring(digits.length - 4);
    return '${e164.startsWith('+') ? '+' : ''}••••$last';
  }
}
