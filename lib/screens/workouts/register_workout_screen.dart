import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/help.dart';

class RegisterWorkoutScreen extends StatefulWidget {
  const RegisterWorkoutScreen({super.key, this.fromRoutine});

  final Routine? fromRoutine;

  @override
  State<RegisterWorkoutScreen> createState() => _RegisterWorkoutScreenState();
}

class _DraftSet {
  _DraftSet({this.reps = 8, this.weight = 20});

  int reps;
  double weight;
}

class _DraftExercise {
  _DraftExercise(this.exercise) : sets = [_DraftSet()];
  final Exercise exercise;
  final List<_DraftSet> sets;
}

class _RegisterWorkoutScreenState extends State<RegisterWorkoutScreen> {
  late final TextEditingController _name;
  final _duration = TextEditingController();
  final List<_DraftExercise> _items = [];

  /// Para calcular la duración si el usuario no la escribe.
  final _startedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.fromRoutine?.name ?? 'Entrenamiento',
    );
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

  int get _elapsedMin {
    final min = DateTime.now().difference(_startedAt).inMinutes;
    return min < 1 ? 1 : min;
  }

  Future<void> _pickExercise() async {
    final store = SessionScope.of(context);
    final chosen = await showModalBottomSheet<Exercise>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          builder: (ctx, controller) {
            return ListView(
              controller: controller,
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
      },
    );
    if (chosen != null) {
      setState(() => _items.add(_DraftExercise(chosen)));
    }
  }

  void _save() {
    String? error;
    if (_items.isEmpty) {
      error = 'Añade al menos un ejercicio.';
    } else if (_items.any((i) => i.sets.isEmpty)) {
      error = 'Cada ejercicio necesita al menos una serie.';
    } else if (_items.any((i) => i.sets.any((s) => s.reps <= 0))) {
      error = 'Las repeticiones tienen que ser mayores que 0.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final duration = int.tryParse(_duration.text) ?? _elapsedMin;
    final workout = Workout(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? 'Entrenamiento' : _name.text.trim(),
      date: DateTime.now(),
      durationMin: duration,
      routineId: widget.fromRoutine?.id,
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entrenamiento guardado.')));
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Descartar entrenamiento?'),
        content: const Text('Perderás las series que has apuntado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Si ya hay ejercicios apuntados, pregunta antes de salir.
      canPop: _items.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Registrar entrenamiento'),
          actions: [
            const HelpButton(HelpTopic.registerWorkout),
            TextButton(onPressed: _save, child: const Text('Guardar')),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Nombre de la sesión',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _duration,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duración (minutos)',
                helperText:
                    'Si lo dejas vacío se usa el tiempo desde que abriste '
                    'esta pantalla.',
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _items.length; i++) _exerciseCard(i),
            OutlinedButton.icon(
              onPressed: _pickExercise,
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(int index) {
    final item = _items[index];
    return Card(
      // La key evita que, al quitar un ejercicio, sus series pasen al siguiente.
      key: ObjectKey(item),
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
                  tooltip: 'Quitar ejercicio',
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
            for (var s = 0; s < item.sets.length; s++) _setRow(item, s),
            TextButton.icon(
              // La nueva serie copia los valores de la anterior.
              onPressed: () => setState(() {
                final last = item.sets.isEmpty ? null : item.sets.last;
                item.sets.add(
                  _DraftSet(reps: last?.reps ?? 8, weight: last?.weight ?? 20),
                );
              }),
              icon: const Icon(Icons.add),
              label: const Text('Añadir serie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setRow(_DraftExercise item, int s) {
    final set = item.sets[s];
    return Row(
      key: ObjectKey(set),
      children: [
        Text('Serie ${s + 1}'),
        const Spacer(),
        SizedBox(
          width: 72,
          child: TextFormField(
            initialValue: '${set.reps}',
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
            onChanged: (v) => set.reps = int.tryParse(v) ?? 0,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: TextFormField(
            initialValue: _fmtKg(set.weight),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Kg'),
            onChanged: (v) =>
                set.weight = double.tryParse(v.replaceAll(',', '.')) ?? 0,
          ),
        ),
        IconButton(
          tooltip: 'Quitar serie',
          onPressed: () => setState(() => item.sets.removeAt(s)),
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }

  String _fmtKg(double kg) =>
      kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : '$kg';
}
