import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n!.translate('settings')),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Directionality(
            textDirection: l10n.locale.languageCode == 'fa'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('language'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: settings.locale.languageCode,
                  items: [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text(l10n.translate('english')),
                    ),
                    DropdownMenuItem(
                      value: 'fa',
                      child: Text(l10n.translate('persian')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(settingsProvider.notifier).setLanguage(value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.translate('notifications'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  title: Text(l10n.translate('enable_notifications'),
                      style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge!.color)),
                  value: settings.notificationsEnabled,
                  onChanged: (value) {
                    ref
                        .read(settingsProvider.notifier)
                        .setNotificationsEnabled(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
