import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../workouts/live_workout_screen.dart';

/// Diálogo para crear una rutina (nombre, descripción y ejercicios) a partir
/// de [exercises] (el catálogo). Con [initial] edita esa rutina manteniendo su
/// id. Con [askRecommendedDays] pide también para cuántos días por semana se
/// recomienda (plantillas). Devuelve null si se cancela.
Future<Routine?> showRoutineEditor(
  BuildContext context, {
  required List<Exercise> exercises,
  String title = 'Nueva rutina',
  String templateName = 'Personal',
  Routine? initial,
  bool askRecommendedDays = false,
}) {
  return showDialog<Routine>(
    context: context,
    builder: (_) => _RoutineEditorDialog(
      title: title,
      templateName: templateName,
      exercises: exercises,
      initial: initial,
      askRecommendedDays: askRecommendedDays,
    ),
  );
}

/// Los controladores viven en el State del diálogo para liberarlos cuando
/// el diálogo ya se ha cerrado del todo (no al acabar showDialog, que vuelve
/// antes de que termine la animación de cierre).
class _RoutineEditorDialog extends StatefulWidget {
  const _RoutineEditorDialog({
    required this.title,
    required this.templateName,
    required this.exercises,
    required this.initial,
    required this.askRecommendedDays,
  });

  final String title;
  final String templateName;
  final List<Exercise> exercises;
  final Routine? initial;
  final bool askRecommendedDays;

  @override
  State<_RoutineEditorDialog> createState() => _RoutineEditorDialogState();
}

class _RoutineEditorDialogState extends State<_RoutineEditorDialog> {
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _description = TextEditingController(
    text: widget.initial?.description,
  );
  late final _templateName = TextEditingController(
    text: widget.initial?.templateName ?? widget.templateName,
  );
  late final _selected = <Exercise>[...?widget.initial?.exercises];
  late int _days = widget.initial?.recommendedDays ?? 3;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _templateName.dispose();
    super.dispose();
  }

  void _save() {
    final initial = widget.initial;
    final tag = _templateName.text.trim();
    Navigator.pop(
      context,
      Routine(
        id: initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        description: _description.text.trim(),
        templateName: widget.askRecommendedDays && tag.isNotEmpty
            ? tag
            : initial?.templateName ?? widget.templateName,
        isTemplate: initial?.isTemplate ?? widget.askRecommendedDays,
        recommendedDays: widget.askRecommendedDays
            ? _days
            : initial?.recommendedDays,
        exercises: List.of(_selected),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)',
                ),
              ),
              if (widget.askRecommendedDays) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _templateName,
                  decoration: const InputDecoration(
                    labelText: 'Etiqueta (p. ej. Full body)',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Expanded(child: Text('Recomendada para')),
                    DropdownButton<int>(
                      value: _days,
                      items: [
                        for (var d = 1; d <= 7; d++)
                          DropdownMenuItem(
                            value: d,
                            child: Text('$d ${d == 1 ? 'día' : 'días'}/sem'),
                          ),
                      ],
                      onChanged: (d) => setState(() => _days = d ?? _days),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_selected.length} ejercicios elegidos',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.exercises.isEmpty)
                const Text(
                  'El catálogo de ejercicios está vacío. Un admin tiene que '
                  'cargarlo desde Administración.',
                ),
              for (final ex in widget.exercises)
                CheckboxListTile(
                  dense: true,
                  value: _selected.contains(ex),
                  title: Text(ex.name),
                  subtitle: Text(ex.muscleGroup),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selected.add(ex);
                      } else {
                        _selected.remove(ex);
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // Solo se puede guardar con nombre y al menos un ejercicio.
          onPressed: _name.text.trim().isEmpty || _selected.isEmpty
              ? null
              : _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

void startWorkoutFrom(BuildContext context, Routine routine) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LiveWorkoutScreen(routine: routine),
    ),
  );
}

/// Color de acento de una rutina (estable para cada rutina).
Color routineAccent(BuildContext context, Routine routine) {
  final scheme = Theme.of(context).colorScheme;
  final colors = [AppTheme.coral, scheme.secondary, scheme.tertiary];
  return colors[routine.id.hashCode.abs() % colors.length];
}

class RoutineCard extends StatelessWidget {
  const RoutineCard({
    super.key,
    required this.routine,
    this.caption,
    this.onDelete,
    this.showUse = true,
  });

  final Routine routine;

  /// Texto extra (p. ej. quién la asignó).
  final String? caption;

  /// Si no es null, aparece el botón de borrar (con confirmación).
  final VoidCallback? onDelete;

  final bool showUse;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar rutina?'),
        content: Text('Se borrará "${routine.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) onDelete!();
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _RoutineDetail(routine: routine, showUse: showUse),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final accent = routineAccent(context, routine);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera con degradado del color de la rutina.
          Container(
            height: 136,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  accent.withValues(alpha: 0.45),
                  scheme.surfaceContainer,
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -16,
                  bottom: -20,
                  child: Icon(
                    Icons.fitness_center,
                    size: 130,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      _Tag(label: routine.templateName),
                      const SizedBox(width: 6),
                      _Tag(label: routine.level, color: accent),
                      const Spacer(),
                      if (onDelete != null)
                        IconButton.filledTonal(
                          tooltip: 'Borrar rutina',
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          onPressed: () => _confirmDelete(context),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${routine.exercises.length} ejercicios · '
                        '${routine.muscleGroups.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 15,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '~${routine.estimatedMin} min',
                            style: text.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (caption != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            caption!,
                            style: text.labelSmall?.copyWith(
                              color: scheme.tertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showDetail(context),
                  style: TextButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHigh,
                    shape: const StadiumBorder(),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ver rutina'),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:
            color?.withValues(alpha: 0.9) ??
            scheme.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color == null ? scheme.onSurface : Colors.black87,
        ),
      ),
    );
  }
}

class _RoutineDetail extends StatelessWidget {
  const _RoutineDetail({required this.routine, required this.showUse});

  final Routine routine;
  final bool showUse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      builder: (ctx, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(routine.name, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${routine.level} · ${routine.exercises.length} ejercicios · '
              '~${routine.estimatedMin} min',
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (routine.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(routine.description),
            ],
            const SizedBox(height: 16),
            for (var i = 0; i < routine.exercises.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.surfaceContainerHighest,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(routine.exercises[i].name),
                  subtitle: Text(
                    '${routine.exercises[i].muscleGroup} · '
                    '${routine.exercises[i].equipment}',
                  ),
                ),
              ),
            if (showUse) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  // Se coge el navigator antes de cerrar la hoja.
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) =>
                          LiveWorkoutScreen(routine: routine),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Empezar entreno'),
              ),
            ],
          ],
        );
      },
    );
  }
}
