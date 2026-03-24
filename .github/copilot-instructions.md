# Copilot Instructions — Industrial de Molinos

## Project Overview

Sistema de gestión contable para PYME (SME accounting management system) built with Flutter.
- **Platforms**: Windows (primary), Web, Android, iOS
- **Backend**: Supabase (PostgreSQL + Auth + RLS)
- **Locale**: Colombia (`es_CO`), currency USD, document types CC/NIT/CE/Pasaporte/TI
- **Flutter**: 3.38.1+ / Dart 3.10.0+

## Architecture

Clean Architecture with Riverpod 3.0 (Notifier-based):

```
lib/
├── core/           # Theme, constants, utils, responsive helpers
├── domain/         # Entities only (no repository interfaces)
├── data/
│   ├── datasources/  # Static-method classes calling Supabase/SQLite directly
│   └── providers/    # Riverpod Notifier + State pairs (one per feature)
└── presentation/
    ├── pages/        # One file per screen (~24 pages)
    └── widgets/      # Shared reusable widgets (~11 files)
```

**Data flow**: Page watches Provider → Notifier calls DataSource → DataSource queries Supabase → returns Entity.

## Key Conventions

### Dart & Flutter
- **State management**: Riverpod 3.0 with `Notifier<T>` + `NotifierProvider`. Each feature has an immutable `State` class with `copyWith()`, a `Notifier` class, and a provider.
- **DataSources**: Static-method classes. Pattern: `static SupabaseClient get _client => SupabaseDataSource.client;` with static CRUD methods.
- **No repository layer** — datasources are called directly from notifiers.
- **Navigation**: GoRouter with `StatefulShellRoute.indexedStack()`. Auth redirect via Supabase auth stream.
- **Responsive**: 3 breakpoints — Mobile <600dp, Tablet 600–1024dp, Desktop >1024dp. Use `LayoutBuilder`/`MediaQuery`/`Wrap`, no external packages.
- **Theme**: Material Design 3, seed color `#1B4F72`. Theme files in `lib/core/theme/`.
- **Locale**: `es_CO` date formatting via `intl`. All user-facing strings in Spanish.
- **Linter**: `flutter_lints` with `avoid_print: false`, `deprecated_member_use: ignore`, `use_build_context_synchronously: ignore`.

### Supabase & Database
- Config loaded from `.env` via `flutter_dotenv` at runtime (never hardcode keys).
- Project ID: `slpawyxxqzjdkbhwikwt`.
- Migrations in `supabase_migrations/` (numbered sequentially: `000_`, `001_`, …).
- RLS is enabled — anon key has restricted access; use `service_role` for admin ops.

### File Encoding
- All `.dart` files must be **UTF-8 without BOM**. Some legacy files were Windows-1252 — always verify encoding when editing datasource files.

## Build & Release

```powershell
# Development
flutter pub get
flutter run -d windows      # or -d chrome, -d android

# Production build
flutter build windows --release

# Full release (build + Inno Setup installer)
.\build_release.bat
# Output: build\installer\MolinosApp_Setup_X.Y.Z.exe
```

**Version bump checklist** (all must match):
1. `pubspec.yaml` → `version: X.Y.Z+N`
2. `lib/core/constants/app_constants.dart` → `appVersion` + `appBuildNumber`
3. `installer/molinos_app.iss` → `#define MyAppVersion "X.Y.Z"`
4. `CHANGELOG.md` → new section

## Responsive Layout Pitfalls

- Avoid `Spacer`/`Expanded` inside `AlertDialog.actions` — use `SizedBox` or `actionsAlignment`.
- Use `isScrollable: true` on `TabBar` in constrained widths.
- Switch card rows to `Wrap` or 2-column fallback when width < ~900dp.
- Prefer `LayoutBuilder` + `Wrap` for action bars with many controls.

## SQL Migrations

- Place new migrations in `supabase_migrations/` with the next sequential number prefix.
- Standalone fix scripts go in the project root as `EJECUTAR_*.sql` or `LIMPIAR_*.sql`.
- Schema reference: `database/schema_consolidado.sql`.

## Project-Specific Notes

- `RestartWidget` wraps the app to allow full restart without re-launching.
- AI assistant overlay is always rendered on top of the main shell (see `router.dart`).
- Auto-update system checks `app_releases` table in Supabase on startup.
- Photo module exists at `lib/photo/` for camera/gallery features.
- Entities use enum extensions with `.normalized` and `.isLegacy` for backward compat.
