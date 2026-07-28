import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/cf_colors.dart';

/// Custom shell bottom bar — compact in-bar My Cricket logo circle.
class CfShellBottomNav extends StatelessWidget {
  const CfShellBottomNav({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  static const double _barHeight = 60;
  static const double _centerLogoSize = 36;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final isLight = cf.isLight;

    return Material(
      color: isLight ? Colors.white : cf.chromeBackground,
      elevation: isLight ? 6 : 0,
      shadowColor: Colors.black26,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: cf.border, width: 0.5),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: _barHeight,
            child: Row(
              children: [
                _SideDestination(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                _SideDestination(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore,
                  label: 'Discover',
                  selected: currentIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                _MyCricketDestination(
                  selected: currentIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                _SideDestination(
                  icon: Icons.groups_outlined,
                  selectedIcon: Icons.groups,
                  label: 'Community',
                  selected: currentIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                _SideDestination(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  label: 'Profile',
                  selected: currentIndex == 4,
                  onTap: () => onDestinationSelected(4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SideDestination extends StatelessWidget {
  const _SideDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final color = selected ? cf.navSelected : cf.navUnselected;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? selectedIcon : icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCricketDestination extends StatelessWidget {
  const _MyCricketDestination({
    required this.selected,
    required this.onTap,
  });

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isLight = cf.isLight;
    final color = selected ? cf.navSelected : cf.navUnselected;
    final ringColor = selected ? CfColors.primaryBlue : cf.border;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: CfShellBottomNav._centerLogoSize,
              height: CfShellBottomNav._centerLogoSize,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLight ? Colors.white : cf.surfaceElevated,
                border: Border.all(
                  color: ringColor,
                  width: selected ? 2 : 1.25,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color:
                              CfColors.primaryBlue.withValues(alpha: 0.22),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: ClipOval(
                child: Image.asset(
                  AppConstants.crickflowLogoAsset,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'My Cricket',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
