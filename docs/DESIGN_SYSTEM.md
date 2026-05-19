# CrickFlow Design System

## Theme

- **Mode:** Dark only (Phase 1)
- **Style:** Sports broadcast / premium

## Colors

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#0A0E17` | Scaffold |
| Surface | `#141B2D` | Cards, app bar |
| Primary Blue | `#1E88E5` | CTAs, scoreboard |
| Gold | `#FFC107` | Accents, highlights, FAB |
| Accent Red | `#E53935` | Live indicator, wickets |
| Scoreboard BG | `#0D47A1` | Scorebug gradient |

## Typography

Material 3 `TextTheme` — display for scores, title for section headers, body for commentary.

## Components

- `ScoreboardCard` — primary live score display
- `CfButton` — full-width primary actions
- `MatchRulesEditor` — segmented format + numeric rule fields
- `LocationFields` — country / state / city trio

## UX Principles

- **Outdoor readability** — high contrast white on dark blue
- **Minimal taps for scorers** — 0–6 run grid, one-tap extras
- **Landscape** — stream screen locks to landscape
- **Tablet** — responsive padding; grids use `Wrap`
