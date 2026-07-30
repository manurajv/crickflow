# CrickFlow Web Admin — Accessibility, i18n, l10n & Globalization

Platform-wide foundation for **Super Admin** and **Organization Admin**.  
Does **not** change business logic, APIs, or the mobile app.

---

## Goals

| Area | Status |
|------|--------|
| Accessibility (WCAG AA-oriented) | Foundation shipped |
| Internationalization (ARB + gen-l10n) | Shipped |
| Localization (en, si, ta, hi + ar RTL scaffold) | Shell + common strings |
| Regional formats (date / time / number / TZ modes) | Shipped |
| Language switcher + preference persistence | Shipped |
| RTL architecture | Ready (`ar`; he/ur planned) |
| Incremental module string migration | Pattern documented |

---

## Architecture

```
apps/admin_core/
  l10n.yaml
  lib/l10n/
    app_en.arb          # Template (source of truth)
    app_si.arb          # Sinhala
    app_ta.arb          # Tamil
    app_hi.arb          # Hindi
    app_ar.arb          # Arabic — English copy, RTL layout
    generated/          # flutter gen-l10n output (committed)
  lib/core/locale/      # Catalog, regional settings, formatters, providers
  lib/core/l10n/        # MaterialApp wiring, nav resolver, export/search facades
  lib/core/a11y/        # Semantics helpers, context.l10n
```

Host apps (`admin`, `superadmin`) wire locale via `MaterialApp.router`:

- `locale` ← `adminLocaleProvider` (null = browser/system)
- `localizationsDelegates` ← `AdminL10nConfig`
- `supportedLocales` ← en / si / ta / hi / ar
- `textScaler` clamped 0.9–1.6 (large text without total layout collapse)

Flutter mirrors layout automatically for RTL locales (`ar`).

---

## Usage

### Strings

```dart
final l10n = context.l10n; // AdminLocalizations
Text(l10n.actionSave);
```

### Dates / numbers / time zones

```dart
final fmt = ref.watch(adminFormattersProvider);
fmt.formatDateTime(match.scheduledAt); // respects regional prefs
fmt.formatNumber(12345.6);
```

Timezone modes: `utc` | `browser` | `preferred` | `organization`.  
Preferred / org IANA ids are stored for future full TZ conversion (display currently falls back to browser local without new dependencies).

### Navigation labels

Keep stable `AdminNavItem.id` in nav configs. Resolve at render time:

```dart
AdminNavL10n.item(context.l10n, item);
AdminNavL10n.section(context.l10n, section.id);
```

### Language switching

Account menu → Language (System / en / si / ta / hi / ar).  
Persisted in `SessionPreferences` under `admin.regional.*`.  
**Never** affects permissions, auth, or API payloads.

### Accessibility helpers

```dart
AdminA11y.announce(context, message);
AdminA11y.iconAction(label: l10n.actionClose, icon: Icons.close, onPressed: …);
AdminA11y.labeledRegion(label: l10n.a11yTable, child: table);
```

Contrast: `textMuted` tokens tuned for WCAG AA on light/dark surfaces.

---

## Translation workflow

1. Add keys to `lib/l10n/app_en.arb` (with `@key` metadata for placeholders).
2. Translate into `app_si.arb` / `app_ta.arb` / `app_hi.arb` (and others as they ship).
3. From `apps/admin_core`: `flutter gen-l10n`
4. Commit updated `lib/l10n/generated/*`
5. Replace hardcoded UI strings with `context.l10n.*` module by module.

For **Arabic / Hebrew / Urdu**: add or update ARBs; RTL is automatic via `Directionality`.

Planned languages (formats-ready, UI pending ARBs): fr, es, de, pt, zh, ja, ur, he — see `AdminLocaleCatalog.planned`.

---

## Module migration checklist

For each hub screen:

- [ ] Page title / toolbar / empty / error / buttons → ARB
- [ ] Table headers / filter labels → ARB
- [ ] Dialogs / validation → ARB
- [ ] Timestamps via `adminFormattersProvider`
- [ ] Semantics labels on icon-only actions and charts
- [ ] Verify keyboard focus order and Escape closes dialogs

Shell (sidebar, top bar, account menu) already migrated.

---

## Exports / reports / search (future-ready)

- `AdminExportLocalizer` — CSV-safe escaping + locale-aware date/number cells  
- `AdminSearchI18n` — normalize / match hooks; synonyms & transliteration reserved  

---

## Security boundaries

Localization **must not** change:

- Authentication / session status  
- Permission checks / route guards  
- Firestore queries or security rules  
- Mobile notification generation  

---

## Testing

```bash
cd apps/admin_core
flutter gen-l10n
flutter test
flutter analyze
```

Manual: switch language in account menu; pick Arabic and confirm sidebar/top bar mirror; browser zoom + large text; keyboard Tab through shell; screen reader labels on nav icons.

---

## Related docs

- [WEB_ADMIN_DESIGN.md](WEB_ADMIN_DESIGN.md) — design tokens  
- [WEB_ADMIN_PRODUCTION.md](WEB_ADMIN_PRODUCTION.md) — performance  
- [WEB_ADMIN_QA_REPORT.md](WEB_ADMIN_QA_REPORT.md) — QA  
