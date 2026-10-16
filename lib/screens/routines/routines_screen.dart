import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../workouts/register_workout_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final templates = store.routines.where((r) => r.isTemplate).toList();
    final mine = store.routines.where((r) => !r.isTemplate).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Rutinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createRoutine(context, store),
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Text(
            'Plantillas recomendadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          for (final r in templates) _RoutineCard(routine: r),
          const SizedBox(height: 16),
          Text(
            'Mis rutinas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (mine.isEmpty) const Text('Aún no has creado ninguna rutina.'),
          for (final r in mine) _RoutineCard(routine: r),
        ],
      ),
    );
  }

  Future<void> _createRoutine(BuildContext context, AppStore store) async {
    final name = TextEditingController();
    final selected = <Exercise>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Nueva rutina'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                        ),
                      ),
                      const SizedBox(height: 12),
                      for (final ex in store.exercises)
                        CheckboxListTile(
                          dense: true,
                          value: selected.contains(ex),
                          title: Text(ex.name),
                          subtitle: Text(ex.muscleGroup),
                          onChanged: (v) {
                            setLocal(() {
                              if (v == true) {
                                selected.add(ex);
                              } else {
                                selected.remove(ex);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (created == true && name.text.trim().isNotEmpty && selected.isNotEmpty) {
      store.addRoutine(
        Routine(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: name.text.trim(),
          description: 'Rutina creada en el dispositivo (sin base de datos).',
          templateName: 'Personal',
          exercises: selected.toList(),
        ),
      );
    }
    name.dispose();
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    routine.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(routine.templateName)),
              ],
            ),
            const SizedBox(height: 4),
            Text(routine.description),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final ex in routine.exercises)
                  Chip(label: Text(ex.name), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RegisterWorkoutScreen(fromRoutine: routine),
                    ),
                  );
                },
                child: const Text('Usar en un entreno'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
