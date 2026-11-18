import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Una pestaña de [PillNavBar]. Si [badge] es mayor que 0, se ve un globo
/// con el número sobre el icono.
class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge = 0,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int badge;
}

/// Barra de navegación flotante en forma de píldora; la pestaña activa va
/// en coral. La usan la app normal ([MainShell]) y el modo entrenador
/// ([TrainerShell]). Con [showLabels] a false solo se ven los iconos (el
/// nombre sigue en Semantics para los lectores de pantalla).
class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.showLabels = true,
  });

  final List<PillNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool showLabels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(99),
          boxShadow: const [
            BoxShadow(
              color: Color(0xB3000000),
              blurRadius: 32,
              offset: Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == selectedIndex,
                  showLabel: showLabels,
                  onTap: () => onSelected(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  final PillNavItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: selected ? AppTheme.coral : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.coral.withValues(alpha: 0.35),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          // La pestaña seleccionada muestra solo el icono; las demás,
          // icono y texto (si [showLabel]).
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: item.badge > 0,
                label: Text('${item.badge}'),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: selected || !showLabel ? 24 : 20,
                  color: color,
                ),
              ),
              if (showLabel && !selected) ...[
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
