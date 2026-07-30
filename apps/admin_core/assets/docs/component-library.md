# Component Library

## Purpose

Document reusable `Cf*` widgets in `apps/admin_core/lib/shared/widgets/`.

## Overview

Design tokens: `AdminColors`, `AdminDimens`, `AdminTypography`, `AdminMotion`, `AdminElevations`.  
Access: `context.adminColors` / `context.adminDimens`.  
Guide: [WEB_ADMIN_DESIGN.md](../WEB_ADMIN_DESIGN.md).

## Catalog

| Widget | File | Role |
|--------|------|------|
| `CfButton` | `cf_button.dart` | Primary / secondary / ghost / danger actions |
| `CfCard` | `cf_card.dart` | Surface container |
| `CfDataTable` | `cf_data_table.dart` | Structured tables |
| `CfDialog` / confirm | `cf_dialog.dart` | Dialogs + `CfErrorState` |
| `CfEmptyState` | `cf_empty_state.dart` | Empty / locked (FittedBox for tight heights) |
| `CfLoadingState` | `cf_loading_state.dart` | Loading copy + spinner |
| `CfSkeleton` | `cf_skeleton.dart` | Placeholder shimmer |
| `CfSearchBar` / chips | `cf_search_bar.dart` | Search field |
| `CfFilterSheet` | `cf_filter_sheet.dart` | Filter drawer chrome |
| `CfPagination` | `cf_pagination.dart` | Page controls |
| `CfStatTile` | `cf_stat_tile.dart` | KPI tile |
| `CfStatusBadge` | `cf_status_badge.dart` | Status pill |
| `CfSnackbar` | `cf_snackbar.dart` | Toast helpers |
| `CfPageHeader` / body | `cf_page.dart` | Page chrome |
| `CfNetworkImage` | `cf_network_image.dart` | Lazy images |
| `CfChartPlaceholder` | `cf_chart_placeholder.dart` | Chart shell |

## Usage example

```dart
CfButton(
  label: context.l10n.actionSave,
  onPressed: busy ? null : onSave,
);
```

```dart
CfEmptyState(
  icon: Icons.inbox_outlined,
  title: context.l10n.commonEmpty,
  message: context.l10n.commonNoResults,
);
```

## Accessibility

- Prefer tooltips + `Semantics` on icon-only controls (`AdminA11y.iconAction`).
- Maintain visible focus via Material 3 themes.
- Status colors must remain distinguishable in light/dark (avoid color-only meaning).

## Best practices

- Extend tokens before inventing one-off colors.
- Keep interaction cards only when interaction needs a container.

## Common mistakes

- Hardcoding `Colors.white70` in sidebar (use sidebar tokens).
- Nested scroll views without Expanded/bounded height.

## Future improvements

- Widgetbook / Storybook-style gallery route.
- Golden tests per `Cf*` widget.
