# CrickFlow Design System

## Theme

- **Mode:** Dark only (Phase 1)
- **Style:** Sports broadcast / premium

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0E17` | Scaffold |
| Surface / chrome | `#141B2D` | Cards, **app bar**, **bottom nav** |
| Primary Blue | `#1E88E5` | CTAs, scoreboard, nav indicator |
| Gold | `#FFC107` | Accents, **selected nav**, FAB |
| Accent Red | `#E53935` | Live indicator, wickets |
| Scoreboard BG | `#0D47A1` | Scorebug gradient |

**Chrome rule:** App bar and bottom navigation both use `chromeBackground` with **gold** selected icons/labels and **grey** unselected — never mix mismatched accent colors.

## Typography

Compact Material 3 `TextTheme` (see `app_theme.dart` + `app_dimens.dart`):

| Token | Size | Use |
|-------|------|-----|
| displayLarge | 26 | Hero scores, overlay |
| displayMedium | 24 | Scoreboard runs |
| headlineMedium | 18 | Section headers |
| titleLarge | 16 | Screen sections |
| bodyLarge | 14 | Primary body |
| bodyMedium | 12 | Secondary / captions |

Global `visualDensity: compact` and reduced control heights (~40px buttons).

## Form fields

- **Underline style app-wide** — full-width labels, 16px input text, ~18px vertical padding (`CfInputTheme` / `inputDecorationTheme`).
- Gold focus underline; optional `CfUnderlinedField`, `CfFormFieldGroup`, `CfPickerField` for forms.
- Primary actions on forms: 52px height (`AppDimens.buttonHeightLarge`).

## Components

- `ShellTabScaffold` — tab roots with **drawer** + hamburger in `CfChromeAppBar`
- `CfAppDrawer` — side menu (profile header, start match, fantasy, settings)
- `MatchListCard` — matches tab list rows (status chip, meta, quick links)
- `ScoreboardCard` — primary live score display
- `CfButton` — full-width primary actions
- `MatchRulesEditor` — segmented format + numeric rule fields
- `LocationFields` — country / state / city trio

## UX Principles

- **Outdoor readability** — high contrast white on dark blue
- **Minimal taps for scorers** — 0–6 run grid, one-tap extras
- **Landscape** — stream screen locks to landscape
- **Tablet** — responsive padding; grids use `Wrap`
