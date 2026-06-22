import '../constants/player_profile_constants.dart';
import '../../data/models/user_model.dart';

/// Display labels for profile fields (role, styles, location, joined date).
class PlayerProfileLabels {
  PlayerProfileLabels._();

  static String playingRole(UserModel user) =>
      user.playerRole?.label ?? '—';

  static String battingStyle(UserModel user) {
    final style = user.battingStyle;
    if (style == null) return '—';
    return switch (style) {
      PlayerBattingStyle.rightHandBatsman => 'Right Hand Bat',
      PlayerBattingStyle.leftHandBatsman => 'Left Hand Bat',
    };
  }

  static String battingStyleShort(UserModel user) {
    final style = user.battingStyle;
    if (style == null) return '';
    return switch (style) {
      PlayerBattingStyle.rightHandBatsman => 'RHB',
      PlayerBattingStyle.leftHandBatsman => 'LHB',
    };
  }

  /// Role, short batting style, and bowling style — comma separated, no icons.
  static String roleStylesLine(UserModel user) {
    final parts = <String>[];
    final role = playingRole(user);
    if (role != '—') parts.add(role);
    final bat = battingStyleShort(user);
    if (bat.isNotEmpty) parts.add(bat);
    final bowl = bowlingStyle(user);
    if (bowl != '—') parts.add(bowl);
    return parts.join(', ');
  }

  static String roleStylesLineFromPlayer({
    required String role,
    required String battingStyle,
    required String bowlingStyle,
  }) {
    final parts = <String>[];
    if (role.isNotEmpty) parts.add(role);
    if (battingStyle.isNotEmpty) {
      final lower = battingStyle.toLowerCase();
      if (lower.contains('left')) {
        parts.add('LHB');
      } else if (lower.contains('right')) {
        parts.add('RHB');
      } else {
        parts.add(battingStyle);
      }
    }
    if (bowlingStyle.isNotEmpty) parts.add(bowlingStyle);
    return parts.join(', ');
  }

  static String bowlingStyle(UserModel user) {
    final style = user.bowlingStyle;
    if (style == null) return '—';
    return style.label;
  }

  static String location(UserModel user) {
    if (user.location.city.isNotEmpty) return user.location.city;
    if (user.location.stateProvince.isNotEmpty) {
      return user.location.stateProvince;
    }
    if (user.country.isNotEmpty) return user.country;
    if (user.location.country.isNotEmpty) return user.location.country;
    return '—';
  }

  static String joinedDate(UserModel user) {
    final date = user.createdAt;
    if (date == null) return '—';
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return 'Joined ${months[date.month - 1]} ${date.year}';
  }

  static String gender(UserModel user) => user.gender?.label ?? '—';

  static String dateOfBirth(UserModel user) {
    final dob = user.dateOfBirth;
    if (dob == null) return '—';
    return '${dob.day.toString().padLeft(2, '0')}/'
        '${dob.month.toString().padLeft(2, '0')}/${dob.year}';
  }

  static String country(UserModel user) {
    if (user.country.isNotEmpty) return user.country;
    if (user.location.country.isNotEmpty) return user.location.country;
    return '—';
  }

  static String city(UserModel user) => user.location.city.isNotEmpty
      ? user.location.city
      : (user.location.displayLabel.isNotEmpty
          ? user.location.displayLabel
          : '—');
}
