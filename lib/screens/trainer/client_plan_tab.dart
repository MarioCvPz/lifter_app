import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/coach_plan.dart';
import '../../data/routine_generator.dart';
import '../../models/models.dart';
import '../../widgets/confirm_dialog.dart';
import '../workouts/exercise_picker.dart';
import 'prescription_dialog.dart';

/// Pestaña "Plan" de la ficha de un cliente: su plan semanal por días. El
/// entrenador puede cambiar, añadir o quitar ejercicios y editar series,
/// repeticiones, descanso y nota. Cada cambio se guarda al momento en
/// `users/{cliente}/plan/current`.
class ClientPlanTab extends StatefulWidget {
  const ClientPlanTab({super.key, required this.client});

  final AppUser client;

  @override
  State<ClientPlanTab> createState() => _ClientPlanTabState();
}

class _ClientPlanTabState extends State<ClientPlanTab> {
  TrainingPlan? _plan;
  bool _loading = true;
  String? _error;

  /// True cuando ya se ha pedido el plan (didChangeDependencies se llama
  /// cada vez que cambia el AppStore, y solo hay que cargarlo una vez).
  bool _started = false;

  UserProfile get _profile => widget.client.profile;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    final store = SessionScope.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await store.fetchPlanOf(widget.client.uid);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el plan: $e';
        _loading = false;
      });
    }
  }

  /// Pone [day] en el plan y lo guarda. Si falla, avisa y recarga.
  Future<void> _saveDay(PlanDay day) async {
    final current = _plan;
    if (current == null) return;
    final next = current.withDay(day);
    setState(() => _plan = next);
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await store.saveClientPlan(widget.client.uid, next);
    if (error == null) return;
    messenger.showSnackBar(SnackBar(content: Text(error)));
    if (mounted) await _load();
  }

  /// Si el cliente no puede hacer [exercise] (material o lesión), pregunta
  /// antes. Devuelve true si se sigue adelante.
  Future<bool> _acceptWarning(Exercise exercise, String action) async {
    final warning = CoachPlan.warningFor(exercise, _profile);
    if (warning == null) return true;
    return confirmAction(
      context,
      title: 'Ojo con ${exercise.name}',
      message: warning,
      confirmLabel: '$action igualmente',
    );
  }

  Future<Exercise?> _pick(PlanDay day, String title) {
    final store = SessionScope.of(context);
    return showExercisePicker(
      context,
      title: title,
      catalog: store.exercises,
      suggested: RoutineGenerator.suggestionsFor(
        day,
        _profile,
        store.exercises,
      ),
      excludeIds: {for (final e in day.exercises) e.exercise.id},
    );
  }

  Future<void> _add(PlanDay day) async {
    final exercise = await _pick(day, 'Añadir ejercicio');
    if (exercise == null || !await _acceptWarning(exercise, 'Añadir')) return;
    await _saveDay(CoachPlan.add(day, exercise, _profile));
  }

  Future<void> _replace(PlanDay day, PlanExercise old) async {
    final exercise = await _pick(day, 'Cambiar ${old.exercise.name}');
    if (exercise == null || !await _acceptWarning(exercise, 'Cambiar')) return;
    await _saveDay(CoachPlan.replace(day, old.exercise.id, exercise, _profile));
  }

  Future<void> _edit(PlanDay day, PlanExercise exercise) async {
    final changed = await showPrescriptionDialog(context, exercise);
    if (changed == null) return;
    await _saveDay(CoachPlan.update(day, changed));
  }

  void _onAction(PlanDay day, PlanExercise exercise, _ExerciseAction action) {
    switch (action) {
      case _ExerciseAction.edit:
        _edit(day, exercise);
      case _ExerciseAction.replace:
        _replace(day, exercise);
      case _ExerciseAction.remove:
        _saveDay(day.withoutExercise(exercise.exercise.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final error = _error;
    if (error != null) {
      return _Message(text: error, onRetry: _load);
    }
    final plan = _plan;
    if (plan == null || plan.days.isEmpty) {
      return const _Message(
        text:
            'Tu cliente todavía no tiene plan. Se crea cuando completa el '
            'cuestionario inicial.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Lo que cambies queda marcado como tuyo y se mantiene aunque se '
          'actualice su plan.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        for (final day in plan.days)
          _DayCard(
            day: day,
            onAdd: () => _add(day),
            onAction: (exercise, action) => _onAction(day, exercise, action),
          ),
      ],
    );
  }
}

enum _ExerciseAction {
  edit('Series, reps y nota', Icons.edit_outlined),
  replace('Cambiar', Icons.swap_horiz),
  remove('Quitar', Icons.delete_outline);

  const _ExerciseAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Un día del plan con sus ejercicios y "Añadir ejercicio".
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.onAdd,
    required this.onAction,
  });

  final PlanDay day;
  final VoidCallback onAdd;
  final void Function(PlanExercise, _ExerciseAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.title, style: Theme.of(context).textTheme.titleMedium),
            for (final exercise in day.exercises)
              _ExerciseTile(
                exercise: exercise,
                onAction: (action) => onAction(exercise, action),
              ),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Añadir ejercicio'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un ejercicio: nombre, "4 × 8–12 · 90 s", su nota y el menú ⋯.
class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise, required this.onAction});

  final PlanExercise exercise;
  final ValueChanged<_ExerciseAction> onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final e = exercise;
    final note = e.trainerNote;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: e.byTrainer
          ? Tooltip(
              message: 'Cambiado por ti',
              child: Icon(Icons.sports, color: scheme.primary),
            )
          : const Icon(Icons.fitness_center),
      title: Text(e.exercise.name),
      subtitle: Text(
        '${e.sets} × ${e.minReps}–${e.maxReps} · ${e.restSeconds} s'
        '${note == null ? '' : '\nNota: $note'}',
      ),
      isThreeLine: note != null,
      trailing: PopupMenuButton<_ExerciseAction>(
        tooltip: 'Opciones',
        onSelected: onAction,
        itemBuilder: (_) => [
          for (final action in _ExerciseAction.values)
            PopupMenuItem(
              value: action,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(action.icon),
                title: Text(action.label),
              ),
            ),
        ],
      ),
    );
  }
}

/// Texto centrado con un botón "Reintentar" opcional.
class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final retry = onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (retry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: retry, child: const Text('Reintentar')),
            ],
          ],
        ),
      ),
    );
  }
}
