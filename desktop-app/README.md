# Hirall POS — Flutter Desktop Client

Hirall POS Desktop is an offline-first, multi-branch, multi-module point of sale terminal client for Linux, Windows, and macOS.

## Architecture

- **Local Store:** SQLite queried via **Drift** ORM.
- **Offline Sync:** **PowerSync** logical replication client connecting to central PostgreSQL.
- **State Management:** **Flutter Riverpod**.
- **Dynamic Module Gating:** Automatically filters navigation and active tools based on branch entitlements (`Cashier`, `Storekeeping`, `POS Outlets`, `Accounting`, `Waiter`, `Management & HR`).
- **Hardware Integration:** 80mm/58mm ESC/POS thermal receipt printing, barcode scanner listener.

## Running Locally

```bash
# Get dependencies
flutter pub get

# Generate Drift database code (optional)
dart run build_runner build

# Run on Linux Desktop
flutter run -d linux

# Run on Windows / macOS
flutter run -d windows
# or
flutter run -d macos
```
