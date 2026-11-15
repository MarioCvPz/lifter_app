import 'package:flutter/material.dart';

/// Opciones del menú ⋯ de cada ejercicio. Es el único sitio de la app
/// donde se añaden, sustituyen o quitan ejercicios del entreno.
enum ExerciseMenuAction {
  addAfter('Añadir ejercicio', Icons.add),
  info('Cómo hacerlo / Historial', Icons.info_outline),
  replace('Sustituir por otro ejercicio', Icons.swap_horiz),
  comment('Comentario de hoy', Icons.chat_bubble_outline),
  moveUp('Subir', Icons.arrow_upward),
  moveDown('Bajar', Icons.arrow_downward),
  remove('Eliminar ejercicio', Icons.delete_outline);

  const ExerciseMenuAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Pide el comentario de hoy del ejercicio. Devuelve el texto nuevo (vacío
/// para borrarlo) o null si se cancela.
Future<String?> askExerciseComment(
  BuildContext context, {
  required String exerciseName,
  required String current,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _CommentDialog(exerciseName: exerciseName, current: current),
  );
}

/// Pregunta antes de quitar un ejercicio del entreno. True si se confirma.
Future<bool> confirmRemoveExercise(
  BuildContext context,
  String exerciseName,
) async {
  final remove = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Eliminar ejercicio?'),
      content: Text('Se quitará "$exerciseName" y sus series de hoy.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  return remove ?? false;
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.exerciseName, required this.current});

  final String exerciseName;
  final String current;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  /// Largo máximo del comentario (cabe en una tarjeta del entrenador).
  static const maxLength = 200;

  late final TextEditingController _text = TextEditingController(
    text: widget.current,
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comentario: ${widget.exerciseName}'),
      content: TextField(
        controller: _text,
        autofocus: true,
        maxLines: 3,
        maxLength: maxLength,
        decoration: const InputDecoration(
          hintText: 'Por ejemplo: molestia en el hombro en la última serie',
          helperText: 'Lo verá también tu entrenador.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _text.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
