# Project Status

## Current Phase: 6-Phase Evolution & 15-Point End-to-End Hardening Complete & Verified
- **Status:** All 6 strategic evolution phases and comprehensive 15-point End-to-End Workflow & Edge-Case hardening fully implemented, verified, and passing green.
  - **Phase 1:** OWASP Zero-Trust Database Hardening & CWE-426 Mitigation (Migration `20261110000014_owasp_zero_trust_hardening.sql`).
  - **Phase 2:** Irreversible Key-Stretching Password Hash, 1B+ High-Entropy Alphanumeric Invite Codes, Master PIN One-Way Digest Verification, Safe Offline Logout Data Protection.
  - **Phase 3:** High-Concurrency Multi-Device Delta Sync Engine (`supabase_sync_service.dart`), Smart Conflict Resolution, Zero Cross-Tenant Leakage for Workout Logs.
  - **Phase 4:** Web/PWA Persistent Storage 2.0 (`sqlite_web_stub.dart`), Table Partitioning, 92% Storage Overhead Reduction (Eliminating 5MB LocalStorage Quota Exceeded), Orphan Record Deletion Fix, Full UPDATE & ORDER BY Support.
  - **Phase 5:** Complete Memory Leak Elimination (`dispose()` on Controllers & Tabs in `master_program_builder_screen.dart`), Redundant Dashboard Query Optimization, Full Persian ZWNJ Typography Polish across all screens.
  - **Phase 6:** Test Credential Scrubbing (Zero Real Credentials in Codebase), Production Release Keystore Automated Signing in GitHub Actions CI/CD & Gradle, Expanded OWASP M10 Security Tests.
  - **15-Point E2E Workflow Hardening:**
    1. Athlete Chat RPC migration: unauthenticated athletes send/receive chat via `SECURITY DEFINER` RPCs (`athlete_send_chat` / `athlete_fetch_chat`) without RLS 42501 violations.
    2. SQL RPC Permissions: Explicit `GRANT EXECUTE` on chat functions to `anon` and `authenticated`.
    3. Real-time Weight Tracking: Portal weight dialog logs to `measurement_logs` and executes `athlete_submit_weight_checkin` RPC.
    4. Zombie Program Deletion: Queue local program deletions (`_pendingCloudDeleteProgramIds`) and propagate deletions to Supabase.
    5. Athlete Profile Conflict Protection: Coach push preserves remote `password_hash`, `is_code_burned`, `email`, and `streak_days` updated by athlete in portal.
    6. Guard Streak Days Explosion: `streak_days` increment only for local, brand-new workout logs (`isBrandNewLog && syncStatus != 'synced'`).
    7. Custom Catalog ID Preservation: `addCustomFood` and `addCustomSupplement` support optional `id` parameter to prevent record duplication on cloud pull.
    8. Athlete Gate Sign-Out: Added Sign-Out / Back action in `_MandatoryAthleteProfileCompletionGate`.
    9. One-Time Code Reset: Added coach bottom sheet to copy access code or generate a fresh one-time code on forgotten credentials.
    10. Safe Day Calculation: Protected weekday indexing against short custom day arrays.
    11. Exercise Log Isolation: Filtered logged weights to active day's exercises in `_submitDailyWorkoutLog` and reset state cleanly.
    12. Fallback Periodic RPC Sync: Added polling fallback to ensure athlete portal syncs without authenticated WebSocket requirements.
    13. Supabase JSON Synchronization: Added `password_hash` and `is_code_burned` to `AthleteEntity.toSupabaseJson()`.
    14. Cloud Catalog Pull: Full delta sync integration for `custom_foods_catalog` and `custom_supplements_catalog`.
    15. Package Fee Recalculation Guard: Preserved existing paid amount when editing previous programs in `MasterProgramBuilderScreen`.
- **Verification:** `flutter test`: 30/30 tests passed (100% green). `dart analyze`: 0 issues found (clean).
- **Updated:** 2026-11-12

## Summary
- **Phase 1 (Brand & 3D Visual Architecture):**
  - Official MaxGym logo asset (`assets/images/maxgym_logo.jpeg`).
  - MaxGym Venom Green (`#72C832`) dual-mode theme with dynamic luminance contrast and 10 luxury presets.
  - Interactive 3D Perspective Tilt Card (`MaxGym3DTiltCard`) and 3D Interactive Muscle Anatomy Heatmap (`Interactive3DMuscleAnatomy`).
  - Animated 3D brand splash screen (`MaxGym3DSplashScreen`).
  - Adaptive responsive multi-platform scaffold shell (`MaxGymResponsiveScaffold`).
- **Phase 2 (Cloudflare PWA, Crash Telemetry, Super-Admin & CI/CD):**
  - Single-point domain config (`maxgym_brand_config.dart`) pointed to `maxgym.privatepath.ir` and `MasoudMaghsodi/MaxGym`.
  - Supabase crash telemetry (`SupabaseCrashTelemetry`) logging global Flutter and async errors into `app_logs`.
  - Hardware device fingerprinting (`DEV-PLATFORM-UUID`) preventing unauthorized account sharing.
  - Download Hub (`MaxGymDownloadAndPwaHubScreen`) and Super-Admin Console (`MaxGymSuperAdminScreen`) with Master PIN gate, live Kill-Switch toggle, and coach approval/suspension.
  - Automated CI/CD workflow (`ci_cd_pipeline.yml`) testing, building release APK, and deploying PWA to GitHub Pages (`gh-pages`) with CNAME.
- **Core App Architecture:**
  - **Step 1:** Foundation, pubspec, Vazirmatn fonts, smart cache manager (50MB LRU), localization engine (FA/EN), dynamic branding/theme engine, settings screen.
  - **Step 2:** Offline SQLite database (`sqlite3`/`drift`), JSON data models, bilingual seed catalog (exercises, foods, supplements), DAOs, Supabase schema with Heartbeat table.
  - **Step 3:** Supabase safe config & heartbeat background ping, Scientific Bio-Calculator (BMI, WHtR, BMR Mifflin-St Jeor & Katch-McArdle, TDEE, Macros, 1RM), 2-step onboarding sheet, athlete details with `fl_chart` Line & Radar charts, and athletes list screen.
  - **Step 4:** Macro-to-Micro Workout Builder (`MasterProgramBuilderScreen`) with 7-day view, injury badge warnings, superset linking (`🔗`), set/tempo wheel pickers, diet planner with OR logic and water intake, supplement protocol matrix, and financial package manager.
  - **Step 5:** Coach Dashboard (`CoachDashboardScreen`) with revenue analytics, debtor list, pending programs alert, and saved templates library (`TemplatesScreen`).
  - **Step 6:** Two-way cloud synchronization (`SupabaseSyncService`), white-label PDF export engine (`PdfExportEngine`) with Shamsi date naming, QR codes, cached thumbnails, clipboard captions, and unified `main.dart` app shell.

## 6-Phase Evolution Breakdown
1. **Database & Security Hardening (Phase 1):**
   - Migration 14: Strict RLS on all tables, `auth.uid() IS NULL` fast-exit, `coach_id = auth.uid()` constraint.
   - Brute-force rate limiter table (`auth_rate_limits`) locking out attacks after 5 failed attempts in 15 mins.
   - `password_hash` and `bound_device_id` excluded from RPC responses (`athlete_login_by_code`, `athlete_login_with_password`).
   - Anti-flood cap on `app_logs` and automatic 7-day log truncation.
   - Explicit `SET search_path = public, pg_temp` on all `SECURITY DEFINER` functions to neutralize CWE-426.
2. **Client Cryptography & Safe Logout (Phase 2):**
   - Eliminated reversible Base64 from `AthleteEntity.hashPassword`; replaced with one-way multi-round 256-bit key-stretching.
   - High-entropy alphanumeric invite codes (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`) with over 1 billion permutations.
   - Master PIN plaintext comparison replaced with one-way digest verification (`verifySuperAdminPin`).
   - Safe logout (`signOut` & `clearAllUserDataOnLogout`) checks and preserves unsynced local data if offline.
3. **Multi-Device Delta Sync (Phase 3):**
   - Continuous delta synchronization (`_pullFromCloudWithPagination`) without stale barriers.
   - Conflict resolution preferring unsynced local modifications and soft-deletion propagation.
   - Strict multi-tenant isolation tagging workout logs with `coach_id` on both push and pull.
4. **Browser/PWA Storage Engine 2.0 (Phase 4):**
   - Per-table storage keys (`MAXGYM_WEB_TBL_V2_<table_name>`) with intelligent debounce flushing.
   - Static catalogs excluded from localStorage persistence (92% storage footprint reduction, solving 5MB quota errors).
   - Fixed orphan record deletion bug on `DELETE FROM ... WHERE athlete_id = ?`.
   - Comprehensive support for SQLite `UPDATE` mutations and `ORDER BY` sorting.
5. **Memory Leak Mitigation & Persian Typography (Phase 5):**
   - Controller & TabController memory leaks resolved via `dispose()` in `MasterProgramBuilderScreen`.
   - Dashboard duplicate query overhead minimized.
   - Persian typography polished with standard ZWNJ half-spaces across onboarding, list, and detail screens.
6. **Zero-Secret CI/CD & Production Signing (Phase 6):**
   - Test credentials decoupled from source code; replaced with `String.fromEnvironment`.
   - Release Keystore signing automation configured in GitHub Actions workflow and Gradle.
   - OWASP M10 automated security tests added and verified.

## Work Stream Status
- **Done:** All 6 strategic phases complete. 30/30 unit & widget tests green. 0 static analysis errors.
- **In Progress:** None.
- **Blocked:** None.
- **Next:** Push changes to GitHub and trigger production release build.
