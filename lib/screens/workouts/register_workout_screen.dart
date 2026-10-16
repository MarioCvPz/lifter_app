import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

class RegisterWorkoutScreen extends StatefulWidget {
  const RegisterWorkoutScreen({super.key, this.fromRoutine});

  final Routine? fromRoutine;

  @override
  State<RegisterWorkoutScreen> createState() => _RegisterWorkoutScreenState();
}

class _DraftSet {
  int reps = 8;
  double weight = 20;
}

class _DraftExercise {
  _DraftExercise(this.exercise) : sets = [_DraftSet()];
  final Exercise exercise;
  final List<_DraftSet> sets;
}

class _RegisterWorkoutScreenState extends State<RegisterWorkoutScreen> {
  late final TextEditingController _name;
  late final TextEditingController _duration;
  final List<_DraftExercise> _items = [];

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.fromRoutine?.name ?? 'Entrenamiento',
    );
    _duration = TextEditingController(text: '45');
    if (widget.fromRoutine != null) {
      for (final ex in widget.fromRoutine!.exercises) {
        _items.add(_DraftExercise(ex));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickExercise() async {
    final store = SessionScope.of(context);
    final chosen = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListView(
          children: [
            const ListTile(title: Text('Catálogo de ejercicios')),
            for (final ex in store.exercises)
              ListTile(
                title: Text(ex.name),
                subtitle: Text('${ex.muscleGroup} · ${ex.equipment}'),
                onTap: () => Navigator.pop(ctx, ex),
              ),
          ],
        );
      },
    );
    if (chosen != null) {
      setState(() => _items.add(_DraftExercise(chosen)));
    }
  }

  void _save() {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Añade al menos un ejercicio.')),
      );
      return;
    }

    final duration = int.tryParse(_duration.text) ?? 0;
    final workout = Workout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Entrenamiento' : _name.text.trim(),
      date: DateTime.now(),
      durationMin: duration,
      exercises: [
        for (final item in _items)
          WorkoutExercise(
            exercise: item.exercise,
            sets: [
              for (final s in item.sets)
                WorkoutSet(reps: s.reps, weightKg: s.weight),
            ],
          ),
      ],
    );

    SessionScope.of(context).addWorkout(workout);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar entrenamiento'),
        actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre de la sesión'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Duración (minutos)',
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < _items.length; i++) _exerciseCard(i),
          OutlinedButton.icon(
            onPressed: _pickExercise,
            icon: const Icon(Icons.add),
            label: const Text('Añadir ejercicio'),
          ),
          const SizedBox(height: 8),
          Text(
            'Se guarda solo en memoria. Al reiniciar la app se pierde.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.exercise.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _items.removeAt(index)),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Text(
              '${item.exercise.muscleGroup} · ${item.exercise.equipment}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (var s = 0; s < item.sets.length; s++)
              Row(
                children: [
                  Text('Serie ${s + 1}'),
                  const Spacer(),
                  SizedBox(
                    width: 72,
                    child: TextFormField(
                      initialValue: '${item.sets[s].reps}',
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reps'),
                      onChanged: (v) =>
                          item.sets[s].reps = int.tryParse(v) ?? item.sets[s].reps,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: TextFormField(
                      initialValue: item.sets[s].weight.toStringAsFixed(0),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Kg'),
                      onChanged: (v) => item.sets[s].weight =
                          double.tryParse(v) ?? item.sets[s].weight,
                    ),
                  ),
                ],
              ),
            TextButton(
              onPressed: () => setState(() => item.sets.add(_DraftSet())),
              child: const Text('Añadir serie'),
            ),
          ],
        ),
      ),
    );
  }
}
