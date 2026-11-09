# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Phase 1 Dual-Role (Coach & Athlete Portal) Architecture:
  - Persian/Arabic number sanitizer extension (`PersianNumberSanitizer`) preventing parser crashes from mobile keyboards.
  - Bilingual catalog expansion to 60+ offline exercises, 40 sports/Iranian foods, 30 supplements, and GitHub 873 global exercises engine (`SeedCatalogData`).
  - Supabase Phase 1 migration script (`20261110000004_phase1_athlete_portal_chat_logs.sql`) with composite performance indexes, RLS, and RPC functions (`athlete_login_by_code`, `athlete_complete_profile`).
  - Upgraded offline SQLite database (`LocalAppDatabase`) with `access_code` lookup, pure text chat (`chat_messages`), athlete workout log (`athlete_workout_logs`), and auto-draft (`program_drafts`).
  - Two-way sync service updated (`SupabaseSyncService`) with chat and workout logs synchronization.
  - 12 new automated unit tests in `phase1_portal_chat_catalog_test.dart` bringing test suite to 22/22 green.
- Commercial-grade feature set bridging development gaps:
  - Custom Exercise, Food, and Supplement creation in SQLite with search query filtering.
  - Drag-and-drop exercise reordering using `ReorderableListView`.
  - Coach technical notes on exercises, rendered in UI and embedded into PDFs.
  - Program editing mode and cycle cloning mode from athlete detail screen.
  - Quick debt settlement action in dashboard and athlete profile.
  - Coach privacy mode (`👁️`) blurring revenue and pending debt in gym environment.
  - Side-by-side Before/After photo comparison story generator with coach branding.
  - Quick WhatsApp chat deep-linking without saving contact.
  - Direct YouTube video tutorial search QR codes and clickable links in exported PDFs.
  - GitHub Actions automated CI/CD pipeline (`ci_cd_pipeline.yml`) for static analysis, automated testing, and obfuscated release APK build with `--dart-define`.
  - Supabase free-tier 3-day keep-alive cron job (`supabase_keep_alive.yml`) to prevent project pause.
  - Supabase SQL migration for custom catalogs, RLS policies, and templates persistence.
  - Complete two-way sync for custom catalogs (exercises, foods, supplements) in `SupabaseSyncService`.
  - Offline JSON database full backup generator (`exportFullDatabaseToJson`) and AppBar export action.
  - Quick filter chips (`All`, `Unpaid Debt`, `Expiring Programs`) and swipe-to-delete in `AthletesListScreen`.
  - Direct template assignment and customization modal in `TemplatesScreen`.
  - OWASP Mobile Top 10 Hardening:
    - Hardware-encrypted session storage with `flutter_secure_storage` (AES-256 Android Keystore / iOS Keychain).
    - PKCE authorization flow for Supabase Auth.
    - Security Gate Screen with Sign-In, Sign-Up, Pending Admin Approval, and Global/Per-coach Kill-Switch screens.
    - Offline-cached Kill-Switch state preventing Airplane Mode bypass.
    - Sign out action in Settings with complete secure storage purge.
  - Resolved 5 hidden compiler & multi-tenant isolation issues (Needle-Audit):
    - Replaced uppercase icon symbol with `LucideIcons.headphones`.
    - Automated email confirmation trigger in Supabase and isolated custom catalog RLS.
    - Added `clearAllUserDataOnLogout` in SQLite to prevent multi-coach data leakage on shared devices.
    - Prevented sync collision on default seed items by attaching `coach_id` and filtering custom catalog entries.
    - Deferred background sync execution until coach is authenticated and approved via `ref.listen`.
  - Complete UI, Unit, and Database test suite with 100% pass rate.
