# Project Status

## Current Phase: 100/100 Production-Ready Coach & Athlete Commercial Ecosystem
- **Status:** Complete closed-loop dual-role ecosystem (Coach & Athlete Portal) with 2-way workout log and weight check-in RPCs, live PR logging, athlete check-ins in coach profile, copy day & undo builder actions, 49/49 automated tests passing green, 0 analysis issues.
- **Updated:** 2026-11-10

## Summary
- **Step 1:** Foundation, pubspec, Vazirmatn fonts, smart cache manager (50MB LRU), localization engine (FA/EN), dynamic branding/theme engine, settings screen.
- **Step 2:** Offline SQLite database (`sqlite3`/`drift`), JSON data models, bilingual seed catalog (exercises, foods, supplements), DAOs, Supabase schema with Heartbeat table.
- **Step 3:** Supabase safe config & heartbeat background ping, Scientific Bio-Calculator (BMI, WHtR, BMR Mifflin-St Jeor & Katch-McArdle, TDEE, Macros, 1RM), 2-step onboarding sheet, athlete details with `fl_chart` Line & Radar charts, and athletes list screen.
- **Step 4:** Macro-to-Micro Workout Builder (`MasterProgramBuilderScreen`) with 7-day view, injury badge warnings, superset linking (`🔗`), set/tempo wheel pickers, diet planner with OR logic and water intake, supplement protocol matrix, and financial package manager.
- **Step 5:** Coach Dashboard (`CoachDashboardScreen`) with revenue analytics, debtor list, pending programs alert, and saved templates library (`TemplatesScreen`).
- **Step 6:** Two-way cloud synchronization (`SupabaseSyncService`), white-label PDF export engine (`PdfExportEngine`) with Shamsi date naming, QR codes, cached thumbnails, clipboard captions, and unified `main.dart` app shell.
- **Production-Grade Commercial Features:**
  - **Custom Catalog CRUD:** Coaches can add custom exercises, custom foods, and custom supplements dynamically to SQLite, with live bilingual searching.
  - **Reorderable Workout Split:** Drag-and-drop reordering (`ReorderableListView`) of exercises in workout days for pre-exhaustion and custom sequencing.
  - **Coach Technical Notes:** Per-exercise notes persisted and printed directly in generated PDFs.
  - **Program Editing & Cloning:** Edit existing athlete programs or clone them for a new cycle with 1 tap.
  - **Quick Debt Settlement:** 1-tap debt settlement on debtor cards in the dashboard and athlete profiles, instantly updating Outbox sync queue.
  - **Coach Privacy Mode:** 1-tap blur/masking (`******`) for revenue and debtor amounts on the dashboard in the gym.
  - **Before/After Transformation Story Maker:** Side-by-side photo comparison with coach branding and athlete stats, exportable directly to Instagram stories without cloud bloat.
  - **Direct WhatsApp Deep-Linking:** 1-tap link to athlete's WhatsApp chat without saving their phone number to contacts.
  - **Tutorial Video QR Codes:** QR codes in PDFs dynamically link to YouTube exercise tutorials.

## Work Stream Status
- **Done:**
  - Steps 1 through 6 fully integrated.
  - Commercial feature upgrades completed across 5 core files.
  - Closed 4 final technical gaps (sync, backup, quick filters, template assignment).
  - OWASP Mobile Top 10 Hardening & Needle-Audit Resolution:
    - Fixed Lucide icon naming (`headphones`).
    - Multi-coach catalog isolation with `coach_id` filtering on sync.
    - Added SQLite data wipe on coach logout (`clearAllUserDataOnLogout`) preventing on-device data leakage.
    - Supabase email auto-confirmation trigger and RLS isolation.
    - Gated sync execution post-authorization via `ref.listen(securityGateProvider, ...)`.
    - Hardware Keystore / Keychain AES-256-GCM encryption for JWT and session tokens (`flutter_secure_storage`).
    - PKCE authorization flow against code interception and replay attacks.
    - Security Gate wrapper (`SecurityGateWrapper`) covering Login, Sign-up, Pending Admin Approval, and App Suspended Kill-Switch.
    - Server-side PostgreSQL RLS function `public.is_active_approved_coach()` preventing unauthorized API bypass.
    - Offline-cached Kill-Switch state preventing bypass via Airplane mode.
    - Sign out and secure key destruction action in Settings.
  - Dual-Role Upgrade (Phase 1 & Phase 2 Complete):
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
    - Persian/Arabic number sanitizer extension (`PersianNumberSanitizer` in `lib/core/utils/number_parser.dart`).
    - Bilingual catalog enriched to 60+ offline exercises, 40 sports & Iranian foods, 30 supplements, and GitHub 873 global exercises engine (`SeedCatalogData`).
    - Supabase Phase 1 & 2 migration script (`supabase/migrations/20261110000004_phase1_athlete_portal_chat_logs.sql`) with composite performance indexes, RLS, and RPC functions (`athlete_login_by_code`, `athlete_complete_profile`).
    - Upgraded offline SQLite database (`lib/data/local/app_database.dart`) with `access_code` lookup, pure text chat (`chat_messages`), athlete workout log (`athlete_workout_logs`), and auto-draft (`program_drafts`).
    - Two-way sync service updated (`lib/data/remote/supabase_sync_service.dart`) with chat and workout logs synchronization.
    - Test suite expanded to 26 tests across 6 files, all passing green.
  - Comprehensive test suite passing with 100% green tests.
  - Static analysis clean (0 errors, 0 warnings, 0 infos).
  - GitHub Actions CI/CD pipeline and Supabase free-tier keep-alive cron active.
  - Supabase versioned migration scripts saved and ready.
- **In Progress:** None
- **Blocked:** None
- **Next:** Live testing on physical Android device or desktop emulator.
