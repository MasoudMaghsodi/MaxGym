import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:max_gym/l10n/app_localizations.dart';
import 'package:max_gym/providers/athlete_provider.dart';
import 'package:max_gym/widgets/custom_card.dart';

class NotificationsTab extends ConsumerWidget {
  const NotificationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ref.read(supabaseServiceProvider).getNotifications(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text(l10n.translate('error_loading_notifications')));
        }
        final notifications = snapshot.data ?? [];
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Directionality(
              textDirection: l10n.locale.languageCode == 'fa'
                  ? TextDirection.rtl
                  : TextDirection.ltr,
              child: Column(
                children: [
                  CustomCard(
                    title: l10n.translate('notifications'),
                    child: notifications.isEmpty
                        ? Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(l10n.translate('no_notifications'),
                                style: const TextStyle(color: Colors.white)),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: notifications.length,
                            itemBuilder: (context, index) {
                              final notification = notifications[index];
                              return ListTile(
                                leading: Icon(Icons.notifications,
                                    color: const Color(0xFFE53935)),
                                title: Text(
                                  notification['title'],
                                  style: const TextStyle(color: Colors.white),
                                ),
                                subtitle: Text(
                                  notification['body'],
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                trailing: Text(
                                  notification['created_at'] != null
                                      ? DateTime.parse(
                                              notification['created_at'])
                                          .toLocal()
                                          .toString()
                                          .split('.')[0]
                                      : '',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
