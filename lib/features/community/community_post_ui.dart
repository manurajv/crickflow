import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';

String communityCategoryLabel(CommunityPostCategory category) {
  return switch (category) {
    CommunityPostCategory.lookingForPlayer => 'Players wanted',
    CommunityPostCategory.lookingForScorer => 'Scorer wanted',
    CommunityPostCategory.lookingForUmpire => 'Umpire wanted',
    CommunityPostCategory.lookingForStreamer => 'Streamer wanted',
    CommunityPostCategory.lookingForCommentator => 'Commentator wanted',
    CommunityPostCategory.practiceMatch => 'Practice match',
    CommunityPostCategory.groundAvailable => 'Ground available',
    CommunityPostCategory.tournamentNeed => 'Tournament',
    CommunityPostCategory.general => 'General',
    CommunityPostCategory.team => 'Team',
    CommunityPostCategory.achievement => 'Achievement',
    CommunityPostCategory.match => 'Match',
  };
}

IconData communityCategoryIcon(CommunityPostCategory category) {
  return switch (category) {
    CommunityPostCategory.lookingForPlayer => Icons.person_search_outlined,
    CommunityPostCategory.lookingForScorer => Icons.scoreboard_outlined,
    CommunityPostCategory.lookingForUmpire => Icons.sports,
    CommunityPostCategory.lookingForStreamer => Icons.videocam_outlined,
    CommunityPostCategory.lookingForCommentator => Icons.mic_outlined,
    CommunityPostCategory.practiceMatch => Icons.sports_cricket,
    CommunityPostCategory.groundAvailable => Icons.stadium_outlined,
    CommunityPostCategory.tournamentNeed => Icons.emoji_events_outlined,
    CommunityPostCategory.general => Icons.campaign_outlined,
    CommunityPostCategory.team => Icons.groups_outlined,
    CommunityPostCategory.achievement => Icons.military_tech_outlined,
    CommunityPostCategory.match => Icons.sports_cricket_outlined,
  };
}

String communityPostKindLabel(CommunityPostKind kind) {
  return switch (kind) {
    CommunityPostKind.general => 'General',
    CommunityPostKind.tournament => 'Tournament',
    CommunityPostKind.team => 'Team',
    CommunityPostKind.achievement => 'Achievement',
    CommunityPostKind.match => 'Match',
    CommunityPostKind.image => 'Photo',
    CommunityPostKind.video => 'Video',
  };
}

CommunityPostCategory categoryFromPostKind(CommunityPostKind kind) {
  return switch (kind) {
    CommunityPostKind.tournament => CommunityPostCategory.tournamentNeed,
    CommunityPostKind.team => CommunityPostCategory.team,
    CommunityPostKind.achievement => CommunityPostCategory.achievement,
    CommunityPostKind.match => CommunityPostCategory.match,
    CommunityPostKind.image ||
    CommunityPostKind.video ||
    CommunityPostKind.general =>
      CommunityPostCategory.general,
  };
}

/// Maps Discover grid labels to post categories.
CommunityPostCategory? categoryFromDiscoverLabel(String label) {
  return switch (label) {
    'Scorers' => CommunityPostCategory.lookingForScorer,
    'Umpires' => CommunityPostCategory.lookingForUmpire,
    'Commentators' => CommunityPostCategory.lookingForCommentator,
    'Streamers' => CommunityPostCategory.lookingForStreamer,
    'Tournaments' => CommunityPostCategory.tournamentNeed,
    'Grounds' => CommunityPostCategory.groundAvailable,
    'Academies' => CommunityPostCategory.general,
    'Players' => CommunityPostCategory.lookingForPlayer,
    _ => null,
  };
}
