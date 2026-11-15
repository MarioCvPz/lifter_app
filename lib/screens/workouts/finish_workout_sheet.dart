import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/workout_draft.dart';

/// Abre el resumen de "Terminar entrenamiento". Devuelve los minutos que
/// hay que guardar si el usuario pulsa "Guardar", o null si sigue
/// entrenando.
Future<int?> showFinishWorkoutSheet(
  BuildContext context, {
  required WorkoutDraft draft,
  required int durationMin,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    // Para que el teclado no tape el campo de la duración.
    isScrollControlled: true,
    builder: (_) => _FinishWorkoutSheet(draft: draft, durationMin: durationMin),
  );
}

/// Después de guardar un entreno con ejercicios añadidos, quitados o
/// sustituidos, pregunta si esos cambios pasan a [target] ("tu plan" o
/// "tu rutina"). True con "Sí"; false con "Solo hoy" o al cerrarlo.
Future<bool> askSaveChanges(
  BuildContext context, {
  required String target,
}) async {
  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Has cambiado ejercicios'),
      content: Text(
        '¿Quieres guardar estos cambios en $target para la próxima vez?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Solo hoy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Sí'),
        ),
      ],
    ),
  );
  return save ?? false;
}

/// Pregunta si se quiere descartar el entrenamiento. Devuelve true si sí.
Future<bool> confirmDiscardWorkout(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Descartar entrenamiento?'),
      content: const Text('Perderás las series que has apuntado.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Seguir entrenando'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Descartar'),
        ),
      ],
    ),
  );
  // Si se cierra el diálogo tocando fuera, devuelve null: no se descarta.
  return discard ?? false;
}

/// Resumen: duración (editable, por si se empezó a apuntar tarde), series
/// hechas, volumen y ejercicios.
class _FinishWorkoutSheet extends StatefulWidget {
  const _FinishWorkoutSheet({required this.draft, required this.durationMin});

  final WorkoutDraft draft;
  final int durationMin;

  @override
  State<_FinishWorkoutSheet> createState() => _FinishWorkoutSheetState();
}

class _FinishWorkoutSheetState extends State<_FinishWorkoutSheet> {
  late final TextEditingController _duration;
  String? _error;

  @override
  void initState() {
    super.initState();
    _duration = TextEditingController(text: '${widget.durationMin}');
  }

  @override
  void dispose() {
    _duration.dispose();
    super.dispose();
  }

  void _save() {
    final minutes = int.tryParse(_duration.text) ?? 0;
    if (minutes < 1 || minutes > WorkoutDraft.maxDurationMin) {
      setState(
        () => _error =
            'Escribe entre 1 y ${WorkoutDraft.maxDurationMin} minutos.',
      );
      return;
    }
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return Padding(
      // Deja sitio al teclado cuando está abierto.
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Terminar entrenamiento',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duration,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Duración (minutos)',
              helperText: 'Puedes corregirla si empezaste a apuntar tarde.',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          _SummaryLine('Series hechas', '${draft.doneSets}'),
          _SummaryLine('Volumen', '${formatKg(draft.liftedKg)} kg'),
          _SummaryLine('Ejercicios', '${draft.doneExercises}'),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Seguir entrenando'),
          ),
        ],
      ),
    );
  }
}

/// Una línea del resumen: texto a la izquierda y valor a la derecha.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
