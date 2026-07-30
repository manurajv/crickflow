/// Catalog entry for the in-app Developer Docs Center.
class DeveloperDocPage {
  const DeveloperDocPage({
    required this.id,
    required this.title,
    required this.section,
    required this.assetPath,
    required this.keywords,
    this.summary = '',
  });

  final String id;
  final String title;
  final String section;
  final String assetPath;
  final List<String> keywords;
  final String summary;
}

/// Static registry — keep in sync with `assets/docs/` and `docs/developer/`.
abstract final class DeveloperDocsCatalog {
  static const pages = <DeveloperDocPage>[
    DeveloperDocPage(
      id: 'readme',
      title: 'Documentation Home',
      section: 'Start here',
      assetPath: 'assets/docs/README.md',
      keywords: ['index', 'toc', 'home', 'onboarding'],
      summary: 'Handbook index and quick start',
    ),
    DeveloperDocPage(
      id: 'architecture',
      title: 'Architecture Overview',
      section: 'Fundamentals',
      assetPath: 'assets/docs/architecture.md',
      keywords: [
        'layers',
        'clean architecture',
        'dependency',
        'data flow',
        'mermaid',
      ],
      summary: 'System layers, module relationships, data flow',
    ),
    DeveloperDocPage(
      id: 'project-structure',
      title: 'Project Structure',
      section: 'Fundamentals',
      assetPath: 'assets/docs/project-structure.md',
      keywords: ['folders', 'lib', 'features', 'core', 'shared'],
      summary: 'Every folder explained',
    ),
    DeveloperDocPage(
      id: 'developer-guide',
      title: 'Developer Guide',
      section: 'Fundamentals',
      assetPath: 'assets/docs/developer-guide.md',
      keywords: ['onboarding', 'setup', 'workflow', 'examples'],
      summary: 'Day-one setup and implementation workflow',
    ),
    DeveloperDocPage(
      id: 'coding-standards',
      title: 'Coding Standards',
      section: 'Fundamentals',
      assetPath: 'assets/docs/coding-standards.md',
      keywords: ['naming', 'lint', 'pr', 'style'],
      summary: 'Naming, formatting, PR expectations',
    ),
    DeveloperDocPage(
      id: 'authentication',
      title: 'Authentication Guide',
      section: 'Core systems',
      assetPath: 'assets/docs/authentication.md',
      keywords: [
        'login',
        'roles',
        'permissions',
        'session',
        'routes',
        'rbac',
      ],
      summary: 'Auth flow, RBAC, protected routes',
    ),
    DeveloperDocPage(
      id: 'state-management',
      title: 'State Management',
      section: 'Core systems',
      assetPath: 'assets/docs/state-management.md',
      keywords: ['riverpod', 'providers', 'repository', 'di'],
      summary: 'Riverpod architecture and best practices',
    ),
    DeveloperDocPage(
      id: 'firestore',
      title: 'Firestore',
      section: 'Data & APIs',
      assetPath: 'assets/docs/firestore.md',
      keywords: [
        'collections',
        'rules',
        'indexes',
        'queries',
        'admin_users',
      ],
      summary: 'Collections, rules, indexes, examples',
    ),
    DeveloperDocPage(
      id: 'firebase-apis',
      title: 'Firebase & APIs',
      section: 'Data & APIs',
      assetPath: 'assets/docs/firebase-apis.md',
      keywords: [
        'auth',
        'functions',
        'storage',
        'maps',
        'admob',
        'youtube',
      ],
      summary: 'External APIs used by admin (no secrets)',
    ),
    DeveloperDocPage(
      id: 'features',
      title: 'Features',
      section: 'Product',
      assetPath: 'assets/docs/features.md',
      keywords: [
        'dashboard',
        'users',
        'matches',
        'security',
        'devops',
        'continuity',
        'modules',
      ],
      summary: 'Every admin hub documented',
    ),
    DeveloperDocPage(
      id: 'component-library',
      title: 'Component Library',
      section: 'Product',
      assetPath: 'assets/docs/component-library.md',
      keywords: ['CfButton', 'widgets', 'design system', 'tables'],
      summary: 'Shared Cf* widgets',
    ),
    DeveloperDocPage(
      id: 'error-handling',
      title: 'Error Handling',
      section: 'Operations',
      assetPath: 'assets/docs/error-handling.md',
      keywords: ['exceptions', 'retry', 'network', 'firestore'],
      summary: 'Error categories and UX',
    ),
    DeveloperDocPage(
      id: 'deployment',
      title: 'Deployment',
      section: 'Operations',
      assetPath: 'assets/docs/deployment.md',
      keywords: ['hosting', 'build', 'domains', 'release'],
      summary: 'Build, Hosting, versioning',
    ),
    DeveloperDocPage(
      id: 'cicd',
      title: 'CI/CD',
      section: 'Operations',
      assetPath: 'assets/docs/cicd.md',
      keywords: [
        'github actions',
        'pipeline',
        'deploy',
        'quality gates',
        'environments',
        'semantic versioning',
      ],
      summary: 'GitHub Actions, env matrix, manual Hosting deploy',
    ),
    DeveloperDocPage(
      id: 'continuity',
      title: 'Continuity & DR',
      section: 'Operations',
      assetPath: 'assets/docs/continuity.md',
      keywords: [
        'backup',
        'restore',
        'disaster recovery',
        'migration',
        'export',
        'import',
      ],
      summary: 'Backup, restore previews, recovery plans (never auto-restore)',
    ),
    DeveloperDocPage(
      id: 'environments',
      title: 'Environments',
      section: 'Operations',
      assetPath: 'assets/docs/environments.md',
      keywords: ['secrets', 'flags', 'config', 'staging'],
      summary: 'Config, flags, secret hygiene',
    ),
    DeveloperDocPage(
      id: 'troubleshooting',
      title: 'Troubleshooting',
      section: 'Operations',
      assetPath: 'assets/docs/troubleshooting.md',
      keywords: ['debug', 'permission-denied', 'login', 'hosting'],
      summary: 'Common failure runbooks',
    ),
    DeveloperDocPage(
      id: 'changelog',
      title: 'Changelog',
      section: 'Meta',
      assetPath: 'assets/docs/changelog.md',
      keywords: ['version', 'history', 'breaking'],
      summary: 'Version history',
    ),
    DeveloperDocPage(
      id: 'roadmap',
      title: 'Roadmap',
      section: 'Meta',
      assetPath: 'assets/docs/roadmap.md',
      keywords: ['planned', 'future', 'backlog'],
      summary: 'Completed, planned, future ideas',
    ),
  ];

  static DeveloperDocPage? byId(String id) {
    for (final p in pages) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<DeveloperDocPage> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return pages;
    return pages.where((p) {
      if (p.title.toLowerCase().contains(q)) return true;
      if (p.section.toLowerCase().contains(q)) return true;
      if (p.summary.toLowerCase().contains(q)) return true;
      if (p.id.contains(q)) return true;
      return p.keywords.any((k) => k.toLowerCase().contains(q));
    }).toList();
  }

  static List<String> get sections {
    final seen = <String>{};
    final out = <String>[];
    for (final p in pages) {
      if (seen.add(p.section)) out.add(p.section);
    }
    return out;
  }
}
