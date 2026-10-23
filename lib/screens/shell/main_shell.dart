import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../home/home_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../profile/profile_screen.dart';
import '../routines/routines_screen.dart';
import '../workouts/workouts_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [
    HomeScreen(),
    WorkoutsScreen(),
    RoutinesScreen(),
    NutritionScreen(),
    ProfileScreen(),
  ];

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Inicio'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Entrenos'),
    (Icons.calendar_today_outlined, Icons.calendar_today, 'Rutinas'),
    (Icons.restaurant_outlined, Icons.restaurant, 'Nutrición'),
    (Icons.person_outline, Icons.person, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      // Barra flotante en forma de píldora; la pestaña activa va en coral.
      bottomNavigationBar: SafeArea(
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
              for (var i = 0; i < _items.length; i++)
                Expanded(child: _navItem(context, i)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int i) {
    final (icon, selectedIcon, label) = _items[i];
    final selected = i == _index;
    final color = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _index = i),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
