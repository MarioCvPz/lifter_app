import 'package:flutter/material.dart';

import '../../widgets/pill_nav_bar.dart';
import '../home/home_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../workouts/workouts_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  /// Posición de Nutrición en [_items]; Inicio abre esta pestaña al tocar
  /// las calorías.
  static const _nutritionIndex = 3;

  // `late`: se crea la primera vez que se usa, cuando ya existe `this` y se
  // puede pasar un método del State (en Java sería inicializarlo en el
  // constructor).
  late final _pages = [
    HomeScreen(onOpenNutrition: () => _select(_nutritionIndex)),
    const WorkoutsScreen(),
    // Progreso ocupa el sitio de Rutinas. RoutinesScreen sigue en el
    // proyecto, pero de momento no está en la barra.
    const ProgressScreen(),
    const NutritionScreen(),
    const ProfileScreen(),
  ];

  void _select(int index) => setState(() => _index = index);

  static const _items = [
    PillNavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Inicio',
    ),
    PillNavItem(
      icon: Icons.fitness_center_outlined,
      selectedIcon: Icons.fitness_center,
      label: 'Entrenos',
    ),
    PillNavItem(
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
      label: 'Progreso',
    ),
    PillNavItem(
      icon: Icons.restaurant_outlined,
      selectedIcon: Icons.restaurant,
      label: 'Nutrición',
    ),
    PillNavItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: PillNavBar(
        items: _items,
        selectedIndex: _index,
        onSelected: _select,
      ),
    );
  }
}
