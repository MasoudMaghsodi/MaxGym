# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
- Virtual product team structure, project rules, and subagent configurations.
- Base repository setup with documentation scaffolding and security guardrails (`.gitignore`).
- Step 1: Branding configuration, theme engine, localization (FA/EN), 50MB smart LRU exercise cache, settings screen.
- Step 2: Local SQLite3 database with Outbox Queue, bilingual catalog seeds, DAOs, Supabase Postgres schema with heartbeat ping table.
- Step 3: Scientific bio-calculator (BMI, WHtR, BMR, TDEE, macros, 1RM), 2-step onboarding sheet, athlete details screen with Line/Radar charts, and athletes directory.
- Step 4: `MasterProgramBuilderScreen` featuring 7-day macro workout planning, injury badge warnings, superset linking, tempo/reps bottom sheets, high-speed diet planner with OR logic and water intake, supplement protocol matrix, and financial package manager.
- Step 5: `CoachDashboardScreen` with business intelligence (monthly revenue, pending programs alert, debtor tracking) and `TemplatesScreen` for reusable program management.
- Step 6: `SupabaseSyncService` for two-way synchronization and heartbeat keep-alive, `PdfExportEngine` with dynamic Shamsi file naming, QR code generation, embedded Vazirmatn fonts, pose thumbnails, auto-cleanup of temp files, and unified `main.dart` app shell.
- Unit and widget test suite covering bio calculations, database operations, template saving, and app smoke testing.

### Fixed
- Fixed foreign key UUID constraint when saving program templates.
- Preserved original athlete `createdAt` timestamp during profile updates.
- Added offline fallback for PDF font loading (`pw.Font.helvetica`).
- Added Android `INTERNET` permission in `AndroidManifest.xml`.
