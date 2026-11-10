import 'package:flutter/material.dart';
import '../config/maxgym_brand_config.dart';

class MaxGymResponsiveScaffold extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;
  final List<Widget> pages;

  const MaxGymResponsiveScaffold({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.pages,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideScreen = width >= 900; // تبلت‌های عریض، لپتاپ و دسکتاپ
    final theme = Theme.of(context);

    if (!isWideScreen) {
      return Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: destinations,
        ),
      );
    }

    final isExtended = width >= 1200;

    // چیدمان عریض دسکتاپ، لپتاپ پذیرش باشگاه و تبلت
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: isExtended,
            labelType: isExtended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            backgroundColor: const Color(0xFF101412),
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      MaxGymBrandConfig.bundledLogoAsset,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.fitness_center,
                        color: theme.colorScheme.primary,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'MAX GYM',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: d.icon,
                    label: Text(d.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1, thickness: 1, color: Colors.white12),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: IndexedStack(
                  index: selectedIndex,
                  children: pages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
