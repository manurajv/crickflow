/// Helpers for `users/{uid}/private/profile` PII (email, phone, date of birth).
///
/// Parent `users/{uid}` remains dual-written so the current Play Store app
/// keeps working. Readers prefer the private subdocument and fall back to
/// the parent fields when it is missing or unreadable.
library;

// Keep in sync with lib/data/user_private_profile.dart.

const String kUserPrivateProfileDocId = 'profile';
const String kUserPrivateCollection = 'private';

/// Overlay private-profile fields onto a parent user document map.
/// Empty or missing private values leave the parent value unchanged.
Map<String, dynamic> mergePrivateUserProfile(
  Map<String, dynamic> parent, [
  Map<String, dynamic>? private,
]) {
  if (private == null || private.isEmpty) {
    return Map<String, dynamic>.from(parent);
  }
  final out = Map<String, dynamic>.from(parent);
  final email = _nonEmpty(private['email']);
  if (email != null) out['email'] = email;

  final phone = _nonEmpty(private['phoneNumber']) ?? _nonEmpty(private['mobile']);
  final mobile = _nonEmpty(private['mobile']) ?? _nonEmpty(private['phoneNumber']);
  if (phone != null) out['phoneNumber'] = phone;
  if (mobile != null) out['mobile'] = mobile;

  final dob = private['dob'] ?? private['dateOfBirth'];
  if (dob != null && (dob is! String || dob.trim().isNotEmpty)) {
    out['dob'] = dob;
    out['dateOfBirth'] = dob;
  }
  return out;
}

/// Payload written to `users/{uid}/private/profile`.
Map<String, dynamic> privateUserProfilePayload({
  required String email,
  String? phoneNumber,
  String? mobile,
  DateTime? dateOfBirth,
  String? dateOfBirthRaw,
  required String updatedAt,
}) {
  final phone = _nonEmpty(phoneNumber) ?? _nonEmpty(mobile);
  final mob = _nonEmpty(mobile) ?? _nonEmpty(phoneNumber);
  final dob = dateOfBirthRaw ?? dateOfBirth?.toIso8601String();
  return {
    'email': email,
    'phoneNumber': phone,
    'mobile': mob,
    'dob': dob,
    'dateOfBirth': dob,
    'updatedAt': updatedAt,
  };
}

String? _nonEmpty(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
