import 'package:flutter/material.dart';

import '../../data/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../workouts/live_workout_screen.dart';
import '../workouts/workout_preview_screen.dart';

/// Resumen del entreno de un día: el día ("Hoy · Martes"), el nombre del
/// entreno, cuántos ejercicios tiene y el botón "Empezar entrenamiento".
/// Al pulsar la tarjeta se abre la vista previa con los ejercicios; se
/// cambian dentro del entrenamiento.
class DayWorkoutCard extends StatelessWidget {
  const DayWorkoutCard({super.key, required this.workout});

  final DayWorkout workout;

  /// Al pulsar la tarjeta: la vista previa con los ejercicios.
  void _openPreview(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WorkoutPreviewScreen(workout: workout)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isEmpty = workout.routine.exercises.isEmpty;
    return Card(
      margin: EdgeInsets.zero,
      // Para que el efecto al pulsar no se salga de las esquinas redondas.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPreview(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (workout.fromTrainer)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: StatusPill(
                    label: 'De tu entrenador',
                    color: AppTheme.coral,
                    icon: Icons.person,
                  ),
                ),
              if (workout.fromTrainer) const SizedBox(height: 8),
              Text(
                workout.dayLabel(DateTime.now().weekday),
                style: text.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workout.name,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                isEmpty
                    ? 'Este día aún no tiene ejercicios.'
                    : workout.exerciseCountLabel,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                // Sin ejercicios no hay nada que empezar.
                // El botón abre directamente el entreno, sin vista previa.
                onPressed: isEmpty
                    ? null
                    : () => startDayWorkout(context, workout),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Empezar entrenamiento'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
