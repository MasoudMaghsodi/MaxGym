# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Android Gradle compilation error `:printing:checkDebugAarMetadata`:
  - Removed outdated native `printing` plugin from `pubspec.yaml` in favor of pure Dart `pdf` + `share_plus` architecture.
  - Upgraded `share_plus` to `^10.1.0` and `pdf` to `^3.11.1`.
  - Configured `android/app/build.gradle.kts` with `compileSdk = 35`, `minSdk = 23`, `targetSdk = 35`, and Java 17.
  - Replaced `PdfGoogleFonts` with direct offline font loading from `assets/fonts/Vazirmatn-*.ttf` and Helvetica fallback in `pdf_export_engine.dart`.
### Added
- Final 3% Product Loops & 100/100 Commercial Sign-Off:
  - Secure athlete RPC tunnel `athlete_submit_workout_log` allowing athletes to submit PRs, RPE, hydration, and sets with 6-digit access code authentication.
  - Secure weekly weight check-in RPC `athlete_submit_weight_checkin` and interactive modal in `AthletePortalScreen` with scale icon in AppBar.
  - Cloud pull of `athlete_workout_logs` in `SupabaseSyncService.syncAllPendingData()` downloading athlete training logs directly into coach device.
  - Athlete Logged Workout Sessions & PRs view on `AthleteDetailScreen` showing day number, date, hydration, and weights moved.
  - Prominent "Copy Day" (`_showDuplicateDayDialog`) button alongside "Add Exercise" in `MasterProgramBuilderScreen`.
  - Immediate `Undo` SnackBar action on exercise deletion in workout builder.
  - 100% comprehensive unit, database, sync, and end-to-end UI test suites passing green across all test files.
- Enterprise Hardening & Needle-Audit Edge Case Resolution:
  - Preserved athlete `email` and `access_code` during profile editing and updates in `athletes_provider.dart`.
  - Advanced input sanitization utilities `toSafeDouble`, `toSafeInt`, and `toSanitizedText` (Anti-XSS, Anti-SQLi, strip control characters) in `number_parser.dart`.
  - Seamless sync and local SQLite storage of athlete historical anthropometric measurements in `security_gate_screen.dart` via `athlete_login_by_code` RPC.
  - Printed athlete access code (`کد ورود اپ: PC-XXXXXX`) on PDF export cover cards in `pdf_export_engine.dart`.
  - Database JSON Backup & Restore dialog and export viewer in `branding_settings_screen.dart`.
  - Table name validation whitelist (`athletes`, `measurement_logs`, `programs`, `chat_messages`, `athlete_workout_logs`) in `LocalAppDatabase.markRecordSynced`.
  - Secure athlete chat RPC routing (`athlete_fetch_chat` & `athlete_send_chat`) preventing access code forgery and data sniff leaks.
  - ProGuard/R8 code shrinking and resource minification configuration with keep rules for Flutter and SQLite native interop in `android/app/build.gradle.kts` and `proguard-rules.pro`.
  - Master all-in-one idempotent SQL migration script (`supabase/migrations/20261110000005_master_all_in_one_and_rpc_chat.sql`) and synced remote schema.
  - Updated all test suites (`unit_bio_and_pdf_test.dart`, `database_and_models_test.dart`, `supabase_api_sync_test.dart`, `app_widget_ui_test.dart`) to 100% green pass.
- Phase 2 Dual-Role (Coach & Athlete Portal) & Audit Gaps Resolution:
  - Athlete Portal (`AthletePortalScreen`) with interactive workout session tracker, PR weight logger, rest countdown timer, water intake gamified counter, and athlete PDF downloads.
  - Mandatory profile completion gate (`_MandatoryAthleteProfileCompletionGate`) enforcing required biometrics before unlocking training.
  - Zero-battery pure text chat (`PureTextChatView`) with lifecycle pausing via `WidgetsBindingObserver`.
  - Dual Login Screen (`CoachAuthScreen`) toggling seamlessly between Coach Mode and Athlete Mode (via 6-character access code `PC-XXXXXX`).
  - Recent Apps background screenshot privacy shield (`_SecurityGateWrapperState`) covering financial/athlete data when backgrounded.
  - Cloud pagination (`.range(offset, offset + pageSize - 1)`) in `SupabaseSyncService` overcoming PostgREST 1000 row limit.
  - Automatic download and bilingual caching of all 873 exercises from GitHub CDN (`ensureGlobal800ExerciseLibraryLoaded`).
  - Program builder Auto-Draft restoration on interruption/call and automatic save on change.
  - Duplicate Day (`_showDuplicateDayDialog`) and Undo SnackBar on exercise removal in `MasterProgramBuilderScreen`.
  - Direct access code display and 1-tap modal text chat in `AthleteDetailScreen`.
  - 4 new automated unit/widget tests in `phase2_dual_role_portal_test.dart` bringing test suite to 26/26 green.
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
