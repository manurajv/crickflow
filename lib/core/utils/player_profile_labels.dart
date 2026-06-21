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
