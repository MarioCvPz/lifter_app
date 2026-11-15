import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../data/workout_draft.dart';
import '../../models/models.dart';
import 'exercise_card.dart';
import 'exercise_info_sheet.dart';
import 'exercise_menu.dart';
import 'exercise_picker.dart';
import 'finish_workout_sheet.dart';
import 'live_workout_header.dart';
import 'rest_timer.dart';

/// Abre el entrenamiento en directo del día [workout]: con el día del plan
/// (sus series, repeticiones y descanso) o, si es la rutina del
/// entrenador, con ella. Con [replace], la pantalla nueva sustituye a la
/// actual (desde la vista previa), así al terminar se vuelve atrás del
/// todo y no a la vista previa.
void startDayWorkout(
  BuildContext context,
  DayWorkout workout, {
  bool replace = false,
}) {
  final planDay = workout.planDay;
  final route = MaterialPageRoute<void>(
    builder: (_) => planDay != null
        ? LiveWorkoutScreen(planDay: planDay)
        : LiveWorkoutScreen(routine: workout.routine),
  );
  final navigator = Navigator.of(context);
  if (replace) {
    navigator.pushReplacement(route);
  } else {
    navigator.push(route);
  }
}

/// Pantalla del entrenamiento en directo: cronómetro, ejercicios con sus
/// series y resumen en vivo. Se abre desde un día del plan ([planDay]),
/// desde una rutina ([routine]) o vacía (sin ninguno de los dos).
class LiveWorkoutScreen extends StatefulWidget {
  const LiveWorkoutScreen({super.key, this.planDay, this.routine});

  final PlanDay? planDay;
  final Routine? routine;

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  late final WorkoutDraft _draft;

  /// Repinta la pantalla cada segundo para que avance el cronómetro.
  Timer? _ticker;

  /// Hora del último repintado. El tiempo se calcula siempre como
  /// [_now] − inicio, no sumando segundos, así que no se desajusta.
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    final planDay = widget.planDay;
    final routine = widget.routine;
    if (planDay != null) {
      _draft = WorkoutDraft.fromPlanDay(planDay, _now);
    } else if (routine != null) {
      _draft = WorkoutDraft.fromRoutine(routine, _now);
    } else {
      _draft = WorkoutDraft.empty(_now);
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Cuenta atrás del descanso (usa el mismo Timer que el cronómetro).
  final RestCountdown _rest = RestCountdown();

  /// "Descanso automático": activado por defecto.
  bool _autoRest = true;

  /// Cada segundo: avanza el reloj y, si el descanso acaba de terminar,
  /// vibra (vibración corta del propio Flutter, sin paquetes) y quita la
  /// barra.
  void _tick() {
    setState(() => _now = DateTime.now());
    if (_rest.finishIfDue(_now)) HapticFeedback.vibrate();
  }

  void _startRest(int seconds) {
    setState(() {
      _now = DateTime.now();
      _rest.start(seconds, _now);
    });
  }

  Future<void> _openRestTimer() async {
    final seconds = await showRestTimerSheet(
      context,
      autoRest: _autoRest,
      onAutoRestChanged: (value) => setState(() => _autoRest = value),
    );
    if (seconds != null && mounted) _startRest(seconds);
  }

  /// La barra de descanso, o null si no hay ninguno en marcha.
  Widget? _restBar() {
    if (!_rest.isRunning) return null;
    return RestTimerBar(
      remainingSeconds: _rest.remainingSeconds(_now),
      totalSeconds: _rest.totalSeconds,
      onAdd: () => setState(() => _rest.add(RestCountdown.step, _now)),
      onSubtract: () => setState(() => _rest.add(-RestCountdown.step, _now)),
      onSkip: () => setState(_rest.skip),
    );
  }

  @override
  void dispose() {
    // Sin esto, el Timer seguiría llamando a setState con la pantalla ya
    // cerrada (y daría error).
    _ticker?.cancel();
    super.dispose();
  }

  void _onMenu(WorkoutMenuAction action) {
    switch (action) {
      case WorkoutMenuAction.addExercise:
        _addExercise();
      case WorkoutMenuAction.discard:
        _discard();
    }
  }

  /// Pregunta y, si confirma, sale sin guardar. `Navigator.pop` sale
  /// aunque el [PopScope] bloquee el botón atrás (ese solo para el gesto
  /// del sistema).
  Future<void> _discard() async {
    final discard = await confirmDiscardWorkout(context);
    if (discard && mounted) Navigator.of(context).pop();
  }

  /// Comprueba las series, enseña el resumen y guarda el entreno.
  Future<void> _finish() async {
    final error = _draft.finishError();
    if (error != null) {
      _showError(error);
      return;
    }
    final minutes = await showFinishWorkoutSheet(
      context,
      draft: _draft,
      durationMin: _draft.durationMin(DateTime.now()),
    );
    // null: ha pulsado "Seguir entrenando". mounted: la pantalla sigue
    // abierta (después de un await siempre hay que comprobarlo).
    if (minutes == null || !mounted) return;
    final now = DateTime.now();
    final workout = _draft.toWorkout(
      id: now.millisecondsSinceEpoch.toString(),
      date: now,
      durationMin: minutes,
    );
    final store = SessionScope.of(context);
    store.addWorkout(workout);
    await _offerSaveChanges(store);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Entrenamiento guardado.')));
    Navigator.of(context).pop();
  }

  /// Si ha añadido, quitado o sustituido ejercicios, pregunta si guarda
  /// los cambios en el día del plan o en su rutina (solo si es suya, no
  /// una plantilla ni la de su entrenador). Con "Solo hoy" no cambia nada.
  Future<void> _offerSaveChanges(AppStore store) async {
    if (!_draft.hasChanges) return;
    final planDay = widget.planDay;
    final routine = widget.routine;
    final profile = store.user;
    if (planDay != null && profile != null) {
      // El día como está ahora en el plan (por si ha cambiado mientras
      // entrenaba).
      final current = store.plan?.dayFor(planDay.weekday);
      if (current == null) return;
      if (await askSaveChanges(context, target: 'tu plan')) {
        store.updatePlanDay(_draft.applyToPlanDay(current, profile));
      }
    } else if (routine != null && store.isOwnRoutine(routine.id)) {
      if (await askSaveChanges(context, target: 'tu rutina')) {
        store.addRoutine(_draft.applyToRoutine(routine));
      }
    }
  }

  // ------------------------------------------ Añadir y menú ⋯ --

  /// "Sugeridos para este día" si el entreno sale del plan.
  List<Exercise> _planSuggestions(AppStore store) {
    final planDay = widget.planDay;
    if (planDay == null) return const [];
    return store.planSuggestions(
      store.plan?.dayFor(planDay.weekday) ?? planDay,
    );
  }

  /// Abre la lista y añade el ejercicio elegido en [index] (al final si
  /// es null).
  Future<void> _addExercise({int? index}) async {
    final store = SessionScope.of(context);
    final chosen = await showExercisePicker(
      context,
      title: 'Añadir ejercicio',
      catalog: store.exercises,
      suggested: _planSuggestions(store),
      excludeIds: _draft.exerciseIds,
    );
    if (chosen == null || !mounted) return;
    setState(() => _draft.insert(chosen, index: index));
  }

  /// Abre la lista con los del mismo patrón arriba y sustituye.
  Future<void> _replaceExercise(int index) async {
    final store = SessionScope.of(context);
    final old = _draft.exercises[index].exercise;
    final chosen = await showExercisePicker(
      context,
      title: 'Sustituir ${old.name}',
      catalog: store.exercises,
      suggested: store.substituteSuggestions(old, exclude: _draft.exerciseIds),
      suggestedTitle: 'Del mismo patrón',
      excludeIds: _draft.exerciseIds,
    );
    if (chosen == null || !mounted) return;
    setState(() => _draft.replaceAt(index, chosen));
  }

  Future<void> _editComment(DraftExercise item) async {
    final text = await askExerciseComment(
      context,
      exerciseName: item.exercise.name,
      current: item.comment,
    );
    if (text == null || !mounted) return;
    setState(() => item.comment = text);
  }

  Future<void> _removeExercise(int index) async {
    final name = _draft.exercises[index].exercise.name;
    if (await confirmRemoveExercise(context, name) && mounted) {
      setState(() => _draft.removeAt(index));
    }
  }

  void _onExerciseMenu(int index, ExerciseMenuAction action) {
    final item = _draft.exercises[index];
    switch (action) {
      case ExerciseMenuAction.addAfter:
        _addExercise(index: index + 1); // justo después de este
      case ExerciseMenuAction.info:
        showExerciseInfoSheet(context, item.exercise);
      case ExerciseMenuAction.replace:
        _replaceExercise(index);
      case ExerciseMenuAction.comment:
        _editComment(item);
      case ExerciseMenuAction.moveUp:
        setState(() => _draft.move(index, -1));
      case ExerciseMenuAction.moveDown:
        setState(() => _draft.move(index, 1));
      case ExerciseMenuAction.remove:
        _removeExercise(index);
    }
  }

  /// Series de la última vez de cada ejercicio, guardadas por id para no
  /// recalcularlas cada segundo al repintar el cronómetro.
  final Map<String, List<WorkoutSet>> _lastSets = {};

  List<WorkoutSet> _lastSetsOf(Exercise exercise) => _lastSets.putIfAbsent(
    exercise.id,
    () => SessionScope.of(context).lastSetsOf(exercise.id),
  );

  /// Muestra [error] abajo, si hay alguno.
  void _showError(String? error) {
    if (error == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  void _toggleSet(DraftExercise item, int index) {
    final hint = DraftExercise.hintFor(_lastSetsOf(item.exercise), index);
    String? error;
    setState(() => error = item.toggleSet(index, hint));
    _showError(error);
    // Descanso automático: solo al marcarla (no al desmarcarla).
    if (_autoRest && item.sets[index].done) _startRest(item.restSeconds);
  }

  void _markAll(DraftExercise item) {
    String? error;
    setState(() => error = item.markAll(_lastSetsOf(item.exercise)));
    _showError(error);
  }

  Widget _exerciseCard(int index) {
    final item = _draft.exercises[index];
    return ExerciseCard(
      // Al quitar o mover ejercicios, cada tarjeta conserva sus series.
      key: ObjectKey(item),
      number: index + 1,
      item: item,
      lastSets: _lastSetsOf(item.exercise),
      // El valor ya está en el borrador: solo hay que repintar el resumen.
      onChanged: () => setState(() {}),
      onToggleSet: (setIndex) => _toggleSet(item, setIndex),
      onAddSet: () => setState(item.addSet),
      onDeleteSet: (setIndex) => setState(() => item.removeSet(setIndex)),
      onMarkAll: () => _markAll(item),
      onHistory: () =>
          showExerciseInfoSheet(context, item.exercise, showHistory: true),
      onMenu: (action) => _onExerciseMenu(index, action),
      isFirst: index == 0,
      isLast: index == _draft.exercises.length - 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // El botón atrás no sale directamente: pregunta si se descarta.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discard();
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    return Scaffold(
      appBar: LiveWorkoutAppBar(
        elapsed: _draft.elapsed(_now),
        onRestTimer: _openRestTimer,
        onMenu: _onMenu,
      ),
      bottomNavigationBar: _restBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          WorkoutSummaryHeader(name: _draft.name, summary: _draft.summary),
          const SizedBox(height: 16),
          for (var i = 0; i < _draft.exercises.length; i++) _exerciseCard(i),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Añadir ejercicio'),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _finish,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Terminar entrenamiento'),
          ),
        ],
      ),
    );
  }
}
