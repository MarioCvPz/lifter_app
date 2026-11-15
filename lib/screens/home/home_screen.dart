import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import 'day_workout_card.dart';
import 'today_strip.dart';
import 'week_strip.dart';

/// Inicio, de arriba abajo: saludo con la racha, semana L–D, franja de hoy
/// (calorías y agua) y el entreno del día seleccionado.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenNutrition});

  /// Abre la pestaña Nutrición (al tocar las calorías).
  final VoidCallback? onOpenNutrition;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Día seleccionado en la semana (1 = lunes). Por defecto, hoy.
  int _selectedWeekday = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final workout = store.workoutFor(_selectedWeekday);
    final isToday = _selectedWeekday == DateTime.now().weekday;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Inicio', help: HelpTopic.home),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Hola, ${store.user?.name ?? 'atleta'}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          _StatusPills(store: store),
          const SizedBox(height: 12),
          WeekStrip(
            trainingWeekdays: {
              for (final day in store.plan?.days ?? const <PlanDay>[])
                day.weekday,
            },
            selectedWeekday: _selectedWeekday,
            onSelected: (weekday) => setState(() => _selectedWeekday = weekday),
          ),
          const SizedBox(height: 16),
          TodayStrip(store: store, onOpenNutrition: widget.onOpenNutrition),
          // Los días de descanso no tienen esta sección.
          if (workout != null) ...[
            const SizedBox(height: 24),
            SectionHeader(
              isToday
                  ? 'Entreno de hoy'
                  : ProfileOptions.weekdayNames[_selectedWeekday - 1],
            ),
            DayWorkoutCard(workout: workout),
          ],
        ],
      ),
    );
  }
}

/// Racha de días entrenando y estado de hoy.
class _StatusPills extends StatelessWidget {
  const _StatusPills({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final streak = store.streakDays();
    // Wrap: en pantallas estrechas la segunda etiqueta baja de línea en vez
    // de salirse por la derecha.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        StatusPill(
          label: '$streak ${streak == 1 ? 'día' : 'días'}',
          color: AppTheme.coral,
          icon: Icons.local_fire_department,
        ),
        StatusPill(
          label: store.todayStatus(DateTime.now()),
          color: Theme.of(context).colorScheme.secondary,
          dot: true,
        ),
      ],
    );
  }
}
