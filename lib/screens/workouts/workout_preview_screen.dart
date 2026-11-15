import 'package:flutter/material.dart';

import '../../data/stats.dart';
import '../../data/workout_draft.dart';
import 'live_workout_screen.dart';

/// Vista previa del entreno de un día, antes de empezar: el nombre y los
/// ejercicios con sus series, repeticiones y descanso ("Press de banca ·
/// 4 × 8–12 · 1:30"), y abajo el botón "Comenzar entrenamiento". Es solo
/// para ver: los ejercicios se cambian dentro del entrenamiento.
class WorkoutPreviewScreen extends StatelessWidget {
  const WorkoutPreviewScreen({super.key, required this.workout});

  final DayWorkout workout;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final exercises = workout.plannedExercises;
    return Scaffold(
      appBar: AppBar(title: Text(workout.dayLabel(DateTime.now().weekday))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            workout.name,
            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(workout.exerciseCountLabel, style: text.bodyMedium),
          const SizedBox(height: 12),
          for (var i = 0; i < exercises.length; i++)
            _PreviewTile(number: i + 1, item: exercises[i]),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            // Sin ejercicios no hay nada que empezar.
            onPressed: exercises.isEmpty
                ? null
                : () => startDayWorkout(context, workout, replace: true),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Comenzar entrenamiento'),
          ),
        ),
      ),
    );
  }
}

/// Un ejercicio de la vista previa: número, nombre y objetivo.
class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.number, required this.item});

  final int number;
  final DraftExercise item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        child: Text('$number', style: const TextStyle(fontSize: 13)),
      ),
      title: Text(item.exercise.name),
      subtitle: Text(item.previewLabel),
    );
  }
}
