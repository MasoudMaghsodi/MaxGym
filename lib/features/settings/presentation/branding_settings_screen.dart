import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../../../core/cache/smart_cache_manager.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/branding_provider.dart';
import '../../auth/security_gate_screen.dart';

class BrandingSettingsScreen extends ConsumerStatefulWidget {
  const BrandingSettingsScreen({super.key});

  @override
  ConsumerState<BrandingSettingsScreen> createState() =>
      _BrandingSettingsScreenState();
}

class _BrandingSettingsScreenState
    extends ConsumerState<BrandingSettingsScreen> {
  late TextEditingController _coachNameCtrl;
  late TextEditingController _credentialsCtrl;
  late TextEditingController _gymNameCtrl;
  late TextEditingController _socialCtrl;
  late TextEditingController _tuitionFeeCtrl;
  late TextEditingController _workoutFeeCtrl;
  late TextEditingController _dietFeeCtrl;
  late TextEditingController _supplementFeeCtrl;

  @override
  void initState() {
    super.initState();
    final config = ref.read(brandingProvider);
    _coachNameCtrl = TextEditingController(text: config.coachName);
    _credentialsCtrl = TextEditingController(text: config.coachCredentials);
    _gymNameCtrl = TextEditingController(text: config.gymName);
    _socialCtrl = TextEditingController(text: config.socialHandle);
    _tuitionFeeCtrl =
        TextEditingController(text: config.defaultTuitionFee.toStringAsFixed(0));
    _workoutFeeCtrl =
        TextEditingController(text: config.defaultWorkoutFee.toStringAsFixed(0));
    _dietFeeCtrl =
        TextEditingController(text: config.defaultDietFee.toStringAsFixed(0));
    _supplementFeeCtrl = TextEditingController(
        text: config.defaultSupplementFee.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _coachNameCtrl.dispose();
    _credentialsCtrl.dispose();
    _gymNameCtrl.dispose();
    _socialCtrl.dispose();
    _tuitionFeeCtrl.dispose();
    _workoutFeeCtrl.dispose();
    _dietFeeCtrl.dispose();
    _supplementFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final savedPath = p.join(appDir.path, 'coach_brand_logo.png');
      await File(picked.path).copy(savedPath);

      final current = ref.read(brandingProvider);
      await ref
          .read(brandingProvider.notifier)
          .updateBranding(current.copyWith(logoPath: savedPath));
    }
  }

  Future<void> _saveSettings() async {
    final current = ref.read(brandingProvider);
    final updated = current.copyWith(
      coachName: _coachNameCtrl.text.trim(),
      coachCredentials: _credentialsCtrl.text.trim(),
      gymName: _gymNameCtrl.text.trim(),
      socialHandle: _socialCtrl.text.trim(),
      defaultTuitionFee: double.tryParse(_tuitionFeeCtrl.text) ?? 0,
      defaultWorkoutFee: double.tryParse(_workoutFeeCtrl.text) ?? 0,
      defaultDietFee: double.tryParse(_dietFeeCtrl.text) ?? 0,
      defaultSupplementFee: double.tryParse(_supplementFeeCtrl.text) ?? 0,
    );
    await ref.read(brandingProvider.notifier).updateBranding(updated);

    if (mounted) {
      final s = AppStrings.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.tr('settings_saved')),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(brandingProvider);
    final notifier = ref.read(brandingProvider.notifier);
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.tr('settings')),
        actions: [
          IconButton(
            tooltip: s.tr('app_language'),
            icon: const Icon(LucideIcons.languages),
            onPressed: notifier.toggleLanguage,
          ),
          IconButton(
            tooltip: s.tr('theme_mode'),
            icon: Icon(
              config.themeMode == ThemeMode.dark
                  ? LucideIcons.sun
                  : LucideIcons.moon,
            ),
            onPressed: notifier.toggleThemeMode,
          ),
          IconButton(
            tooltip: s.isFa ? 'خروج امن از حساب' : 'Sign Out',
            icon: const Icon(LucideIcons.logOut, color: AppColors.danger),
            onPressed: () => ref.read(securityGateProvider.notifier).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ۱. بخش لوگو و انتخاب زبان/پوسته
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickLogo,
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              theme.colorScheme.primary.withOpacity(0.15),
                          backgroundImage: config.logoPath != null &&
                                  File(config.logoPath!).existsSync()
                              ? FileImage(File(config.logoPath!))
                              : null,
                          child: config.logoPath == null
                              ? Icon(LucideIcons.camera,
                                  size: 30, color: theme.colorScheme.primary)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.tr('select_logo'),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _pickLogo,
                                  icon: const Icon(LucideIcons.upload, size: 16),
                                  label: Text(s.tr('change_logo')),
                                ),
                                if (config.logoPath != null)
                                  TextButton(
                                    onPressed: () => notifier.updateBranding(
                                        config.copyWith(clearLogo: true)),
                                    child: Text(
                                      s.tr('remove_logo'),
                                      style: const TextStyle(
                                          color: AppColors.danger),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // انتخابگر رنگ سازمانی (Accent Color)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      s.tr('brand_color'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 54,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: AppColors.presets.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final preset = AppColors.presets[index];
                        final isSelected = config.colorPresetId == preset.id;
                        return GestureDetector(
                          onTap: () => notifier.setColorPreset(preset.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: preset.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(
                                color: isSelected
                                    ? preset.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: preset.primary,
                                  child: isSelected
                                      ? const Icon(Icons.check,
                                          size: 14, color: Colors.black)
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.bilingual(preset.nameFa, preset.nameEn),
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ۲. مشخصات برندینگ مربی (چاپ در هدر PDF)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _gymNameCtrl,
                    decoration: InputDecoration(
                      labelText: s.tr('gym_name'),
                      prefixIcon: const Icon(LucideIcons.dumbbell),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _coachNameCtrl,
                    decoration: InputDecoration(
                      labelText: s.tr('coach_name'),
                      prefixIcon: const Icon(LucideIcons.userCheck),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _credentialsCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: s.tr('coach_credentials'),
                      prefixIcon: const Icon(LucideIcons.award),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _socialCtrl,
                    decoration: InputDecoration(
                      labelText: s.tr('instagram_id'),
                      prefixIcon: const Icon(LucideIcons.atSign),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ۳. تعرفه پایه مالی و پکیجها
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.tr('financial_defaults'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tuitionFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('tuition_fee'),
                            prefixIcon: const Icon(LucideIcons.wallet),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _workoutFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('workout_fee'),
                            prefixIcon: const Icon(LucideIcons.clipboardList),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dietFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('diet_fee'),
                            prefixIcon: const Icon(LucideIcons.apple),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _supplementFeeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('supplement_fee'),
                            prefixIcon: const Icon(LucideIcons.pill),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // دکمه پاکسازی کش ۵۰ مگابایتی
          OutlinedButton.icon(
            onPressed: () async {
              await SmartExerciseCacheManager.clearCache();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.tr('cache_cleared'))),
                );
              }
            },
            icon: const Icon(LucideIcons.trash2, size: 18),
            label: Text(s.tr('clear_media_cache')),
          ),
          const SizedBox(height: 20),

          // دکمه ذخیره نهایی
          ElevatedButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(LucideIcons.save),
            label: Text(s.tr('save_settings')),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
