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
