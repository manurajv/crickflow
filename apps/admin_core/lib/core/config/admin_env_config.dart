/// Compile-time admin environment (CI / dart-define). Never holds secrets.
///
/// ```bash
/// flutter build web --dart-define=ADMIN_ENV=staging --dart-define=ADMIN_VERSION=0.1.0
/// ```
enum AdminBuildEnvironment {
  development,
  testing,
  staging,
  production;

  String get label => switch (this) {
        AdminBuildEnvironment.development => 'Development',
        AdminBuildEnvironment.testing => 'Testing',
        AdminBuildEnvironment.staging => 'Staging',
        AdminBuildEnvironment.production => 'Production',
      };

  String get wireValue => name;

  bool get isProduction => this == AdminBuildEnvironment.production;

  /// True when this build must not talk to production Firebase by default.
  bool get isolatesFromProduction =>
      this == AdminBuildEnvironment.development ||
      this == AdminBuildEnvironment.testing;

  static AdminBuildEnvironment parse(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final e in values) {
      if (e.name == v) return e;
    }
    return AdminBuildEnvironment.development;
  }
}

/// Values injected at build time. Safe to ship to the browser (no secrets).
abstract final class AdminEnvConfig {
  /// `development` | `testing` | `staging` | `production`
  static const envName = String.fromEnvironment(
    'ADMIN_ENV',
    defaultValue: 'development',
  );

  static const version = String.fromEnvironment(
    'ADMIN_VERSION',
    defaultValue: '0.1.0',
  );

  static const buildNumber = String.fromEnvironment(
    'ADMIN_BUILD_NUMBER',
    defaultValue: '0',
  );

  /// Logical Firebase project id for this build (display / gating only).
  /// Real options still come from each app's `firebase_options.dart`.
  static const firebaseProjectId = String.fromEnvironment(
    'ADMIN_FIREBASE_PROJECT_ID',
    defaultValue: 'crickflow-b06bc',
  );

  /// Hosting site id for documentation / DevOps metadata (not a secret).
  static const hostingSite = String.fromEnvironment(
    'ADMIN_HOSTING_SITE',
    defaultValue: '',
  );

  static const gitSha = String.fromEnvironment(
    'ADMIN_GIT_SHA',
    defaultValue: '',
  );

  static const gitRef = String.fromEnvironment(
    'ADMIN_GIT_REF',
    defaultValue: '',
  );

  static AdminBuildEnvironment get environment =>
      AdminBuildEnvironment.parse(envName);

  static String get versionLabel {
    final b = buildNumber.trim();
    if (b.isEmpty || b == '0') return version;
    return '$version+$b';
  }

  /// Banner / DevOps display helper.
  static String get displayBanner =>
      '${environment.label} · $versionLabel'
      '${gitSha.isEmpty ? '' : ' · ${gitSha.length >= 7 ? gitSha.substring(0, 7) : gitSha}'}';
}
