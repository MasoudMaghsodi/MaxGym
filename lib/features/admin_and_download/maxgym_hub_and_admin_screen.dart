import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/config/maxgym_brand_config.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/localization/app_localizations.dart';

// =============================================================================
// ۱. مرکز دانلود آخرین نسخه‌های MaxGym و راهنمای نصب وباپ آیفون (iOS PWA Hub)
// =============================================================================
class MaxGymDownloadAndPwaHubScreen extends StatefulWidget {
  const MaxGymDownloadAndPwaHubScreen({super.key});

  @override
  State<MaxGymDownloadAndPwaHubScreen> createState() =>
      _MaxGymDownloadAndPwaHubScreenState();
}

class _MaxGymDownloadAndPwaHubScreenState
    extends State<MaxGymDownloadAndPwaHubScreen> {
  String _latestVersion = MaxGymBrandConfig.currentAppVersion;
  String _apkUrl = MaxGymBrandConfig.latestAndroidApkUrl;
  String _releaseNotes =
      'نسخه اختصاصی باشگاه MAX GYM با هیت‌مپ سه‌بعدی عضلات، چت زنده و موتور PDF';

  @override
  void initState() {
    super.initState();
    _fetchLiveVersionInfo();
  }

  Future<void> _fetchLiveVersionInfo() async {
    try {
      final row = await SupabaseConfig.clientOrNull
          ?.from('app_control')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (row != null && mounted) {
        setState(() {
          _latestVersion =
              row['latest_version'] as String? ?? _latestVersion;
          _apkUrl = row['apk_download_url'] as String? ?? _apkUrl;
          _releaseNotes =
              row['release_notes_fa'] as String? ?? _releaseNotes;
        });
      }
    } catch (_) {}
  }

  void _openSuperAdminPinGate() {
    final pinCtrl = TextEditingController();
    final isFa = AppStrings.of(context).isFa;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.shieldAlert, color: AppColors.warning),
            const SizedBox(width: 8),
            Text(isFa ? 'ورود به کنسول سوپر-ادمین' : 'Super-Admin Console'),
          ],
        ),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText:
                isFa ? 'رمز مستر توسعه‌دهنده (Master PIN)' : 'Master PIN',
            prefixIcon: const Icon(LucideIcons.keyRound),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isFa ? 'انصراف' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.trim() ==
                  MaxGymBrandConfig.superAdminMasterPin) {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MaxGymSuperAdminScreen(),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('رمز مستر اشتباه است!'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: Text(isFa ? 'ورود ادمین' : 'Unlock'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFa = AppStrings.of(context).isFa;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(isFa
            ? 'مرکز دانلود و نسخه‌های MAX GYM'
            : 'MAX GYM Download & PWA Hub'),
        actions: [
          IconButton(
            tooltip: 'Super-Admin Console',
            icon: const Icon(LucideIcons.terminal, size: 18),
            onPressed: _openSuperAdminPinGate,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // هدر برندینگ باشگاه مکس
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  primary.withOpacity(0.25),
                  const Color(0xFF121614),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: primary, width: 1.5),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    MaxGymBrandConfig.bundledLogoAsset,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(LucideIcons.dumbbell, size: 64, color: primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '${MaxGymBrandConfig.appName} • v$_latestVersion',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _releaseNotes,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ۱. کارت دانلود مستقیم نسخه اندروید (APK)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.smartphone, color: primary, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFa
                              ? 'دانلود نسخه اندروید (فایل نصبی مستقیم APK)'
                              : 'Android Direct APK Download',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _apkUrl,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: _apkUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFa
                                  ? '✅ لینک دانلود مستقیم آخرین نسخه اندروید کپی شد! در مرورگر باز کنید یا برای شاگرد بفرستید.'
                                  : '✅ Direct APK link copied to clipboard!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.download),
                      label: Text(isFa
                          ? 'کپی و دریافت لینک مستقیم APK اندروید'
                          : 'Copy Direct Android APK Link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ۲. کارت وباپلیکیشن آیفون (iOS PWA روی دامنه کلادفلر شما)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.globe,
                          color: Colors.cyanAccent, size: 26),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFa
                              ? 'نسخه ویژه آیفون (iOS PWA) و وب (بدون نیاز به اپ‌استور)'
                              : 'iOS (iPhone) Web-App (PWA)',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🌐 ${MaxGymBrandConfig.pwaWebUrl}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isFa
                              ? '۱. لینک بالا را در مرورگر Safari آیفون باز کنید.\n'
                                  '۲. دکمه Share (مربع با فلش رو به بالا در پایین صفحه) را بزنید.\n'
                                  '۳. گزینه "Add to Home Screen" را انتخاب کنید تا آیکون MAX GYM روی صفحه اصلی آیفون شما نصب شود!'
                              : '1. Open link in Safari on iPhone.\n2. Tap Share button.\n3. Tap "Add to Home Screen".',
                          style: const TextStyle(fontSize: 12, height: 1.6),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: MaxGymBrandConfig.pwaWebUrl));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isFa
                                  ? '✅ آدرس وباپ آیفون (${MaxGymBrandConfig.pwaWebUrl}) کپی شد!'
                                  : '✅ PWA Web URL copied!'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(LucideIcons.copy, size: 18),
                      label: Text(isFa
                          ? 'کپی لینک وباپ آیفون (${MaxGymBrandConfig.activeDomain})'
                          : 'Copy iOS PWA Link'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ۲. پنل فرماندهی سوپر-ادمین داخلی (MaxGym Super-Admin Console)
// شامل کنترل آنی Kill-Switch، تایید/تعلیق مربیان، ریست Device ID و مشاهده کرش‌لاگ‌ها
// =============================================================================
class MaxGymSuperAdminScreen extends StatefulWidget {
  const MaxGymSuperAdminScreen({super.key});

  @override
  State<MaxGymSuperAdminScreen> createState() => _MaxGymSuperAdminScreenState();
}

class _MaxGymSuperAdminScreenState extends State<MaxGymSuperAdminScreen> {
  bool _isLoading = true;
  bool _isAppDisabled = false;
  final _lockReasonCtrl = TextEditingController();
  final _devContactCtrl = TextEditingController();
  final _versionCtrl = TextEditingController();
  final _apkUrlCtrl = TextEditingController();

  List<Map<String, dynamic>> _coaches = [];
  List<Map<String, dynamic>> _crashLogs = [];

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  @override
  void dispose() {
    _lockReasonCtrl.dispose();
    _devContactCtrl.dispose();
    _versionCtrl.dispose();
    _apkUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseConfig.clientOrNull;
      if (client == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final ctrl = await client
          .from('app_control')
          .select()
          .eq('id', 1)
          .maybeSingle();
      if (ctrl != null) {
        _isAppDisabled = ctrl['is_app_disabled'] as bool? ?? false;
        _lockReasonCtrl.text = ctrl['lock_message_fa'] as String? ?? '';
        _devContactCtrl.text = ctrl['developer_contact'] as String? ?? '';
        _versionCtrl.text = ctrl['latest_version'] as String? ?? '1.2.0';
        _apkUrlCtrl.text = ctrl['apk_download_url'] as String? ??
            MaxGymBrandConfig.latestAndroidApkUrl;
      }

      final coachesRes = await client
          .from('coach_profiles')
          .select()
          .order('created_at', ascending: false);
      _coaches = List<Map<String, dynamic>>.from(coachesRes);

      final logsRes = await client
          .from('app_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(30);
      _crashLogs = List<Map<String, dynamic>>.from(logsRes);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _saveGlobalKillSwitchAndVersion() async {
    try {
      await SupabaseConfig.clientOrNull?.rpc(
        'super_admin_update_control',
        params: {
          'p_master_pin': MaxGymBrandConfig.superAdminMasterPin,
          'p_is_disabled': _isAppDisabled,
          'p_lock_message': _lockReasonCtrl.text.trim(),
          'p_dev_contact': _devContactCtrl.text.trim(),
          'p_latest_version': _versionCtrl.text.trim(),
          'p_apk_url': _apkUrlCtrl.text.trim(),
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ تنظیمات سراسری و وضعیت Kill-Switch به صورت زنده روی تمام گوشی‌ها اعمال شد!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateCoachStatus(
      String coachId, bool approve, bool suspend) async {
    await SupabaseConfig.clientOrNull?.rpc(
      'super_admin_set_coach_status',
      params: {
        'p_master_pin': MaxGymBrandConfig.superAdminMasterPin,
        'p_coach_id': coachId,
        'p_approve': approve,
        'p_suspend': suspend,
      },
    );
    await _loadAdminData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('👑 کنسول سوپر-ادمین (مدیریت لایسنس و مربیان)'),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: _loadAdminData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ۱. سوییچ مرگ سراسری (Global Kill-Switch) برای قطع فوری اپ در صورت عدم تسویه حساب
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color:
                          _isAppDisabled ? AppColors.danger : AppColors.success,
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            '🚨 غیرفعال‌سازی و قفل فوری کل اپلیکیشن (Global Kill-Switch)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_isAppDisabled
                              ? 'وضعیت فعلی: کل اپلیکیشن مسدود است!'
                              : 'وضعیت فعلی: اپلیکیشن فعال و باز است'),
                          value: _isAppDisabled,
                          activeColor: AppColors.danger,
                          onChanged: (v) =>
                              setState(() => _isAppDisabled = v),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _lockReasonCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText:
                                'متن پیام مسدودیت (نمایش روی صفحه گوشی در صورت عدم تسویه)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _devContactCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اطلاعات تماس شما (توسعه‌دهنده)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _versionCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'آخرین ورژن اپ'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _apkUrlCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'لینک مستقیم APK'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _saveGlobalKillSwitchAndVersion,
                            icon: const Icon(LucideIcons.zap),
                            label: const Text(
                                'اعمال آنی (Realtime) روی تمام دستگاه‌ها'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ۲. مدیریت و تایید مربیان ثبت‌نام‌شده
                Text(
                  '👥 مربیان ثبت‌نام‌شده (${_coaches.length}):',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ..._coaches.map((c) {
                  final id = c['id'] as String;
                  final approved = c['is_approved'] as bool? ?? false;
                  final suspended = c['is_suspended'] as bool? ?? false;
                  final name =
                      '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('$name (${c['email']})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        suspended
                            ? '⛔ مسدود شده'
                            : (approved
                                ? '✅ تایید شده و فعال'
                                : '⏳ در انتظار تایید شما'),
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          if (!approved || suspended)
                            ElevatedButton(
                              onPressed: () =>
                                  _updateCoachStatus(id, true, false),
                              child: const Text('تایید / فعالسازی'),
                            ),
                          if (!suspended)
                            OutlinedButton(
                              onPressed: () =>
                                  _updateCoachStatus(id, approved, true),
                              child: const Text(
                                'مسدود کردن',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 20),

                // ۳. مانیتورینگ لاگ خطاها (Supabase Telemetry / app_logs)
                Text(
                  '🛠 آخرین لاگ‌های فنی و تلمتری سیستم (${_crashLogs.length}):',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (_crashLogs.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                          '✅ هیچ کرش یا خطای سیستمی در جدول app_logs ثبت نشده است.'),
                    ),
                  )
                else
                  ..._crashLogs.take(10).map((log) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(LucideIcons.bug,
                            color: AppColors.warning, size: 18),
                        title: Text(
                          log['error_message'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${log['platform_info']} • ${(log['created_at'] as String).substring(0, 16)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
