import '../models/models.dart';
import 'routine_generator.dart';

// Borrador del entrenamiento en directo. Es Dart puro (sin Flutter ni
// Firebase): la pantalla lo modifica y lo dibuja, y los tests lo prueban
// directamente. Solo al terminar se convierte en un [Workout].

/// Una serie mientras se entrena. [weightKg] y [reps] son null mientras el
/// campo está vacío (entonces se ve la pista de la última vez).
class DraftSet {
  DraftSet({this.weightKg, this.reps, this.done = false});

  double? weightKg;
  int? reps;

  /// True cuando el usuario la ha marcado con ✓. Solo se guardan estas.
  bool done;

  /// Kilos levantados en la serie (reps × kg). Un peso vacío cuenta como
  /// 0 kg (peso corporal).
  double get liftedKg => (reps ?? 0) * (weightKg ?? 0);
}

/// Un ejercicio del entrenamiento con su objetivo (series, repeticiones y
/// descanso), su comentario de hoy y sus series.
class DraftExercise {
  /// Empieza con tantas filas vacías como series objetivo.
  DraftExercise({
    required this.exercise,
    required this.targetSets,
    this.minReps,
    this.maxReps,
    this.restSeconds = defaultRestSeconds,
    this.originalId,
  }) : sets = [for (var i = 0; i < targetSets; i++) DraftSet()];

  /// Con el objetivo que marca el plan.
  factory DraftExercise.fromPlan(PlanExercise planned) => DraftExercise(
    exercise: planned.exercise,
    targetSets: planned.sets,
    minReps: planned.minReps,
    maxReps: planned.maxReps,
    restSeconds: planned.restSeconds,
    originalId: planned.exercise.id,
  );

  /// Con los valores por defecto (3 series, sin objetivo de reps y 90 s),
  /// para los ejercicios de una rutina o añadidos a mano.
  factory DraftExercise.basic(Exercise exercise, {String? originalId}) =>
      DraftExercise(
        exercise: exercise,
        targetSets: defaultSets,
        originalId: originalId,
      );

  static const defaultSets = 3;
  static const defaultRestSeconds = 90;

  final Exercise exercise;
  final int targetSets;

  /// Repeticiones objetivo; null si no hay objetivo.
  final int? minReps;
  final int? maxReps;
  final int restSeconds;

  /// Id del ejercicio del plan o de la rutina que ocupa este hueco, o null
  /// si se ha añadido hoy. Sirve para saber al terminar qué ha cambiado.
  final String? originalId;

  /// Comentario de hoy ("Molestia en el hombro…"). Vacío si no hay.
  String comment = '';

  final List<DraftSet> sets;

  /// Límites para validar lo que escribe el usuario.
  static const maxRepsPerSet = 100;
  static const maxWeightKg = 500.0;

  int get doneSets => sets.where((s) => s.done).length;

  /// Kilos levantados, contando solo las series marcadas.
  double get liftedKg =>
      sets.where((s) => s.done).fold(0, (total, s) => total + s.liftedKg);

  /// Etiquetas de la tarjeta: "4 series", "8–12 reps" (null si no hay
  /// objetivo) y "Descanso 1:30".
  String get setsLabel => '$targetSets ${targetSets == 1 ? 'serie' : 'series'}';

  String? get repsLabel {
    final min = minReps;
    final max = maxReps;
    if (min == null || max == null) return null;
    return min == max ? '$min reps' : '$min–$max reps';
  }

  String get restLabel => 'Descanso ${formatRest(restSeconds)}';

  /// Línea de la vista previa: "4 × 8–12 · 1:30", o "3 series · 1:30" si
  /// no hay objetivo de repeticiones.
  String get previewLabel {
    final min = minReps;
    final max = maxReps;
    final rest = formatRest(restSeconds);
    if (min == null || max == null) return '$setsLabel · $rest';
    final reps = min == max ? '$min' : '$min–$max';
    return '$targetSets × $reps · $rest';
  }

  /// Añade una fila vacía al final (con la pista de la última vez).
  void addSet() => sets.add(DraftSet());

  /// Borra la serie [index] (al deslizar su fila). Si se queda sin
  /// series, el ejercicio no se guardará.
  void removeSet(int index) => sets.removeAt(index);

  /// Pista para la serie [index]: la misma serie de la última vez o, si
  /// hoy hace más series que entonces, la última que hizo. Null si nunca
  /// ha hecho el ejercicio.
  static WorkoutSet? hintFor(List<WorkoutSet> lastSets, int index) {
    if (lastSets.isEmpty) return null;
    return index < lastSets.length ? lastSets[index] : lastSets.last;
  }

  /// Marca o desmarca la serie [index]. Al marcarla, los campos vacíos se
  /// rellenan con [hint] (la última vez). Devuelve un mensaje de error si
  /// la serie no es válida (y entonces no se marca), o null si todo va bien.
  String? toggleSet(int index, WorkoutSet? hint) {
    final set = sets[index];
    if (set.done) {
      set.done = false;
      return null;
    }
    final reps = set.reps ?? hint?.reps;
    // Sin peso escrito ni pista, cuenta como peso corporal (0 kg).
    final weight = set.weightKg ?? hint?.weightKg ?? 0;
    final error = validateSet(reps, weight);
    if (error != null) return error;
    set
      ..reps = reps
      ..weightKg = weight
      ..done = true;
    return null;
  }

  /// Marca todas las series que faltan (✓✓). Devuelve el primer error si
  /// alguna no se ha podido marcar; las demás sí quedan marcadas.
  String? markAll(List<WorkoutSet> lastSets) {
    String? firstError;
    for (var i = 0; i < sets.length; i++) {
      if (sets[i].done) continue;
      final error = toggleSet(i, hintFor(lastSets, i));
      firstError ??= error;
    }
    return firstError;
  }

  /// Comprueba las repeticiones (1–[maxRepsPerSet], obligatorias) y el
  /// peso (0–[maxWeightKg]). Devuelve el mensaje de error o null.
  static String? validateSet(int? reps, double weightKg) {
    if (reps == null || reps <= 0) {
      return 'Escribe las repeticiones de la serie (más de 0).';
    }
    if (reps > maxRepsPerSet) {
      return 'Como máximo $maxRepsPerSet repeticiones por serie.';
    }
    if (weightKg < 0 || weightKg > maxWeightKg) {
      return 'El peso tiene que estar entre 0 y ${formatKg(maxWeightKg)} kg.';
    }
    return null;
  }
}

/// El entrenamiento que se está haciendo ahora.
class WorkoutDraft {
  WorkoutDraft({
    required this.name,
    required this.startedAt,
    this.planDay,
    this.routine,
    List<DraftExercise>? exercises,
  }) : exercises = exercises ?? [];

  /// Desde un día del plan: con sus series, repeticiones y descanso.
  factory WorkoutDraft.fromPlanDay(PlanDay day, DateTime startedAt) =>
      WorkoutDraft(
        name: day.name,
        startedAt: startedAt,
        planDay: day,
        exercises: [for (final e in day.exercises) DraftExercise.fromPlan(e)],
      );

  /// Desde una rutina: con los valores por defecto.
  factory WorkoutDraft.fromRoutine(Routine routine, DateTime startedAt) =>
      WorkoutDraft(
        name: routine.name,
        startedAt: startedAt,
        routine: routine,
        exercises: [
          for (final e in routine.exercises)
            DraftExercise.basic(e, originalId: e.id),
        ],
      );

  /// Sin ejercicios, para empezar desde Entrenamientos.
  factory WorkoutDraft.empty(DateTime startedAt) =>
      WorkoutDraft(name: 'Entrenamiento', startedAt: startedAt);

  final String name;

  /// Cuándo se abrió la pantalla. El cronómetro se calcula como
  /// ahora − [startedAt], así no se desajusta aunque el Timer se retrase.
  final DateTime startedAt;

  /// Día del plan del que sale, si sale de uno.
  final PlanDay? planDay;

  /// Rutina de la que sale, si sale de una.
  final Routine? routine;

  final List<DraftExercise> exercises;

  int get totalSets => exercises.fold(0, (t, e) => t + e.sets.length);

  int get doneSets => exercises.fold(0, (t, e) => t + e.doneSets);

  double get liftedKg => exercises.fold(0, (t, e) => t + e.liftedKg);

  /// "3 de 12 series · 1250 kg levantados".
  String get summary =>
      '$doneSets de $totalSets series · ${formatKg(liftedKg)} kg levantados';

  /// Tiempo desde que se empezó. Nunca negativo (por si el reloj del
  /// móvil se atrasa).
  Duration elapsed(DateTime now) {
    final time = now.difference(startedAt);
    return time.isNegative ? Duration.zero : time;
  }

  /// Límite de la duración que se puede escribir al terminar (10 horas).
  static const maxDurationMin = 600;

  /// Minutos que se guardan: los del cronómetro redondeados, y como mínimo
  /// 1 (un entreno de 20 segundos cuenta como 1 minuto).
  int durationMin(DateTime now) {
    final minutes = (elapsed(now).inSeconds / 60).round();
    return minutes < 1 ? 1 : minutes;
  }

  /// Ejercicios con alguna serie marcada (los que se guardarán).
  int get doneExercises => exercises.where((e) => e.doneSets > 0).length;

  // ------------------------------------------ Cambios de ejercicios --

  /// Ids de los ejercicios que hay ahora (para no ofrecer los repetidos).
  Set<String> get exerciseIds => {for (final e in exercises) e.exercise.id};

  /// Ids de los ejercicios con los que empezó (los del plan o la rutina).
  Set<String> get _originalIds {
    final day = planDay;
    if (day != null) return {for (final e in day.exercises) e.exercise.id};
    return {for (final e in routine?.exercises ?? const <Exercise>[]) e.id};
  }

  /// True si ha añadido, quitado o sustituido algún ejercicio. Cambiar el
  /// orden no cuenta: solo vale para hoy.
  bool get hasChanges {
    final now = exerciseIds;
    final before = _originalIds;
    return now.length != before.length || !now.containsAll(before);
  }

  /// Añade [exercise] en la posición [index] (al final si es null), con
  /// los valores por defecto.
  void insert(Exercise exercise, {int? index}) => exercises.insert(
    index ?? exercises.length,
    DraftExercise.basic(exercise),
  );

  /// Pone [replacement] en lugar del ejercicio [index]. Mantiene el mismo
  /// objetivo (series, reps y descanso) y el mismo hueco del plan
  /// ([DraftExercise.originalId]); las series empiezan vacías.
  void replaceAt(int index, Exercise replacement) {
    final old = exercises[index];
    exercises[index] = DraftExercise(
      exercise: replacement,
      targetSets: old.targetSets,
      minReps: old.minReps,
      maxReps: old.maxReps,
      restSeconds: old.restSeconds,
      originalId: old.originalId,
    );
  }

  /// Sube (delta = −1) o baja (delta = 1) el ejercicio [index]. Si ya está
  /// en el borde, no hace nada.
  void move(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= exercises.length) return;
    final item = exercises.removeAt(index);
    exercises.insert(target, item);
  }

  void removeAt(int index) => exercises.removeAt(index);

  /// [day] con los cambios de hoy, usando los métodos de [PlanDay]:
  /// 1. los ejercicios del día que ya no están → [PlanDay.withoutExercise];
  /// 2. los sustituidos → [PlanDay.replacing];
  /// 3. los añadidos → [PlanDay.withExercise] (al final del día).
  /// Los nuevos se prescriben con el perfil y quedan como `isCustom`.
  PlanDay applyToPlanDay(PlanDay day, UserProfile profile) {
    PlanExercise custom(Exercise e) =>
        RoutineGenerator.prescribe(e, profile, isCustom: true);
    final kept = {
      for (final e in exercises)
        if (e.originalId != null) e.originalId,
    };
    var result = day;
    for (final planned in day.exercises) {
      if (!kept.contains(planned.exercise.id)) {
        result = result.withoutExercise(planned.exercise.id);
      }
    }
    for (final item in exercises) {
      final originalId = item.originalId;
      if (originalId == null) {
        if (!result.contains(item.exercise.id)) {
          result = result.withExercise(custom(item.exercise));
        }
      } else if (originalId != item.exercise.id) {
        result = result.replacing(originalId, custom(item.exercise));
      }
    }
    return result;
  }

  /// [original] con los ejercicios de hoy, en el orden de hoy.
  Routine applyToRoutine(Routine original) => Routine(
    id: original.id,
    name: original.name,
    description: original.description,
    templateName: original.templateName,
    exercises: [for (final e in exercises) e.exercise],
  );

  /// Error que impide guardar, o null si se puede:
  /// - si no hay ninguna serie marcada;
  /// - si una serie marcada se ha cambiado después a un valor no válido
  ///   (por ejemplo, borrando sus repeticiones).
  String? finishError() {
    if (doneSets == 0) {
      return 'Marca al menos una serie para guardar el entrenamiento.';
    }
    for (final item in exercises) {
      for (final set in item.sets.where((s) => s.done)) {
        final error = DraftExercise.validateSet(set.reps, set.weightKg ?? 0);
        if (error != null) return '${item.exercise.name}: $error';
      }
    }
    return null;
  }

  /// El entreno que se guarda: solo las series marcadas, y sin los
  /// ejercicios que no tienen ninguna. Llamar después de comprobar
  /// [finishError].
  Workout toWorkout({
    required String id,
    required DateTime date,
    required int durationMin,
  }) => Workout(
    id: id,
    name: name,
    date: date,
    durationMin: durationMin,
    routineId: routine?.id,
    exercises: [
      for (final item in exercises)
        if (item.doneSets > 0)
          WorkoutExercise(
            exercise: item.exercise,
            sets: [
              for (final set in item.sets)
                if (set.done)
                  // finishError ya ha comprobado que reps no es null; el
                  // `?? 0` solo evita usar `!`.
                  WorkoutSet(reps: set.reps ?? 0, weightKg: set.weightKg ?? 0),
            ],
            comment: item.comment.trim().isEmpty ? null : item.comment.trim(),
          ),
    ],
  );
}

/// Tiempo para el cronómetro: "05:07", o "1:05:07" si pasa de una hora.
String formatClock(Duration time) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(time.inMinutes % 60);
  final seconds = twoDigits(time.inSeconds % 60);
  if (time.inHours > 0) return '${time.inHours}:$minutes:$seconds';
  return '$minutes:$seconds';
}

/// Segundos de descanso como "1:30" (90 s) o "0:30" (30 s).
String formatRest(int seconds) {
  final rest = (seconds % 60).toString().padLeft(2, '0');
  return '${seconds ~/ 60}:$rest';
}

/// Kilos sin decimales si son enteros y, si no, con uno y coma decimal:
/// 60 → "60"; 62.5 → "62,5".
String formatKg(double kg) {
  if (kg == kg.roundToDouble()) return kg.toStringAsFixed(0);
  return kg.toStringAsFixed(1).replaceAll('.', ',');
}

/// Cuenta atrás del descanso. Como el cronómetro, guarda cuándo termina y
/// calcula lo que falta con la hora actual, así no se desajusta.
class RestCountdown {
  /// Opciones de la hoja del temporizador (30 s … 3:00).
  static const options = [30, 60, 90, 120, 150, 180];

  /// Lo que suman o restan los botones "+15 s" y "−15 s".
  static const step = 15;

  /// Cuándo termina; null si no hay descanso en marcha.
  DateTime? endsAt;

  /// Duración total del descanso actual, para la barra de progreso.
  int totalSeconds = 0;

  bool get isRunning => endsAt != null;

  void start(int seconds, DateTime now) {
    totalSeconds = seconds;
    endsAt = now.add(Duration(seconds: seconds));
  }

  /// Suma (o resta, si [seconds] es negativo) tiempo. Si al restar ya no
  /// queda nada, el descanso termina.
  void add(int seconds, DateTime now) {
    final end = endsAt;
    if (end == null) return;
    final next = end.add(Duration(seconds: seconds));
    if (!next.isAfter(now)) {
      skip();
      return;
    }
    endsAt = next;
    totalSeconds = (totalSeconds + seconds).clamp(1, 24 * 60 * 60);
  }

  void skip() => endsAt = null;

  /// Segundos que faltan, redondeando hacia arriba (con 0,4 s queda "0:01",
  /// no "0:00"). 0 si no hay descanso.
  int remainingSeconds(DateTime now) {
    final end = endsAt;
    if (end == null) return 0;
    final millis = end.difference(now).inMilliseconds;
    return millis <= 0 ? 0 : (millis / 1000).ceil();
  }

  /// Si el descanso ya ha llegado a 0, lo para y devuelve true (para avisar
  /// con la vibración una sola vez).
  bool finishIfDue(DateTime now) {
    final end = endsAt;
    if (end == null || end.isAfter(now)) return false;
    skip();
    return true;
  }
}
