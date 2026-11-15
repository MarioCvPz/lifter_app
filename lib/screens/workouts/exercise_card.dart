import 'package:flutter/material.dart';

import '../../data/workout_draft.dart';
import '../../models/models.dart';
import 'exercise_menu.dart';
import 'set_row.dart';

/// Tarjeta de un ejercicio del entrenamiento en directo: número, nombre,
/// etiquetas con el objetivo, una fila por serie y los botones "Añadir
/// serie", "Historial" y ✓✓.
///
/// No cambia el borrador por su cuenta (salvo lo que se escribe en los
/// campos): avisa a la pantalla con los callbacks y la pantalla hace el
/// cambio y repinta.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.number,
    required this.item,
    required this.lastSets,
    required this.onChanged,
    required this.onToggleSet,
    required this.onAddSet,
    required this.onDeleteSet,
    required this.onMarkAll,
    required this.onHistory,
    required this.onMenu,
    required this.isFirst,
    required this.isLast,
  });

  /// Posición en el entreno (1, 2, 3…).
  final int number;
  final DraftExercise item;

  /// Series de la última vez, para las pistas.
  final List<WorkoutSet> lastSets;

  final VoidCallback onChanged;
  final ValueChanged<int> onToggleSet;
  final VoidCallback onAddSet;

  /// Borra la serie de esa posición (al deslizar su fila).
  final ValueChanged<int> onDeleteSet;
  final VoidCallback onMarkAll;

  final VoidCallback onHistory;
  final ValueChanged<ExerciseMenuAction> onMenu;

  /// Para desactivar "Subir" en el primero y "Bajar" en el último.
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardTitle(number: number, name: item.exercise.name, menu: _menu()),
            _TargetTags(item),
            if (item.comment.isNotEmpty) _Comment(item.comment),
            const SizedBox(height: 8),
            const _SetsHeader(),
            for (var i = 0; i < item.sets.length; i++) _setRow(context, i),
            _CardActions(
              onAddSet: onAddSet,
              onHistory: onHistory,
              onMarkAll: onMarkAll,
            ),
          ],
        ),
      ),
    );
  }

  /// Botón ⋯ con las opciones del ejercicio.
  Widget _menu() {
    return PopupMenuButton<ExerciseMenuAction>(
      tooltip: 'Opciones del ejercicio',
      icon: const Icon(Icons.more_horiz),
      onSelected: onMenu,
      itemBuilder: (_) => [
        for (final action in ExerciseMenuAction.values)
          PopupMenuItem(
            value: action,
            enabled:
                !(action == ExerciseMenuAction.moveUp && isFirst) &&
                !(action == ExerciseMenuAction.moveDown && isLast),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(action.icon),
              title: Text(action.label),
            ),
          ),
      ],
    );
  }

  /// Fila de la serie [i]. Se puede borrar deslizándola hacia la izquierda.
  Widget _setRow(BuildContext context, int i) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      // La key hace que cada fila conserve sus campos aunque se añadan o
      // se borren series.
      key: ObjectKey(item.sets[i]),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      onDismissed: (_) => onDeleteSet(i),
      child: SetRow(
        number: i + 1,
        set: item.sets[i],
        hint: DraftExercise.hintFor(lastSets, i),
        onChanged: onChanged,
        onToggle: () => onToggleSet(i),
      ),
    );
  }
}

/// Número de orden, nombre y botón ⋯.
class _CardTitle extends StatelessWidget {
  const _CardTitle({
    required this.number,
    required this.name,
    required this.menu,
  });

  final int number;
  final String name;
  final Widget menu;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: Text('$number', style: const TextStyle(fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        menu,
      ],
    );
  }
}

/// Comentario de hoy, bajo el nombre.
class _Comment extends StatelessWidget {
  const _Comment(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, right: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiquetas pequeñas: "4 series", "8–12 reps" y "Descanso 1:30".
class _TargetTags extends StatelessWidget {
  const _TargetTags(this.item);

  final DraftExercise item;

  @override
  Widget build(BuildContext context) {
    final repsLabel = item.repsLabel;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Tag(item.setsLabel),
        if (repsLabel != null) _Tag(repsLabel),
        _Tag(item.restLabel),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}

/// Títulos de las columnas, alineados con [SetRow].
class _SetsHeader extends StatelessWidget {
  const _SetsHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: SetColumns.numberWidth,
            child: Text('Serie', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Kg', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Reps', style: style, textAlign: TextAlign.center),
          ),
          const SizedBox(width: SetColumns.checkWidth),
        ],
      ),
    );
  }
}

/// "Añadir serie", "Historial" y ✓✓ (marcar todas).
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.onAddSet,
    required this.onMarkAll,
    required this.onHistory,
  });

  final VoidCallback onAddSet;
  final VoidCallback onMarkAll;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // En pantallas estrechas, los dos botones pasan a otra línea en
        // vez de salirse de la tarjeta.
        Expanded(
          child: Wrap(
            children: [
              TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add),
                label: const Text('Añadir serie'),
              ),
              TextButton.icon(
                onPressed: onHistory,
                icon: const Icon(Icons.history),
                label: const Text('Historial'),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Marcar todas las series',
          onPressed: onMarkAll,
          icon: const Icon(Icons.done_all),
        ),
      ],
    );
  }
}
