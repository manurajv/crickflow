import 'package:share_plus/share_plus.dart';

import 'deep_link_utils.dart';

/// Opens the platform share sheet for a match scorecard link.
Future<void> shareMatchLink({
  required String matchId,
  String? title,
}) async {
  final url = DeepLinkUtils.publicLiveScorecardUri(matchId).toString();
  final headline = title?.trim();
  final text = headline != null && headline.isNotEmpty
      ? '$headline — CrickFlow\n$url'
      : 'Follow this match on CrickFlow\n$url';
  await Share.share(text, subject: headline ?? 'CrickFlow match');
}

/// Share current live score with a deep link.
Future<void> shareLiveScore({
  required String matchId,
  required String title,
  required String scoreLine,
}) async {
  final url = DeepLinkUtils.publicLiveScorecardUri(matchId).toString();
  final headline = title.trim();
  final text = headline.isNotEmpty
      ? '$headline\n$scoreLine\n$url'
      : '$scoreLine\n$url';
  await Share.share(text, subject: headline.isNotEmpty ? headline : 'Live score');
}
