import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import '../home/day_workout_card.dart';
import 'live_workout_screen.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final next = store.nextWorkout(DateTime.now());

    return Scaffold(
      appBar: const BrandAppBar(
        title: 'Entrenamientos',
        help: HelpTopic.workouts,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            // Sin rutina: empieza vacío, con "Añadir ejercicio".
            MaterialPageRoute(builder: (_) => const LiveWorkoutScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // Arriba, el entreno de hoy o el próximo (si tiene plan).
          if (next != null) ...[
            DayWorkoutCard(workout: next),
            const SizedBox(height: 16),
          ],
          if (store.workouts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Todavía no hay entrenamientos.\n'
                'Pulsa "Registrar" para apuntar el primero.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final w in store.workouts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _workoutTile(context, store, w),
            ),
        ],
      ),
    );
  }

  /// Un entreno del historial (se borra deslizándolo).
  Widget _workoutTile(BuildContext context, AppStore store, Workout w) {
    return Dismissible(
      key: ValueKey(w.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      onDismissed: (_) => _delete(context, store, w),
      child: Card(
        margin: EdgeInsets.zero,
        child: ExpansionTile(
          leading: const Icon(Icons.fitness_center),
          title: Text(w.name),
          subtitle: Text(
            '${_fmt(w.date)} · ${w.durationMin} min · '
            '${w.exercises.length} ejercicios · '
            '${w.volumeKg.toStringAsFixed(0)} kg',
          ),
          children: [
            for (final ex in w.exercises)
              ListTile(
                title: Text(ex.exercise.name),
                subtitle: Text(_setsLabel(ex)),
              ),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext context, AppStore store, Workout w) {
    store.deleteWorkout(w.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('"${w.name}" eliminado.'),
          action: SnackBarAction(
            label: 'Deshacer',
            onPressed: () => store.addWorkout(w),
          ),
        ),
      );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _setsLabel(WorkoutExercise ex) {
    return ex.sets
        .map((s) => '${s.reps}×${s.weightKg.toStringAsFixed(1)} kg')
        .join('  ·  ');
  }
}
