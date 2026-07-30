/// Account lifecycle for platform users (additive `accountStatus` on `users`).
///
/// Soft lifecycle only — admin never hard-deletes the Firestore `users` doc.
/// Mobile ignores unknown fields; missing [accountStatus] is treated as [active].
///
/// Wire values align with SaaS conventions:
/// `active` | `suspended` | `banned` | `deleted` (+ `pendingVerification`, `inactive`).
enum UserAccountStatus {
  active,
  suspended,
  banned,
  deleted,
  pendingVerification,
  inactive;

  String get label => switch (this) {
        UserAccountStatus.active => 'Active',
        UserAccountStatus.suspended => 'Suspended',
        UserAccountStatus.banned => 'Banned',
        UserAccountStatus.deleted => 'Deleted',
        UserAccountStatus.pendingVerification => 'Pending Verification',
        UserAccountStatus.inactive => 'Inactive',
      };

  String get wireValue => name;

  bool get isSoftDeleted => this == UserAccountStatus.deleted;

  static UserAccountStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return UserAccountStatus.active;
    for (final s in UserAccountStatus.values) {
      if (s.name.toLowerCase() == raw.toLowerCase()) return s;
    }
    return UserAccountStatus.active;
  }
}
