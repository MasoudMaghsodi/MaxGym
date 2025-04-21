import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:max_gym/data/models/athlete.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/widgets/custom_card.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../l10n/app_localizations.dart';

class AthleteProfileScreen extends ConsumerStatefulWidget {
  final Athlete athlete;

  const AthleteProfileScreen({super.key, required this.athlete});

  @override
  ConsumerState<AthleteProfileScreen> createState() =>
      _AthleteProfileScreenState();
}

class _AthleteProfileScreenState extends ConsumerState<AthleteProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final _goalWeightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  final _measurementTypeController = TextEditingController();
  final _measurementValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _goalWeightController.text = widget.athlete.goalWeight?.toString() ?? '';
    _heightController.text = widget.athlete.height?.toString() ?? '';
    _bodyFatController.text = widget.athlete.bodyFat?.toString() ?? '';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _goalWeightController.dispose();
    _heightController.dispose();
    _bodyFatController.dispose();
    _measurementTypeController.dispose();
    _measurementValueController.dispose();
    super.dispose();
  }

  Future<void> _updateGoalWeight() async {
    final goalWeight = double.tryParse(_goalWeightController.text);
    if (goalWeight != null) {
      await ref
          .read(isarServiceProvider)
          .updateGoalWeight(widget.athlete.supabaseId!, goalWeight);
      ref
          .read(athleteProvider.notifier)
          .updateGoal(widget.athlete.supabaseId!, goalWeight);
      setState(() {
        widget.athlete.goalWeight = goalWeight;
      });
    }
  }

  Future<void> _updateMeasurements() async {
    final height = double.tryParse(_heightController.text);
    final bodyFat = double.tryParse(_bodyFatController.text);
    final updatedAthlete = widget.athlete
      ..height = height
      ..bodyFat = bodyFat;
    await ref.read(isarServiceProvider).updateAthlete(updatedAthlete);
    await ref.read(supabaseServiceProvider).updateAthlete(updatedAthlete);
    ref.read(athleteProvider.notifier).updateAthlete(updatedAthlete);
  }

  Future<void> _addMeasurement() async {
    final type = _measurementTypeController.text;
    final value = double.tryParse(_measurementValueController.text);
    if (type.isNotEmpty && value != null) {
      final measurement = Measurement()
        ..type = type
        ..value = value
        ..date = DateTime.now().toIso8601String();
      final updatedAthlete = widget.athlete..measurements.add(measurement);
      await ref.read(isarServiceProvider).updateAthlete(updatedAthlete);
      await ref.read(supabaseServiceProvider).updateAthlete(updatedAthlete);
      ref.read(athleteProvider.notifier).updateAthlete(updatedAthlete);
      _measurementTypeController.clear();
      _measurementValueController.clear();
    }
  }

  Future<void> _deleteWorkoutPlan(String supabaseId) async {
    try {
      await ref.read(supabaseServiceProvider).deleteWorkoutPlan(supabaseId);
      await ref.read(isarServiceProvider).deleteWorkoutPlan(supabaseId);
      ref
          .read(workoutPlanProvider(widget.athlete.supabaseId!).notifier)
          .deletePlan(supabaseId);
      await ref.read(firebaseServiceProvider).logEvent(
          name: 'workout_plan_deleted', parameters: {'supabaseId': supabaseId});
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Future<void> _markWorkoutCompleted(String supabaseId) async {
    try {
      final plan = await ref
          .read(isarServiceProvider)
          .getWorkoutPlans(widget.athlete.supabaseId!)
          .then((plans) =>
              plans.firstWhere((plan) => plan.supabaseId == supabaseId));
      plan.status = 'completed';
      await ref.read(supabaseServiceProvider).updateWorkoutPlan(plan);
      await ref.read(isarServiceProvider).updateWorkoutPlan(plan);
      ref
          .read(workoutPlanProvider(widget.athlete.supabaseId!).notifier)
          .updatePlan(plan);
    } catch (e) {
      await ref.read(firebaseServiceProvider).logError(e.toString());
    }
  }

  Widget _getAvatar() {
    final gender = widget.athlete.gender?.toLowerCase();
    if (gender == 'female') {
      return Image.asset(
        'assets/images/women.jpg',
        width: 100,
        height: 100,
        fit: BoxFit.fill,
      );
    } else if (gender == 'male') {
      return Image.asset(
        'assets/images/men.jpg',
        width: 100,
        height: 100,
        fit: BoxFit.fill,
      );
    }
    return Image.asset('assets/images/athlete.png', width: 100, height: 100);
  }

  @override
  Widget build(BuildContext context) {
    final athlete = widget.athlete;
    final plans = ref.watch(workoutPlanProvider(athlete.supabaseId ?? ''));
    final l10n = AppLocalizations.of(context);
    final progress = athlete.goalWeight != null && athlete.weight != null
        ? ((athlete.weight! - athlete.goalWeight!).abs() /
                athlete.goalWeight! *
                100)
            .toStringAsFixed(1)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n!.translate('profile')),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              // ignore: deprecated_member_use
              Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Directionality(
            textDirection: l10n.locale.languageCode == 'fa'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            child: ClipOval(child: _getAvatar()),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            athlete.name ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodyLarge!.color,
                            ),
                          ),
                          Text(
                            '${l10n.translate('joined')}: ${athlete.createdAt != null ? DateTime.parse(athlete.createdAt!).toLocal().toString().split(' ')[0] : '-'}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('details'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('age'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                Text('${athlete.age ?? '-'}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('weight'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                Text('${athlete.weight ?? '-'} kg',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('goal_weight'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                Text('${athlete.goalWeight ?? '-'} kg',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('gender'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                // ignore: unnecessary_string_interpolations
                                Text('${athlete.gender ?? '-'}',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('height'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                Text('${athlete.height ?? '-'} cm',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l10n.translate('body_fat'),
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                                Text('${athlete.bodyFat ?? '-'} %',
                                    style: TextStyle(
                                        color: Theme.of(context)
                                            .textTheme
                                            .bodyLarge!
                                            .color)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('progress_insights'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${l10n.translate('progress_to_goal')}: $progress%',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 100,
                              child: PieChart(
                                PieChartData(
                                  sections: [
                                    PieChartSectionData(
                                      value: double.parse(progress),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      title: '$progress%',
                                      radius: 40,
                                    ),
                                    PieChartSectionData(
                                      value: 100 - double.parse(progress),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          // ignore: deprecated_member_use
                                          .withOpacity(0.2),
                                      title: '',
                                      radius: 40,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('weight_progress'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 200,
                              child: LineChart(
                                LineChartData(
                                  gridData: const FlGridData(show: false),
                                  titlesData: FlTitlesData(
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 40,
                                        getTitlesWidget: (value, meta) => Text(
                                          '${value.toInt()} kg',
                                          style: TextStyle(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall!
                                                  .color,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ),
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        getTitlesWidget: (value, meta) {
                                          final index = value.toInt();
                                          if (index >= 0 &&
                                              index <
                                                  athlete
                                                      .weightHistory.length) {
                                            final date = DateTime.parse(athlete
                                                .weightHistory[index].date!);
                                            return Text(
                                              '${date.month}/${date.day}',
                                              style: TextStyle(
                                                  color: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall!
                                                      .color,
                                                  fontSize: 12),
                                            );
                                          }
                                          return const Text('');
                                        },
                                      ),
                                    ),
                                    topTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                    rightTitles: const AxisTitles(
                                        sideTitles:
                                            SideTitles(showTitles: false)),
                                  ),
                                  borderData: FlBorderData(show: false),
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: athlete.weightHistory
                                          .asMap()
                                          .entries
                                          .map((e) {
                                        return FlSpot(e.key.toDouble(),
                                            e.value.weight ?? 0);
                                      }).toList(),
                                      isCurved: true,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: true),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary
                                            // ignore: deprecated_member_use
                                            .withOpacity(0.2),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('measurements'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              label: l10n.translate('height'),
                              controller: _heightController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            CustomTextField(
                              label: l10n.translate('body_fat'),
                              controller: _bodyFatController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            CustomButton(
                              text: l10n.translate('update'),
                              onPressed: _updateMeasurements,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.translate('add_measurement'),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            CustomTextField(
                              label: l10n.translate('measurement_type'),
                              controller: _measurementTypeController,
                            ),
                            const SizedBox(height: 8),
                            CustomTextField(
                              label: l10n.translate('measurement_value'),
                              controller: _measurementValueController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            CustomButton(
                              text: l10n.translate('add'),
                              onPressed: _addMeasurement,
                            ),
                            const SizedBox(height: 16),
                            ...athlete.measurements.map((m) => ListTile(
                                  title: Text('${m.type}: ${m.value} cm',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .color)),
                                  subtitle: Text(m.date ?? '',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .color)),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('workout_plans'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...plans.map((plan) => ListTile(
                                  title: Text(plan.name ?? 'Workout',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodyLarge!
                                              .color)),
                                  subtitle: Text(
                                      '${plan.exercises.map((e) => '${e.name}: ${e.sets} sets').join(', ')} | ${plan.status ?? 'Active'}',
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall!
                                              .color)),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (plan.status != 'completed')
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () =>
                                              _markWorkoutCompleted(
                                                  plan.supabaseId ?? ''),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red),
                                        onPressed: () => _deleteWorkoutPlan(
                                            plan.supabaseId ?? ''),
                                      ),
                                    ],
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: CustomCard(
                      title: l10n.translate('goal_weight'),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomTextField(
                              label: l10n.translate('goal_weight'),
                              controller: _goalWeightController,
                              keyboardType: TextInputType.number,
                            ),
                            const SizedBox(height: 8),
                            CustomButton(
                              text: l10n.translate('update_goal'),
                              onPressed: _updateGoalWeight,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
