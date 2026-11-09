import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../data/local/app_database.dart';
import 'athletes_provider.dart';

class AthleteOnboardingSheet extends ConsumerStatefulWidget {
  final AthleteEntity? existingAthlete;
  const AthleteOnboardingSheet({super.key, this.existingAthlete});

  @override
  ConsumerState<AthleteOnboardingSheet> createState() =>
      _AthleteOnboardingSheetState();
}

class _AthleteOnboardingSheetState
    extends ConsumerState<AthleteOnboardingSheet> {
  int _currentStep = 0; // 0 = Quick Profile, 1 = Body Measurements

  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;

  String _gender = 'male';
  String _fitnessGoal = 'lean_bulk';
  final Set<String> _selectedInjuries = {};

  // کنترلرهای مرحله ۲ (سایزهای بدنی)
  final _bfCtrl = TextEditingController();
  final _shoulderCtrl = TextEditingController();
  final _chestCtrl = TextEditingController();
  final _waistCtrl = TextEditingController();
  final _hipsCtrl = TextEditingController();
  final _bicepsCtrl = TextEditingController();
  final _forearmCtrl = TextEditingController();
  final _thighCtrl = TextEditingController();
  final _calfCtrl = TextEditingController();

  static const List<Map<String, String>> _goals = [
    {'id': 'weight_loss', 'fa': 'چربیسوزی و کات', 'en': 'Fat Loss & Cut'},
    {'id': 'lean_bulk', 'fa': 'عضلهسازی خشک', 'en': 'Lean Muscle Bulk'},
    {'id': 'muscle_gain', 'fa': 'افزایش حجم و وزن', 'en': 'Mass & Strength'},
    {'id': 'maintenance', 'fa': 'تثبیت و تناسب اندام', 'en': 'Maintenance'},
  ];

  static const List<Map<String, String>> _injuryOptions = [
    {'id': 'lower_back', 'fa': 'دیسک / درد کمر', 'en': 'Lower Back Disc'},
    {'id': 'knee', 'fa': 'مینیسک / درد زانو', 'en': 'Knee Injury'},
    {'id': 'shoulder', 'fa': 'آسیب سرشانه (روتاتور)', 'en': 'Shoulder Injury'},
    {'id': 'neck', 'fa': 'دیسک گردن', 'en': 'Neck Disc'},
    {'id': 'wrist', 'fa': 'درد مچ دست / آرنج', 'en': 'Wrist / Elbow Pain'},
  ];

  @override
  void initState() {
    super.initState();
    final ex = widget.existingAthlete;
    _firstNameCtrl = TextEditingController(text: ex?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: ex?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: ex?.phone ?? '');
    _ageCtrl = TextEditingController(text: (ex?.age ?? 25).toString());
    _heightCtrl =
        TextEditingController(text: (ex?.heightCm ?? 175).toStringAsFixed(0));
    _weightCtrl =
        TextEditingController(text: (ex?.weightKg ?? 75).toStringAsFixed(1));
    if (ex != null) {
      _gender = ex.gender;
      _fitnessGoal = ex.fitnessGoal;
      _selectedInjuries.addAll(ex.injuryTags);
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bfCtrl.dispose();
    _shoulderCtrl.dispose();
    _chestCtrl.dispose();
    _waistCtrl.dispose();
    _hipsCtrl.dispose();
    _bicepsCtrl.dispose();
    _forearmCtrl.dispose();
    _thighCtrl.dispose();
    _calfCtrl.dispose();
    super.dispose();
  }

  double? _parseOpt(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _submit() async {
    final isFa = AppStrings.of(context).isFa;
    if (_firstNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              isFa ? 'لطفاً نام ورزشکار را وارد کنید' : 'Please enter first name'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    await ref.read(athletesProvider.notifier).createOrUpdateAthlete(
          existingId: widget.existingAthlete?.id,
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          gender: _gender,
          age: int.tryParse(_ageCtrl.text) ?? 25,
          heightCm: double.tryParse(_heightCtrl.text) ?? 175,
          weightKg: double.tryParse(_weightCtrl.text) ?? 75,
          fitnessGoal: _fitnessGoal,
          injuryTags: _selectedInjuries.toList(),
          bodyFatPercent: _parseOpt(_bfCtrl),
          shoulderCm: _parseOpt(_shoulderCtrl),
          chestCm: _parseOpt(_chestCtrl),
          waistCm: _parseOpt(_waistCtrl),
          hipsCm: _parseOpt(_hipsCtrl),
          bicepsCm: _parseOpt(_bicepsCtrl),
          forearmCm: _parseOpt(_forearmCtrl),
          thighCm: _parseOpt(_thighCtrl),
          calfCm: _parseOpt(_calfCtrl),
        );

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    final isFa = s.isFa;
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.6,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _currentStep == 0
                          ? (isFa
                              ? 'گام ۱: مشخصات پایه و هدف ورزشکار'
                              : 'Step 1: Quick Athlete Profile')
                          : (isFa
                              ? 'گام ۲: سایزگیری آنتروپومتریک (اختیاری)'
                              : 'Step 2: Body Measurements (Optional)'),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _submit,
                      icon: const Icon(LucideIcons.checkCircle2, size: 18),
                      label: Text(isFa ? 'ثبت سریع' : 'Quick Save'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: _currentStep == 0
                      ? _buildStep1(isFa, theme)
                      : _buildStep2(isFa),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: const Border(top: BorderSide(color: Colors.white10)),
                ),
                child: Row(
                  children: [
                    if (_currentStep == 1) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setState(() => _currentStep = 0),
                          child: Text(isFa ? 'بازگشت به گام ۱' : 'Back to Step 1'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (_currentStep == 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _currentStep = 1),
                          icon: const Icon(LucideIcons.ruler, size: 18),
                          label: Text(isFa
                              ? 'افزودن سایز بدنی (گام ۲)'
                              : 'Add Body Sizes (Step 2)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _submit,
                        icon: const Icon(LucideIcons.save, size: 18),
                        label: Text(isFa ? 'ذخیره نهایی' : 'Save Athlete'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildStep1(bool isFa, ThemeData theme) {
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _firstNameCtrl,
              decoration: InputDecoration(
                labelText: isFa ? 'نام *' : 'First Name *',
                prefixIcon: const Icon(LucideIcons.user),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _lastNameCtrl,
              decoration: InputDecoration(
                labelText: isFa ? 'نام خانوادگی' : 'Last Name',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: isFa ? 'شماره موبایل (واتساپ)' : 'Phone Number',
                prefixIcon: const Icon(LucideIcons.phone),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _gender,
              decoration: InputDecoration(
                labelText: isFa ? 'جنسیت' : 'Gender',
              ),
              items: [
                DropdownMenuItem(
                    value: 'male', child: Text(isFa ? 'آقا' : 'Male')),
                DropdownMenuItem(
                    value: 'female', child: Text(isFa ? 'خانم' : 'Female')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'male'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isFa ? 'سن' : 'Age',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _heightCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: isFa ? 'قد (cm)' : 'Height (cm)',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _weightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isFa ? 'وزن (kg)' : 'Weight (kg)',
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      Text(
        isFa ? 'هدف اصلی ورزشکار (تنظیم خودکار ماکروها):' : 'Fitness Goal:',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _goals.map((g) {
          final isSelected = _fitnessGoal == g['id'];
          return ChoiceChip(
            label: Text(isFa ? g['fa']! : g['en']!),
            selected: isSelected,
            selectedColor: theme.colorScheme.primary.withOpacity(0.25),
            onSelected: (_) => setState(() => _fitnessGoal = g['id']!),
          );
        }).toList(),
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          const Icon(LucideIcons.alertTriangle,
              size: 18, color: AppColors.warning),
          const SizedBox(width: 6),
          Text(
            isFa
                ? 'آسیبدیدگیها و محدودیتهای مفصلی (هشدار هوشمند در تمرین):'
                : 'Injuries & Joint Limitations:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _injuryOptions.map((inj) {
          final id = inj['id']!;
          final selected = _selectedInjuries.contains(id);
          return FilterChip(
            label: Text(isFa ? inj['fa']! : inj['en']!),
            selected: selected,
            selectedColor: AppColors.warning.withOpacity(0.25),
            checkmarkColor: AppColors.warning,
            onSelected: (val) {
              setState(() {
                if (val) {
                  _selectedInjuries.add(id);
                } else {
                  _selectedInjuries.remove(id);
                }
              });
            },
          );
        }).toList(),
      ),
    ];
  }

  List<Widget> _buildStep2(bool isFa) {
    Widget sizeField(TextEditingController ctrl, String fa, String en) {
      return TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: isFa ? '$fa (cm)' : '$en (cm)',
          prefixIcon: const Icon(LucideIcons.ruler, size: 18),
        ),
      );
    }

    return [
      TextField(
        controller: _bfCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: isFa
              ? 'درصد چربی بدن - Body Fat % (اختیاری - فعالسازی فرمول Katch-McArdle)'
              : 'Body Fat % (Optional - Enables Katch-McArdle Formula)',
          prefixIcon: const Icon(LucideIcons.percent),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: sizeField(_shoulderCtrl, 'دور سرشانه', 'Shoulders')),
          const SizedBox(width: 12),
          Expanded(child: sizeField(_chestCtrl, 'دور سینه', 'Chest')),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
              child: sizeField(_waistCtrl, 'دور کمر / شکم', 'Waist / Belly')),
          const SizedBox(width: 12),
          Expanded(child: sizeField(_hipsCtrl, 'دور باسن', 'Hips')),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: sizeField(_bicepsCtrl, 'دور بازو', 'Biceps')),
          const SizedBox(width: 12),
          Expanded(child: sizeField(_forearmCtrl, 'دور ساعد', 'Forearm')),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: sizeField(_thighCtrl, 'دور ران', 'Thigh')),
          const SizedBox(width: 12),
          Expanded(child: sizeField(_calfCtrl, 'دور ساق', 'Calf')),
        ],
      ),
    ];
  }
}
