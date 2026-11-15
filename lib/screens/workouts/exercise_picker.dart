import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../models/models.dart';

/// Abre la lista para elegir un ejercicio. Es la misma para "Añadir
/// ejercicio" y para "Sustituir":
/// - arriba, el buscador y chips para ver un solo grupo muscular;
/// - después, si hay, la sección [suggestedTitle] con [suggested];
/// - debajo, el catálogo dividido por grupo muscular y en orden alfabético.
/// No muestra los ejercicios de [excludeIds] (los que ya están en el
/// entreno). Devuelve el ejercicio elegido, o null si se cierra.
Future<Exercise?> showExercisePicker(
  BuildContext context, {
  required String title,
  required List<Exercise> catalog,
  List<Exercise> suggested = const [],
  String suggestedTitle = 'Sugeridos para este día',
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExercisePicker(
      title: title,
      catalog: catalog,
      suggested: suggested,
      suggestedTitle: suggestedTitle,
      excludeIds: excludeIds,
    ),
  );
}

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({
    required this.title,
    required this.catalog,
    required this.suggested,
    required this.suggestedTitle,
    required this.excludeIds,
  });

  final String title;
  final List<Exercise> catalog;
  final List<Exercise> suggested;
  final String suggestedTitle;
  final Set<String> excludeIds;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _query = '';

  /// Grupo elegido en los chips; null = todos.
  String? _group;

  /// Lista visible según el buscador y el chip, sin los excluidos.
  List<Exercise> _visible(List<Exercise> list) => filterExercises(
    [
      for (final e in list)
        if (!widget.excludeIds.contains(e.id)) e,
    ],
    query: _query,
    group: _group,
  );

  @override
  Widget build(BuildContext context) {
    final suggested = _visible(widget.suggested);
    final suggestedIds = {for (final e in suggested) e.id};
    // Los sugeridos no se repiten abajo, en el catálogo.
    final rest = _visible([
      for (final e in widget.catalog)
        if (!suggestedIds.contains(e.id)) e,
    ]);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar ejercicio',
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 8),
          _GroupChips(
            selected: _group,
            onSelected: (group) => setState(() => _group = group),
          ),
          if (widget.catalog.isEmpty)
            const ListTile(
              title: Text('El catálogo de ejercicios está vacío.'),
            ),
          if (suggested.isNotEmpty) ...[
            _SectionTitle(widget.suggestedTitle),
            for (final e in suggested) _ExerciseTile(e),
          ],
          for (final group in exercisesByMuscle(rest).entries) ...[
            _SectionTitle(group.key),
            for (final e in group.value) _ExerciseTile(e),
          ],
          if (suggested.isEmpty && rest.isEmpty && widget.catalog.isNotEmpty)
            const ListTile(title: Text('No hay ejercicios con ese nombre.')),
        ],
      ),
    );
  }
}

/// Chips "Todos", "Pecho", "Espalda"… en una fila que se desliza.
class _GroupChips extends StatelessWidget {
  const _GroupChips({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final group in [null, ...muscleGroups])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(group ?? 'Todos'),
                selected: selected == group,
                onSelected: (_) => onSelected(group),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Un ejercicio de la lista. Al pulsarlo, se cierra la hoja con él.
class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(exercise.name),
      subtitle: Text('${exercise.equipment} · ${exercise.level}'),
      onTap: () => Navigator.pop(context, exercise),
    );
  }
}
