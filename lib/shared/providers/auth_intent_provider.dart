import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/enums.dart';

/// Role chosen on the login screen before Google / phone sign-in.
final signUpRoleProvider = StateProvider<UserRole>(
  (ref) => UserRole.organizer,
);
