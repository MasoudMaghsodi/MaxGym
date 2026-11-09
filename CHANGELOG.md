# Changelog

All notable changes to this project will be documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
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
  - Complete UI, Unit, and Database test suite with 100% pass rate.
