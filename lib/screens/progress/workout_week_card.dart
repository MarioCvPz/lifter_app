import 'package:flutter/material.dart';

import '../../data/week_summary.dart';
import '../../theme/app_theme.dart';
import 'day_circles.dart';

/// Tarjeta "Entrenos" ("3 de 4") con un círculo por día:
/// hecho = relleno coral con ✓; pendiente = borde coral discontinuo;
/// no hecho = borde apagado con "–"; descanso = punto gris.
class WorkoutWeekCard extends StatelessWidget {
  const WorkoutWeekCard({super.key, required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    return WeekDaysCard(
      title: 'Entrenos',
      count: '${summary.doneWorkouts} de ${summary.plannedWorkouts}',
      circles: [
        for (final status in summary.workoutStatuses)
          _circleFor(context, status),
      ],
    );
  }

  Widget _circleFor(BuildContext context, WorkoutDayStatus status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      WorkoutDayStatus.done => const DayCircle(
        fill: AppTheme.coral,
        child: Icon(Icons.check, size: 18, color: Colors.white),
      ),
      WorkoutDayStatus.pending => const DayCircle(
        border: AppTheme.coral,
        dashed: true,
      ),
      WorkoutDayStatus.missed => DayCircle(
        border: scheme.outlineVariant,
        child: Text('–', style: TextStyle(color: scheme.onSurfaceVariant)),
      ),
      WorkoutDayStatus.rest => const RestDot(),
    };
  }
}
