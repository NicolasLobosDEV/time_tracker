# CLAUDE.md - AI Assistant Guide for Time Tracker

## Project Overview

Time Tracker is a cross-platform Flutter application for freelancers and consultants to track time, manage clients/projects, log expenses, generate invoices, and view reports. It uses a local SQLite database via Drift ORM with a Provider-based state management layer.

**Author:** Nicolas Lobos
**Version:** 1.0.0+1
**Dart SDK:** ^3.8.1
**Primary framework:** Flutter (Material Design 3, dark theme)

## Quick Reference Commands

```bash
# Install dependencies
flutter pub get

# Generate Drift database code (required after schema changes)
dart run build_runner build

# Run the application
flutter run

# Run static analysis (linting)
flutter analyze

# Run tests
flutter test
```

## Project Structure

```
lib/
├── main.dart                          # App entry point, Provider setup, theme config
├── database/
│   ├── database.dart                  # Drift schema: 7 tables, migrations, DB connection
│   └── database.g.dart               # Auto-generated Drift code (DO NOT EDIT)
├── models/
│   └── line_item.dart                 # Invoice line item model (JSON serializable)
├── screens/
│   ├── main_screen.dart               # Bottom navigation bar (8 tabs)
│   ├── home_screen.dart               # Todo/task list screen
│   ├── time_tracker/
│   │   ├── time_tracker_screen.dart   # Active timer, recent entries, weekly totals
│   │   ├── add_entry_dialog.dart      # Create time entries (timer or manual)
│   │   └── edit_entry_screen.dart     # Edit existing time entries
│   ├── clients/
│   │   ├── clients_screen.dart        # Client listing
│   │   └── client_edit_screen.dart    # Add/edit clients
│   ├── projects/
│   │   ├── projects_screen.dart       # Projects grouped by client
│   │   └── project_edit_screen.dart   # Add/edit projects with hourly rates
│   ├── expenses/
│   │   ├── expenses_screen.dart       # Expense listing
│   │   └── expense_edit_screen.dart   # Add/edit expenses (incl. mileage)
│   ├── invoices/
│   │   ├── invoices_screen.dart       # Invoice listing
│   │   └── invoice_edit_screen.dart   # Create/edit invoices with line items
│   ├── reports/
│   │   └── reports_screen.dart        # Analytics charts with time period filtering
│   └── settings/
│       └── settings_screen.dart       # Company info, logo, invoice preferences
└── utils/
    └── pdf_generator.dart             # PDF invoice generation with letterhead
```

### Platform directories (native config, rarely modified)

- `android/` - Gradle build config
- `ios/` - Xcode project config
- `macos/` - Xcode project config
- `linux/` - CMake build config
- `windows/` - CMake build config
- `web/` - Web deployment config

## Architecture

### State Management

- **Provider** supplies a singleton `AppDatabase` instance to the entire widget tree
- All screens access the database via `Provider.of<AppDatabase>(context)`

### Data Flow

```
UI Screens (StatefulWidget / StatelessWidget)
  ↕ StreamBuilder watches Drift queries (.watch())
Drift AppDatabase (SQLite)
  ↕ Provider injects singleton instance
App root (main.dart)
```

- Screens use `StreamBuilder` with Drift's `.watch()` for reactive, auto-updating UI
- CRUD operations are performed directly on the database from screen classes
- No separate repository or service layer exists — database access is inline in screens

### Database Schema (Drift, v3)

| Table | Key Relationships | Purpose |
|-------|-------------------|---------|
| `Clients` | Root entity | Client master data (name, email, address, currency) |
| `Projects` | → Clients (cascade delete) | Project tracking with hourly rates |
| `TimeEntries` | → Projects (cascade delete) | Time tracking with billable/billed/logged status |
| `Expenses` | → Projects, → Clients (cascade delete) | Expense tracking with mileage support |
| `Invoices` | → Clients (cascade delete) | Invoices with JSON-serialized line items |
| `Todos` | → Projects (cascade delete) | Task management with priority and estimates |
| `CompanySettings` | Singleton | Company branding (name, address, logo, letterhead) |

**Schema version:** 3 (migrations in `database.dart` `MigrationStrategy`)

### Navigation

- Bottom navigation bar with 8 tabs in `MainScreen`
- `MaterialPageRoute` for detail/edit screens
- Modal dialogs for add entry and delete confirmation

## Key Conventions

### Code Style

- **Linting:** Uses `package:flutter_lints/flutter.yaml` (see `analysis_options.yaml`)
- **Naming:** Standard Dart/Flutter conventions (camelCase for variables/methods, PascalCase for classes)
- **Widget pattern:** StatefulWidget for screens with forms or local state; StatelessWidget where possible
- **Theme:** Custom dark theme — primary: `Colors.deepPurple`, scaffold background: `Color.fromARGB(255, 28, 25, 38)`, cards: black

### Database Changes

1. Modify table definitions in `lib/database/database.dart`
2. Increment `schemaVersion` in `AppDatabase`
3. Add migration logic in `MigrationStrategy.onUpgrade`
4. Regenerate: `dart run build_runner build`
5. **Never** manually edit `database.g.dart`

### File Organization

- Each feature domain has its own subdirectory under `screens/`
- List screens (`*_screen.dart`) and edit screens (`*_edit_screen.dart`) are co-located
- Shared models go in `lib/models/`
- Utility functions go in `lib/utils/`

## Dependencies

### Core

| Package | Purpose |
|---------|---------|
| `drift` | Reactive SQLite ORM — all persistence |
| `sqlite3_flutter_libs` | Bundled SQLite3 native libraries |
| `provider` | State management (DI for AppDatabase) |
| `pdf` / `printing` | PDF invoice generation and display |
| `fl_chart` | Bar charts in reports screen |
| `intl` | Date and currency formatting |
| `file_picker` / `image_picker` | Company logo selection |
| `path_provider` / `path` | File system paths for database |
| `uuid` | Unique ID generation |
| `open_file` | Open generated files natively |

### Dev

| Package | Purpose |
|---------|---------|
| `drift_dev` | Code generation for Drift tables |
| `build_runner` | Build system for code generation |
| `flutter_lints` | Lint rules |
| `flutter_test` | Widget testing framework |

## Testing

- Test directory: `test/`
- Current state: minimal — `widget_test.dart` contains only a template smoke test
- Run with: `flutter test`
- Lint with: `flutter analyze`

## Common Tasks

### Adding a new screen

1. Create a new directory under `lib/screens/<feature>/`
2. Add list screen and edit screen files
3. Register the screen as a tab in `lib/screens/main_screen.dart`

### Adding a new database table

1. Define the table class in `lib/database/database.dart`
2. Add it to the `@DriftDatabase(tables: [...])` annotation
3. Increment `schemaVersion` and add migration logic
4. Run `dart run build_runner build`

### Generating invoices

Invoice PDF generation is handled in `lib/utils/pdf_generator.dart`. Line items are stored as JSON in the `Invoices.lineItemsJson` column and deserialized via `LineItem` model.

## Known Limitations

- No automated CI/CD pipeline (no GitHub Actions workflows)
- Test coverage is minimal (template test only)
- No user authentication — single-user, local-only
- No multi-device sync or cloud backup
- No separate repository/service abstraction layer
- Error handling in screens is basic
