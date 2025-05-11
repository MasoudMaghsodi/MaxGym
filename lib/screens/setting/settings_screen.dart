import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/screens/setting/exercise_list_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.translate('settings'),
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Montserrat',
            fontSize: 20.sp,
          ),
        ),
        backgroundColor: const Color(0xFFE53935),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE53935), Color(0xFF212121)],
          ),
        ),
        child: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_6, color: Colors.white),
              title: Text(
                l10n.translate('theme'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
              trailing: Switch(
                value: Theme.of(context).brightness == Brightness.dark,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
                activeColor: const Color(0xFFE53935),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.fitness_center, color: Colors.white),
              title: Text(
                l10n.translate('manage_exercises'),
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Montserrat',
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ExerciseListScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
