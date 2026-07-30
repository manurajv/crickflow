# Coding Standards

## Purpose

Keep admin code consistent across contributors.

## Overview

Follow existing `admin_core` patterns before inventing new ones. Run `flutter analyze` before PRs.

## Naming

| Kind | Convention | Example |
|------|------------|---------|
| Files | `snake_case.dart` | `match_detail_panel.dart` |
| Types | `PascalCase` | `ManagedMatch` |
| Providers | `camelCase` + `Provider` | `usersListControllerProvider` |
| Private widgets | `_Prefix` | `_NavTile` |
| Collections | `snake_case` / `admin_*` | `admin_audit_logs` |
| Permissions | `canVerbNoun` | `canManageUsers` |

## Folder & feature rules

- One feature folder per hub.
- No business Firestore calls in widgets.
- Shared visuals → `shared/widgets/cf_*.dart`.
- Cross-cutting services → `services/` or `core/`.

## Documentation comments

- Public APIs / repositories: short `///` purpose + non-negotibles.
- Do not narrate obvious code.
- Security-sensitive areas: state what must **never** be stored/returned (tokens, passwords).

## Formatting & lint

- `flutter format` / IDE Dart formatter.
- `flutter_lints` enabled in each package.
- Prefer expression/`switch` forms consistent with neighboring files.

## Provider naming

```dart
final usersRepositoryProvider = Provider<UsersRepository>(...);
final usersListControllerProvider =
    StateNotifierProvider<UsersListController, UsersHubState>(...);
final selectedManagedUserProvider = FutureProvider.autoDispose<ManagedUser?>(...);
```

## Error & empty UX

- Use `CfEmptyState`, `CfLoadingState`, `CfErrorState` / snackbars.
- Map Firebase errors via `AdminErrors` where available.

## PR expectations

- No mobile `lib/` changes in admin PRs.
- Update `docs/IMPLEMENTATION_STATUS.md` for shipped modules.
- Do not commit secrets.
- Prefer small PRs per module.

## Common mistakes

- `TextEditingController` created inside `build`.
- Ignoring org scope on Super-vs-Org shared repositories.
- Adding permissions without seeding `admin_roles` / provision script.

## Future improvements

- `analysis_options.yaml` custom rules for admin_core.
- Danger/CI check forbidding secrets patterns.
