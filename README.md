<div align="center">

<img src="assets/images/maxgym_logo.jpeg" alt="MAX GYM Official Logo" width="220" style="border-radius: 28px; box-shadow: 0 10px 30px rgba(114, 200, 50, 0.4);" />

# 🏋️‍♂️ MAX GYM | Enterprise Coaching & Athlete Portal SaaS
### **NO PAIN NO GAIN • EST. 2019**

[![Flutter](https://img.shields.io/badge/Flutter-3.24%2B-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.4%2B-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![Supabase](https://img.shields.io/badge/Supabase-PostgreSQL%20%2B%20Realtime-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)](https://supabase.com)
[![SQLite](https://img.shields.io/badge/Offline_First-SQLite3_FFI-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![Security](https://img.shields.io/badge/OWASP_Mobile-Top_10_Hardened-72C832?style=for-the-badge&logo=shield&logoColor=black)](https://owasp.org)
[![Platform](https://img.shields.io/badge/Platforms-Android%20%7C%20iOS_PWA%20%7C%20Web%20%7C%20Desktop-FFB300?style=for-the-badge)](#)

🌐 **Live Web & iOS PWA Portal:** [**https://maxgym.privatepath.ir**](https://maxgym.privatepath.ir)  
📥 **Latest Android Release (APK):** [**Download Direct APK**](https://github.com/MasoudMaghsodi/MaxGym/releases/latest/download/MaxGym-Release.apk)

---

[**🇬🇧 English Documentation**](#-english-overview--architecture) | [**🇮🇷 مستندات کامل فارسی**](#-معرفی-و-معماری-سامانه-مکسجیم-فارسی)

</div>

---

# 🇬🇧 English Overview & Architecture

**MAX GYM** is a production-grade, **Offline-First + Realtime** Bilingual (Persian/English) Fitness Coaching, Scientific Bio-Analytics, Workout/Nutrition Planning, and Live Athlete Portal ecosystem built with **Flutter** and **Supabase**.

Engineered specifically for high-pace gym environments with zero-latency local execution (`SQLite3 C-FFI`) and instant cloud synchronization (`Supabase Realtime WebSockets`), MAX GYM bridges the gap between professional bodybuilding coaches and their athletes across Android, iOS (Safari PWA), and Widescreen Desktops.

## ✨ Key Architectural Highlights

| Module | Enterprise Capabilities |
| :--- | :--- |
| **🛡️ OWASP Top-10 Security & Kill-Switch** | Hardware-backed `AES-256` JWT/Refresh token storage (`Android Keystore` / `iOS Keychain`), `PKCE` auth flow, Server-side RLS policies, **Super-Admin Console** with instant **Realtime Global Kill-Switch**, Coach Approval Gate, and OS Recent-Apps Privacy Shield. |
| **⚡ Hybrid Offline-First + Realtime Sync** | 100% functional inside underground gyms with zero internet via direct `SQLite3` + Outbox Sync Queue. Automatically streams live updates via WebSockets when online. |
| **🧬 Scientific Bio-Calculator Engine** | Automated calculation of **BMI**, **WHtR (Waist-to-Height Ratio)**, **BMR & TDEE** (auto-switching between *Mifflin-St Jeor* and *Katch-McArdle LBM*), Goal-adjusted **Macros (Protein, Carbs, Fats)**, **Dietary Fiber**, **Hydration**, and **Epley 1RM**. |
| **🏋️ Macro-to-Micro 3D Workout Builder** | Interactive **3D Muscle Heatmap Anatomy** (Anterior/Posterior rotation), **870+ Global Exercise Database** with automatic Persian translation, 50MB LRU Smart Media Cache, Drag-and-Drop reordering, **Supersets / Drop-sets**, Tempo (`3-1-1-0`), Injury Conflict Warnings, Duplicate Day, Undo, and **Auto-Draft** recovery. |
| **🥗 High-Speed Diet & Supplement Matrix** | 6 Meal slots with **"OR" Food Alternatives** logic, Iranian & International bodybuilding food catalog, 35+ Supplements, Vitamins & Minerals catalog, and custom coach catalog CRUD. |
| **📱 Live Athlete Portal & Pure-Text Chat** | Multi-method athlete login (**6-Digit Access Code `PC-XXXXXX`**, Phone, or Email), Mandatory 1-time Profile Completion Gate, Dual High-Res Start/End Pose Gallery with pinch-to-zoom, Built-in Rest Timer, Weight/PR Logger, Water Tracker, and **Zero-Battery-Drain Live WebSocket Chat**. |
| **📄 Vector RTL/LTR Custom PDF Engine** | Instant vector PDF generation in **Bilingual**, **Persian (RTL)**, or **English (LTR)** modes with Solar Hijri (`Shamsi`) & Gregorian dates, Brand Header, Bio & Anthropometric tables, and large Start/End exercise pose thumbnails. Auto-named as `[Athlete_Name]_[Shamsi_Date].pdf`. |

---

## 🏗️ System Architecture Diagram

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                     MAX GYM PRESENTATION LAYER (FLUTTER)                     │
│  ┌─────────────────────┐  ┌──────────────────────┐  ┌─────────────────────┐  │
│  │   Coach Command     │  │  Live Athlete Portal │  │ Super-Admin Console │  │
│  │  (3D Builder / CRM) │  │ (Workout / Chat/H2O) │  │ (Kill-Switch / Logs)│  │
│  └──────────┬──────────┘  └──────────┬───────────┘  └──────────┬──────────┘  │
└─────────────┼────────────────────────┼─────────────────────────┼─────────────┘
              │                        │                         │
              ▼                        ▼                         ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                 STATE MANAGEMENT & SECURITY GATE (RIVERPOD)                  │
│   • OWASP Input Sanitizer (Anti-XSS / Anti-SQLi / Persian Digit Normalizer)  │
│   • Hardware-Encrypted Session Vault (FlutterSecureStorage AES-GCM)          │
│   • Custom 50MB LRU Exercise Image CacheManager                              │
└─────────────────────────┬──────────────────────────────┬─────────────────────┘
                          │                              │
        [Native Android / Desktop]               [Web / iOS PWA & Cloud]
                          ▼                              ▼
         ┌────────────────────────────────┐   ┌────────────────────────────────┐
         │   LOCAL SQLITE3 ENGINE (FFI)   │◄─►│   SUPABASE CLOUD & REALTIME    │
         │  • Sub-2ms Offline Queries     │   │  • PostgreSQL + Strict RLS     │
         │  • Auto-Draft & Outbox Queue   │   │  • WebSocket Realtime Streams  │
         │  • Full JSON Backup & Restore  │   │  • Secure PL/pgSQL RPC Tunnels │
         └────────────────────────────────┘   └────────────────────────────────┘
```

---

<div dir="rtl" align="right">

# 🇮🇷 معرفی و معماری سامانه مکس‌جیم (فارسی)

**مکس‌جیم (MAX GYM)** یک پلتفرم جامع، فوق‌سریع و دوزبانه (فارسی/انگلیسی) برای **مدیریت هوشمند مربیان بدنسازی، طراحی علمی برنامه‌های تمرینی، غذایی و مکمل، و پرتال آنلاین ورزشکاران** است که به صورت اختصاصی با هویت بصری باشگاه مکس طراحی و مهندسی شده است.

این سامانه با ترکیب معماری **Offline-First (کارکرد ۱۰۰٪ آفلاین در محیط باشگاه بدون اینترنت)** و **Realtime WebSocket (همگام‌سازی زنده و بلادرنگ در کسری از ثانیه)**، روی تمامی دستگاه‌ها شامل **اندروید، آیفون (وب‌اپلیکیشن پیشرونده PWA بدون نیاز به اپ‌استور)، تبلت و لپ‌تاپ‌های عریض** اجرا می‌شود.

---

## 🔥 ویژگی‌ها و قابلیت‌های کلیدی سامانه

### ۱. پنل فرماندهی مربی (Coach Command Center)
* **ثبت‌نام ۲ مرحله‌ای و پرونده آنتروپومتریک:** ثبت سریع شاگرد همراه با تگ‌های آسیب‌دیدگی (دیسک کمر، مینیسک زانو، آسیب سرشانه و...) و ثبت تاریخچه سایزهای بدنی به همراه نمودارهای خطی و راداری (`fl_chart`).
* **موتور محاسبات علمی فیزیولوژی ورزشی:** محاسبه خودکار شاخص توده بدنی (**BMI**)، نسبت دور کمر به قد (**WHtR** برای تشخیص دقیق توده عضلانی از چربی احشایی)، متابولیسم پایه (**BMR** با سوییچ هوشمند بین فرمول‌های *Mifflin-St Jeor* و *Katch-McArdle*)، کالری هدف (**TDEE**)، گرم دقیق پروتئین، کربوهیدرات، چربی سالم، فیبر، آب مصرفی و ماشین‌حساب رکورد یک تکرار بیشینه (**1RM**).
* **طراح تمرین ماکرو و میکرو با هیت‌مپ سه‌بعدی عضلات:**
  * نمایش **آناتومی سه‌بعدی چرخان بدن (3D Muscle Heatmap)** با درخشش نئونی عضلات هدف.
  * بانک غنی بیش از **۸۷۰ حرکت استاندارد جهانی** با ترجمه خودکار فارسی و تصاویر بزرگ شروع و پایان حرکت + امکان افزودن حرکت سفارشی توسط مربی.
  * پشتیبانی از **سوپرست، تری‌ست، دراپ‌ست**، تنظیم تمپو (`3-1-1-0`)، استراحت بین ست، یادداشت فنی مربی، جابجایی ترتیب حرکات با **Drag & Drop**، کپی کل روز تمرینی (**Duplicate Day**)، بازگردانی حذف (**Undo**) و **ذخیره خودکار پیش‌نویس (Auto-Draft)**.
  * **هشدار هوشمند آسیب‌دیدگی:** نمایش اخطار خودکار در صورت انتخاب حرکتی که با آسیب‌دیدگی شاگرد تداخل دارد.
* **طراح سریع رژیم غذایی و ماتریس مکمل‌ها و ویتامین‌ها:**
  * ۶ وعده غذایی با پشتیبانی از منطق **«جایگزین غذایی (یا / OR)»** و بانک کامل غذاهای ایرانی و ورزشی.
  * بانک جامع بیش از **۳۵ مکمل ورزشی، ویتامین و مینرال** با دوز و زمان مصرف استاندارد.
* **مدیریت مالی، پکیج‌ها و حالت حریم خصوصی (Privacy Mode):**
  * محاسبه خودکار شهریه باشگاه + هزینه برنامه تمرین/تغذیه/مکمل، لیست بدهکاران، تسویه ۱ کلیکی و دکمه **👁️ مخفی‌سازی ارقام مالی (`••••••`)** هنگامی که شاگرد کنار مربی حضور دارد.
* **موتور خروجی PDF برداری و سفارشی:**
  * تولید آنی فایل PDF با لوگوی باشگاه مکس، تاریخ **شمسی و میلادی**، کد ورود اختصاصی شاگرد، جداول علمی ماکروها و تصاویر واضح شروع و پایان هر حرکت با نام‌گذاری خودکار `[نام_ورزشکار]_[تاریخ_شمسی].pdf`.

---

### ۲. پرتال آنلاین و تعاملی ورزشکار (Live Athlete Portal)
* **ورود چندگانه و آسان:** ورود ورزشکار با **کد اختصاصی ۶ رقمی (`PC-XXXXXX`)**، **شماره موبایل** یا **ایمیل** + گیت تکمیل یکباره‌ی پرونده ورزشی در اولین ورود.
* **همگام‌سازی ۱۰۰٪ زنده (Realtime):** به محض اینکه مربی برنامه‌ای را ذخیره یا ویرایش کند، بدون نیاز به رفرش دستی روی صفحه گوشی ورزشکار ظاهر می‌شود.
* **اجرای تعاملی تمرین در باشگاه:** نمایش تصاویر بزرگ دوتایی (شروع و پایان حرکت) با قابلیت **زوم تمام‌صفحه**، تیک زدن ست‌ها، **تایمر معکوس استراحت بین ست**، ثبت رکورد وزنه‌های زده‌شده و ارسال گزارش جلسه برای مربی.
* **کنتور آبرسانی و چت زنده با مربی:** ثبت لیوان‌های آب روزانه و **چت متنی خالص و بلادرنگ (Live WebSocket Chat)** با مربی با مصرف باتری و رم نزدیک به صفر.

---

### ۳. کنسول سوپر-ادمین و امنیت سایبری (OWASP Hardened & Super-Admin)
* **کنسول سوپر-ادمین داخلی:** دسترسی مستقیم از بالای صفحه اول با رمز مستر توسعه‌دهنده جهت **تایید یا مسدودسازی مربیان**، مشاهده **لاگ خطاهای سیستم (`Supabase Telemetry / app_logs`)** و مدیریت لینک آخرین نسخه.
* **سوییچ مرگ سراسری بلادرنگ (Realtime Global Kill-Switch):** امکان قفل کردن آنی کل اپلیکیشن از راه دور در صورت عدم تسویه حساب یا پایان لایسنس، همراه با کش شدن قفل در حافظه رمزنگاری‌شده سخت‌افزاری (`Keystore`) برای جلوگیری از دور زدن با حالت پرواز.

</div>

---

## 🚀 Quick Start, Build & Deployment

### 1. Run Locally
```bash
# Fetch dependencies
flutter pub get

# Run automated Unit, SQLite DB, Supabase Contract & Widget UI tests
flutter test

# Run on connected device / emulator
flutter run
```

### 2. Build Production Obfuscated Android APK
```bash
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=APP_DOMAIN=maxgym.privatepath.ir \
  --dart-define=GITHUB_REPO=MasoudMaghsodi/MaxGym
```

### 3. Build Web / iOS PWA
```bash
flutter build web --release \
  --base-href "/" \
  --dart-define=APP_DOMAIN=maxgym.privatepath.ir \
  --dart-define=GITHUB_REPO=MasoudMaghsodi/MaxGym
```

---

<div align="center">
  <b>Engineered with Precision for MAX GYM • 2019–2026</b><br/>
  <i>All Rights Reserved © Masoud Maghsoudi</i>
</div>
