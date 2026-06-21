import '../../../core/constants/player_profile_constants.dart';

/// Curated cricket fields for the edit-profile screen (not onboarding).
class EditProfileOptions {
  EditProfileOptions._();

  static final playingRoles = [
    PlayerPlayingRole.batsman,
    PlayerPlayingRole.bowler,
    PlayerPlayingRole.allRounder,
    PlayerPlayingRole.wicketKeeper,
    PlayerPlayingRole.wicketKeeperBatter,
  ];

  static final battingStyles = PlayerBattingStyle.values;

  static final bowlingStyles = [
    PlayerBowlingStyle.rightArmFast,
    PlayerBowlingStyle.leftArmFast,
    PlayerBowlingStyle.rightArmMedium,
    PlayerBowlingStyle.leftArmMedium,
    PlayerBowlingStyle.rightArmOffSpin,
    PlayerBowlingStyle.rightArmLegSpin,
    PlayerBowlingStyle.leftArmOrthodoxSpin,
    PlayerBowlingStyle.leftArmChinaman,
  ];

  static final dominantHands = PlayerStrongHand.values;

  static String battingLabel(PlayerBattingStyle style) => switch (style) {
        PlayerBattingStyle.rightHandBatsman => 'Right Hand Bat',
        PlayerBattingStyle.leftHandBatsman => 'Left Hand Bat',
      };

  static String bowlingLabel(PlayerBowlingStyle style) => switch (style) {
        PlayerBowlingStyle.leftArmOrthodoxSpin => 'Left Arm Orthodox',
        _ => style.label,
      };

  static String dominantHandLabel(PlayerStrongHand hand) => switch (hand) {
        PlayerStrongHand.rightHanded => 'Right',
        PlayerStrongHand.leftHanded => 'Left',
      };
}
