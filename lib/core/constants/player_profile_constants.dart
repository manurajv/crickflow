/// Playing role, style, and onboarding option labels stored on user profile.
library;

import 'countries.dart';

enum PlayerPlayingRole {  batsman,
  bowler,
  allRounder,
  wicketKeeper,
  wicketKeeperBatter,
  bowlingAllRounder,
  battingAllRounder,
}

enum PlayerBattingStyle {
  rightHandBatsman,
  leftHandBatsman,
}

enum PlayerBowlingCategory {
  fast,
  mediumFast,
  medium,
  spin,
  doNotBowl,
}

enum PlayerBowlingArm {
  rightArm,
  leftArm,
}

enum PlayerBowlingStyle {
  rightArmFast,
  leftArmFast,
  rightArmMediumFast,
  leftArmMediumFast,
  rightArmMedium,
  leftArmMedium,
  rightArmOffSpin,
  rightArmLegSpin,
  rightArmLegBreak,
  rightArmGoogly,
  leftArmOrthodoxSpin,
  leftArmChinaman,
  leftArmWristSpin,
  doNotBowl,
}

enum PlayerPrimaryPosition {
  opener,
  topOrder,
  middleOrder,
  finisher,
  bowlingAllRounder,
  battingAllRounder,
  paceBowler,
  spinner,
  wicketKeeper,
}

enum PlayerStrongHand {
  rightHanded,
  leftHanded,
}

enum PlayerGender {
  male,
  female,
  other,
}

extension PlayerPlayingRoleLabels on PlayerPlayingRole {
  String get label => switch (this) {
        PlayerPlayingRole.batsman => 'Batsman',
        PlayerPlayingRole.bowler => 'Bowler',
        PlayerPlayingRole.allRounder => 'All Rounder',
        PlayerPlayingRole.wicketKeeper => 'Wicket Keeper',
        PlayerPlayingRole.wicketKeeperBatter => 'Wicket Keeper Batter',
        PlayerPlayingRole.bowlingAllRounder => 'Bowling All Rounder',
        PlayerPlayingRole.battingAllRounder => 'Batting All Rounder',
      };
}

extension PlayerBattingStyleLabels on PlayerBattingStyle {
  String get label => switch (this) {
        PlayerBattingStyle.rightHandBatsman => 'Right Hand Batsman',
        PlayerBattingStyle.leftHandBatsman => 'Left Hand Batsman',
      };
}

extension PlayerBowlingCategoryLabels on PlayerBowlingCategory {
  String get label => switch (this) {
        PlayerBowlingCategory.fast => 'Fast',
        PlayerBowlingCategory.mediumFast => 'Medium Fast',
        PlayerBowlingCategory.medium => 'Medium',
        PlayerBowlingCategory.spin => 'Spin',
        PlayerBowlingCategory.doNotBowl => 'Do Not Bowl',
      };
}

extension PlayerBowlingArmLabels on PlayerBowlingArm {
  String get label => switch (this) {
        PlayerBowlingArm.rightArm => 'Right Arm',
        PlayerBowlingArm.leftArm => 'Left Arm',
      };
}

extension PlayerBowlingStyleLabels on PlayerBowlingStyle {
  String get label => switch (this) {
        PlayerBowlingStyle.rightArmFast => 'Right Arm Fast',
        PlayerBowlingStyle.leftArmFast => 'Left Arm Fast',
        PlayerBowlingStyle.rightArmMediumFast => 'Right Arm Medium Fast',
        PlayerBowlingStyle.leftArmMediumFast => 'Left Arm Medium Fast',
        PlayerBowlingStyle.rightArmMedium => 'Right Arm Medium',
        PlayerBowlingStyle.leftArmMedium => 'Left Arm Medium',
        PlayerBowlingStyle.rightArmOffSpin => 'Right Arm Off Spin',
        PlayerBowlingStyle.rightArmLegSpin => 'Right Arm Leg Spin',
        PlayerBowlingStyle.rightArmLegBreak => 'Right Arm Leg Break',
        PlayerBowlingStyle.rightArmGoogly => 'Right Arm Googly',
        PlayerBowlingStyle.leftArmOrthodoxSpin => 'Left Arm Orthodox Spin',
        PlayerBowlingStyle.leftArmChinaman => 'Left Arm Chinaman',
        PlayerBowlingStyle.leftArmWristSpin => 'Left Arm Wrist Spin',
        PlayerBowlingStyle.doNotBowl => 'Do Not Bowl',
      };

  static PlayerBowlingStyle? fromCategoryAndArm({
    required PlayerBowlingCategory category,
    required PlayerBowlingArm arm,
  }) {
    return switch (category) {
      PlayerBowlingCategory.fast => arm == PlayerBowlingArm.rightArm
          ? PlayerBowlingStyle.rightArmFast
          : PlayerBowlingStyle.leftArmFast,
      PlayerBowlingCategory.mediumFast => arm == PlayerBowlingArm.rightArm
          ? PlayerBowlingStyle.rightArmMediumFast
          : PlayerBowlingStyle.leftArmMediumFast,
      PlayerBowlingCategory.medium => arm == PlayerBowlingArm.rightArm
          ? PlayerBowlingStyle.rightArmMedium
          : PlayerBowlingStyle.leftArmMedium,
      PlayerBowlingCategory.spin => null,
      PlayerBowlingCategory.doNotBowl => PlayerBowlingStyle.doNotBowl,
    };
  }

  static List<PlayerBowlingStyle> spinStylesForArm(PlayerBowlingArm arm) {
    if (arm == PlayerBowlingArm.rightArm) {
      return const [
        PlayerBowlingStyle.rightArmOffSpin,
        PlayerBowlingStyle.rightArmLegSpin,
        PlayerBowlingStyle.rightArmLegBreak,
        PlayerBowlingStyle.rightArmGoogly,
      ];
    }
    return const [
      PlayerBowlingStyle.leftArmOrthodoxSpin,
      PlayerBowlingStyle.leftArmChinaman,
      PlayerBowlingStyle.leftArmWristSpin,
    ];
  }
}

extension PlayerPrimaryPositionLabels on PlayerPrimaryPosition {
  String get label => switch (this) {
        PlayerPrimaryPosition.opener => 'Opener',
        PlayerPrimaryPosition.topOrder => 'Top Order',
        PlayerPrimaryPosition.middleOrder => 'Middle Order',
        PlayerPrimaryPosition.finisher => 'Finisher',
        PlayerPrimaryPosition.bowlingAllRounder => 'Bowling All Rounder',
        PlayerPrimaryPosition.battingAllRounder => 'Batting All Rounder',
        PlayerPrimaryPosition.paceBowler => 'Pace Bowler',
        PlayerPrimaryPosition.spinner => 'Spinner',
        PlayerPrimaryPosition.wicketKeeper => 'Wicket Keeper',
      };
}

extension PlayerStrongHandLabels on PlayerStrongHand {
  String get label => switch (this) {
        PlayerStrongHand.rightHanded => 'Right Handed',
        PlayerStrongHand.leftHanded => 'Left Handed',
      };
}

extension PlayerGenderLabels on PlayerGender {
  String get label => switch (this) {
        PlayerGender.male => 'Male',
        PlayerGender.female => 'Female',
        PlayerGender.other => 'Other',
      };
}

T? enumFromName<T extends Enum>(List<T> values, String? raw) {
  if (raw == null || raw.isEmpty) return null;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return null;
}

/// Common cricket nations with ISO code and flag emoji.
class CricketCountry {
  const CricketCountry({
    required this.name,
    required this.code,
    required this.flag,
    required this.dialCode,
  });

  final String name;
  final String code;
  final String flag;
  final String dialCode;

  factory CricketCountry.fromData(CountryData data) => CricketCountry(
        name: data.name,
        code: data.code,
        flag: data.flag,
        dialCode: data.dialCode,
      );

  static final List<CricketCountry> all = buildSortedCountryList()
      .map(CricketCountry.fromData)
      .toList(growable: false);

  static final List<String> phoneDialCodes = buildPhoneDialCodes(
    buildSortedCountryList(),
  );

  static CricketCountry? byCode(String? code) {
    if (code == null) return null;
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }

  static CricketCountry? byName(String? name) {
    if (name == null) return null;
    for (final c in all) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    return null;
  }
}