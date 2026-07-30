# CrickFlow Web Admin — Design System

Premium enterprise SaaS design language for **Super Admin** and **Organization Admin**.

This document is the source of truth for web admin UI. Mobile [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md) does **not** apply here.

---

## Principles

1. **One product** — every module shares tokens, chrome, and `Cf*` widgets.
2. **Polish, don’t redesign** — improve consistency without changing features or business logic.
3. **Token-first** — prefer `AdminColors` / `AdminDimens` / `AdminTypography` / `AdminMotion` over hardcoded values.
4. **Desktop-first** — tablet / laptop / desktop / ultra-wide; no mobile layout required.
5. **Accessible** — focus rings, semantics, tooltips, contrast-aware status colors.

---

## Folder structure

```
apps/admin_core/lib/
  core/theme/
    admin_colors.dart      # Brand + semantic colors (ThemeExtension)
    admin_dimens.dart      # Spacing, radius, layout, icon sizes
    admin_typography.dart  # Type scale helpers
    admin_motion.dart      # Durations / curves
    admin_elevations.dart  # Elevation intent
    admin_theme.dart       # Material 3 ThemeData light/dark
  core/extensions/
    context_extensions.dart  # context.adminColors / adminDimens
  shared/widgets/
    cf_button.dart
    cf_card.dart
    cf_data_table.dart
    cf_dialog.dart
    cf_empty_state.dart
    cf_error (via cf_dialog.dart → CfErrorState)
    cf_filter_sheet.dart     # + CfFilterDrawerChrome / CfFilterSection
    cf_loading_state.dart
    cf_page.dart             # CfPageHeader / CfPageBody
    cf_pagination.dart
    cf_search_bar.dart       # + CfSearchChip
    cf_skeleton.dart
    cf_snackbar.dart
    cf_stat_tile.dart
    cf_status_badge.dart
    cf_chart_placeholder.dart
  features/shell/            # Sidebar + top bar (structure preserved)
```

---

## Brand & color

| Token | Value |
|-------|-------|
| Primary | Blue `#1E88E5` |
| Secondary | Gold / Yellow `#FFC107` |
| Neutrals | White, gray, dark gray / slate |
| Success / Warning / Danger / Info | Semantic on `AdminColors` |

Access: `context.adminColors`.

Sidebar uses `sidebar`, `sidebarHover`, `sidebarFg`, `sidebarFgMuted`, `sidebarSelected` — avoid raw `Colors.white70` in new code.

---

## Spacing & layout

| Token | Default |
|-------|---------|
| `spaceXs` … `spaceXxxl` | 4 → 32 |
| `radiusSm` … `radiusXl` | 8 → 20 |
| `pagePadding` | `20, 20, 20, 32` |
| `cardPadding` | `20` |
| `topBarHeight` | `64` |
| `detailPanelWidth` | `480` |
| Sidebar | `Breakpoints.sidebarExpanded` 260 / collapsed 72 |

Access: `context.adminDimens`.

---

## Typography

Font: **Plus Jakarta Sans** via `AdminTypography.textTheme`.

Roles: Display → Headline → Title → Body → Label, plus helpers:

- `AdminTypography.statistic`
- `AdminTypography.table`
- `AdminTypography.sidebar`
- `AdminTypography.button`

---

## Motion

`AdminMotion.fast` / `normal` / `slow` + `standard` / `enter` / `exit` curves. Prefer subtle fade/slide; do not add decorative motion.

---

## Shared components

| Widget | Use for |
|--------|---------|
| `CfButton` | primary / secondary / outlined / text / ghost / danger / success + loading |
| `CfCard` | surfaces; optional hover elevation when `onTap` set |
| `CfStatTile` | KPI / overview cards |
| `CfDataTable` | simple tabular data (hover, density, sort hooks, selection) |
| `CfSearchBar` / `CfSearchChip` | toolbars |
| `CfFilterDrawerChrome` | end-drawer filters (Reset / Apply) |
| `showCfConfirmDialog` / `CfDialogKind` | confirm / delete / archive / restore / warning… |
| `CfSnack` | success / warning / error / info / progress snackbars |
| `CfEmptyState` / `CfErrorState` / `CfLoadingState` | empty / error / loading |
| `CfSkeleton*` | shimmer placeholders (`CfLoadingState(skeleton: true)`) |
| `CfStatusBadge` | status pills |
| `CfPageHeader` / `CfPageBody` | page chrome + standard padding |
| `CfPagination` | page controls |

---

## Shell

- **Sidebar** — existing structure kept; spacing, selected border accent, hover, collapse animation use tokens.
- **Top bar** — height from `AdminDimens.topBarHeight`; breadcrumbs + notifications + profile / theme / logout.
- **Breadcrumbs** — set via `breadcrumbProvider` from each screen (`['Management', 'Users']`).

---

## Themes

```dart
MaterialApp.router(
  theme: AdminTheme.light(),
  darkTheme: AdminTheme.dark(),
  themeMode: ref.watch(themeModeProvider),
);
```

Light + dark Material 3. Secondary brand color is gold. Avoid heavy gradients except the small sidebar brand mark.

---

## Adoption rules

1. **New UI** must use tokens + `Cf*` widgets.
2. **Existing modules** migrate opportunistically when touched — do not rewrite feature logic for style alone.
3. Prefer `showCfConfirmDialog` / `CfSnack` over one-off `AlertDialog` / raw snackbars.
4. Prefer `CfStatusBadge` over new per-module pill widgets.
5. Never expose secrets in UI; mask sensitive fields.

---

## Accessibility checklist

- [ ] Interactive controls have tooltips or semantics labels
- [ ] Focus visible via theme `focusColor` / focused borders
- [ ] Status not color-only (label text on badges)
- [ ] Empty / error / loading states announce meaning
- [ ] Contrast: text on surfaces uses `textPrimary` / `textSecondary`

---

## Out of scope

- Mobile app design system
- Firestore / API / auth / business-logic changes
- Redesigning module information architecture
