import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/coach_plan.dart';
import '../../models/models.dart';

/// Diálogo para que el entrenador cambie las series, repeticiones,
/// descanso y nota de un ejercicio del plan. Devuelve el ejercicio con los
/// cambios, o null si se cancela.
Future<PlanExercise?> showPrescriptionDialog(
  BuildContext context,
  PlanExercise exercise,
) {
  return showDialog<PlanExercise>(
    context: context,
    builder: (_) => _PrescriptionDialog(exercise),
  );
}

class _PrescriptionDialog extends StatefulWidget {
  const _PrescriptionDialog(this.exercise);

  final PlanExercise exercise;

  @override
  State<_PrescriptionDialog> createState() => _PrescriptionDialogState();
}

class _PrescriptionDialogState extends State<_PrescriptionDialog> {
  late final _sets = TextEditingController(text: '${widget.exercise.sets}');
  late final _minReps = TextEditingController(
    text: '${widget.exercise.minReps}',
  );
  late final _maxReps = TextEditingController(
    text: '${widget.exercise.maxReps}',
  );
  late final _rest = TextEditingController(
    text: '${widget.exercise.restSeconds}',
  );
  late final _note = TextEditingController(
    text: widget.exercise.trainerNote ?? '',
  );
  String? _error;

  @override
  void dispose() {
    for (final c in [_sets, _minReps, _maxReps, _rest, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final sets = int.tryParse(_sets.text);
    final minReps = int.tryParse(_minReps.text);
    final maxReps = int.tryParse(_maxReps.text);
    final rest = int.tryParse(_rest.text);
    final error = CoachPlan.validate(
      sets: sets,
      minReps: minReps,
      maxRepsValue: maxReps,
      restSeconds: rest,
    );
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final note = _note.text.trim();
    Navigator.pop(
      context,
      // validate() ha devuelto null, así que los cuatro números existen.
      widget.exercise.copyWith(
        sets: sets!,
        minReps: minReps!,
        maxReps: maxReps!,
        restSeconds: rest!,
        trainerNote: () => note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.exercise.exercise.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _NumberField(controller: _sets, label: 'Series'),
                const SizedBox(width: 8),
                _NumberField(controller: _rest, label: 'Descanso (s)'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _NumberField(controller: _minReps, label: 'Reps mín.'),
                const SizedBox(width: 8),
                _NumberField(controller: _maxReps, label: 'Reps máx.'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: CoachPlan.maxNoteLength,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Nota para tu cliente (opcional)',
                hintText: 'Ej.: baja controlando 3 segundos',
              ),
            ),
            if (_error case final error?)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

/// Campo pequeño que solo admite números enteros.
class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
