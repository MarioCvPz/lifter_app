import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import 'register_workout_screen.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Entrenamientos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RegisterWorkoutScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Registrar'),
      ),
      body: store.workouts.isEmpty
          ? const Center(child: Text('Todavía no hay entrenamientos.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: store.workouts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final w = store.workouts[i];
                return Card(
                  child: ExpansionTile(
                    leading: const Icon(Icons.fitness_center),
                    title: Text(w.name),
                    subtitle: Text(
                      '${_fmt(w.date)} · ${w.durationMin} min · ${w.exercises.length} ejercicios',
                    ),
                    children: [
                      for (final ex in w.exercises)
                        ListTile(
                          title: Text(ex.exercise.name),
                          subtitle: Text(_setsLabel(ex)),
                        ),
                    ],
                  ),
                );
              },
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
