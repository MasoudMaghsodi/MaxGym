import 'package:flutter/material.dart';
import '../config/maxgym_brand_config.dart';
import '../constants/app_colors.dart';

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
    final isWideScreen = width >= 900;
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

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

    final isExtended = width >= 1150;

    return Scaffold(
      body: Stack(
        children: [
          // هاله نوری سایبرنتیک در پسزمینه دسکتاپ برای حذف حس تخت بودن صفحه
          Positioned(
            top: -120,
            left: -100,
            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0E1411),
                      Color(0xFF090C0A),
                    ],
                  ),
                  border: Border(
                    left: BorderSide(
                      color: primary.withOpacity(0.22),
                      width: 1.2,
                    ),
                  ),
                ),
                child: NavigationRail(
                  extended: isExtended,
                  backgroundColor: Colors.transparent,
                  indicatorColor: primary.withOpacity(0.22),
                  selectedIconTheme: IconThemeData(color: primary, size: 22),
                  unselectedIconTheme:
                      const IconThemeData(color: Colors.white60, size: 20),
                  selectedLabelTextStyle: TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  unselectedLabelTextStyle: const TextStyle(
                    fontFamily: 'Vazirmatn',
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  labelType: isExtended
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 12),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: primary, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.35),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.asset(
                              MaxGymBrandConfig.bundledLogoAsset,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.fitness_center,
                                color: primary,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'MAX GYM',
                          style: TextStyle(
                            color: primary,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle,
                                  size: 7, color: AppColors.success),
                              SizedBox(width: 5),
                              Text(
                                'PRO CLOUD',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
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
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: IndexedStack(
                      index: selectedIndex,
                      children: pages,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
