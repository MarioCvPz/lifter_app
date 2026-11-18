import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_store.dart';
import 'nutrition_calculator.dart';
import 'routine_generator.dart';
import 'week_summary.dart';
import 'workout_draft.dart';

/// Datos calculados a partir de lo que hay en el store: rachas, volumen,
/// macros, agua… No leen ni escriben en Firestore.
extension AppStoreStats on AppStore {
  DailyMacros macrosFor(DateTime day) {
    final ofDay = nutritionFor(day);
    return DailyMacros(
      kcal: ofDay.fold(0, (s, e) => s + e.kcal),
      protein: ofDay.fold(0, (s, e) => s + e.protein),
      carbs: ofDay.fold(0, (s, e) => s + e.carbs),
      fat: ofDay.fold(0, (s, e) => s + e.fat),
    );
  }

  List<NutritionEntry> nutritionFor(DateTime day) {
    return nutritionLogs
        .where((e) => DateUtils.isSameDay(e.date, day))
        .toList();
  }

  /// Objetivo diario de calorías y macros, calculado con
  /// [NutritionCalculator] (sexo, edad, altura, peso, actividad y objetivo).
  /// Usa [profile] si se indica (por ejemplo, las respuestas del
  /// cuestionario aún sin guardar) y, si no, el perfil de la sesión.
  /// Sin ninguno de los dos (sin sesión) usa un perfil con los valores por
  /// defecto, para que las pantallas siempre tengan un objetivo.
  /// Con el perfil de la sesión, si el entrenador ha fijado objetivos
  /// ([coachSettings]), se usan esos (ver
  /// [NutritionCalculator.macrosWithCoach]).
  DailyMacros macroTargets([UserProfile? profile]) {
    final p = profile ?? user ?? UserProfile(name: '', username: '', email: '');
    // Las respuestas del cuestionario ([profile]) no llevan entrenador.
    final coach = profile == null ? coachSettings : null;
    return NutritionCalculator.macrosWithCoach(p, coach);
  }

  DateTime get _monday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  Iterable<Workout> get _thisWeek =>
      workouts.where((w) => !w.date.isBefore(_monday));

  /// Entrenamientos desde el lunes de esta semana.
  int workoutsThisWeek() => _thisWeek.length;

  /// Volumen (reps × kg) acumulado esta semana.
  double volumeThisWeek() => _thisWeek.fold(0, (s, w) => s + w.volumeKg);

  bool trainedOn(DateTime day) =>
      workouts.any((w) => DateUtils.isSameDay(w.date, day));

  /// Días seguidos entrenando, contando hasta hoy (o hasta ayer si hoy
  /// todavía no has entrenado).
  int streakDays() {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!trainedOn(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (trainedOn(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Mayor número de días seguidos entrenando de todo el historial.
  int bestStreak() {
    final days = {
      for (final w in workouts) DateTime(w.date.year, w.date.month, w.date.day),
    }.toList()..sort();
    var best = 0;
    var current = 0;
    DateTime? prev;
    for (final d in days) {
      // Se compara por fecha de calendario para no fallar con el cambio de hora.
      final next = prev == null
          ? null
          : DateTime(prev.year, prev.month, prev.day + 1);
      current = next != null && DateUtils.isSameDay(d, next) ? current + 1 : 1;
      if (current > best) best = current;
      prev = d;
    }
    return best;
  }

  double totalVolume() => workouts.fold(0, (s, w) => s + w.volumeKg);

  int totalMinutes() => workouts.fold(0, (s, w) => s + w.durationMin);

  int totalSets() => workouts.fold(
    0,
    (s, w) => s + w.exercises.fold(0, (t, e) => t + e.sets.length),
  );

  /// Ejercicio que más veces aparece en tus entrenos.
  String? favoriteExercise() {
    final counts = <String, int>{};
    for (final w in workouts) {
      for (final e in w.exercises) {
        counts[e.exercise.name] = (counts[e.exercise.name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Días distintos con alguna comida registrada.
  int nutritionDaysLogged() => {
    for (final n in nutritionLogs)
      DateTime(n.date.year, n.date.month, n.date.day),
  }.length;

  /// Entrenos de cada una de las últimas [weeks] semanas (la última es la
  /// actual).
  List<int> workoutsPerWeek({int weeks = 8}) {
    final counts = List.filled(weeks, 0);
    for (final w in workouts) {
      final diff = _monday.difference(
        DateTime(w.date.year, w.date.month, w.date.day - (w.date.weekday - 1)),
      );
      final weeksAgo = (diff.inHours / (24 * 7)).round();
      if (weeksAgo >= 0 && weeksAgo < weeks) counts[weeks - 1 - weeksAgo]++;
    }
    return counts;
  }

  /// La rutina del último entreno que salió de una rutina.
  Routine? activeRoutine() {
    final all = [...routines, for (final a in assignedToMe) a.routine];
    for (final w in workouts) {
      if (w.routineId == null) continue;
      for (final r in all) {
        if (r.id == w.routineId) return r;
      }
    }
    return null;
  }

  int sessionsThisWeek(String routineId) =>
      _thisWeek.where((w) => w.routineId == routineId).length;

  /// Series de la última vez que hizo ese ejercicio (del entreno más
  /// reciente que lo tenga), o una lista vacía si nunca lo ha hecho. Son
  /// las pistas de los campos vacíos del entrenamiento en directo.
  List<WorkoutSet> lastSetsOf(String exerciseId) {
    Workout? latest;
    List<WorkoutSet> sets = const [];
    for (final w in workouts) {
      for (final e in w.exercises) {
        if (e.exercise.id != exerciseId) continue;
        if (latest == null || w.date.isAfter(latest.date)) {
          latest = w;
          sets = e.sets;
        }
      }
    }
    return sets;
  }

  /// Veces que ha hecho el ejercicio, de la más reciente a la más antigua
  /// (como mucho [limit]). Cada una con la fecha del entreno, lo que hizo
  /// y la respuesta de su entrenador a su comentario (si la hay).
  List<({DateTime date, WorkoutExercise entry, String? coachReply})> historyOf(
    String exerciseId, {
    int limit = 10,
  }) {
    final history = [
      for (final w in workouts)
        for (final (i, e) in w.exercises.indexed)
          if (e.exercise.id == exerciseId)
            (date: w.date, entry: e, coachReply: coachReplyFor(w.id, i)),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return history.take(limit).toList();
  }

  /// Respuesta de mi entrenador a mi comentario del ejercicio
  /// [exerciseIndex] del entreno [workoutId], o null. Como las notas del
  /// plan, solo se ve mientras tengo entrenador.
  String? coachReplyFor(String workoutId, int exerciseIndex) {
    if (!hasAcceptedTrainer) return null;
    return coachReplies[CoachReply.idFor(workoutId, exerciseIndex)]?.reply;
  }

  /// La última respuesta de mi entrenador a un comentario mío en
  /// [exerciseId], para la tarjeta del entreno en directo, o null.
  String? latestCoachReplyFor(String exerciseId) {
    // `workouts` va del más reciente al más antiguo.
    for (final w in workouts) {
      for (final (i, e) in w.exercises.indexed) {
        if (e.exercise.id != exerciseId) continue;
        final reply = coachReplyFor(w.id, i);
        if (reply != null) return reply;
      }
    }
    return null;
  }

  /// Propuestas para "Sustituir": ejercicios del catálogo con el mismo
  /// patrón de movimiento que [exercise], que el usuario puede hacer con su
  /// material y sin cargar sus lesiones, y que no están en [exclude]. Usa
  /// [RoutineGenerator.candidates] del generador (sin filtrar por nivel,
  /// para que haya más opciones). Sin perfil o con un ejercicio sin patrón
  /// ("otro"), no hay propuestas.
  List<Exercise> substituteSuggestions(
    Exercise exercise, {
    Set<String> exclude = const {},
  }) {
    final profile = user;
    if (profile == null || exercise.pattern == MovementPattern.other) {
      return const [];
    }
    return RoutineGenerator.candidates(
      exercise.pattern,
      profile,
      exercises,
      exclude: {...exclude, exercise.id},
      ignoreLevel: true,
    );
  }

  /// True si [routineId] es una rutina creada por el usuario (no una
  /// plantilla ni una rutina de su entrenador): solo esas se pueden
  /// actualizar al terminar el entreno.
  bool isOwnRoutine(String routineId) =>
      routines.any((r) => r.id == routineId && !r.isTemplate);

  /// "Sugeridos para este día" con el perfil y el catálogo de la sesión
  /// (ver [RoutineGenerator.suggestionsFor]).
  List<Exercise> planSuggestions(PlanDay day) {
    final profile = user;
    if (profile == null) return const [];
    return RoutineGenerator.suggestionsFor(day, profile, exercises);
  }

  /// Entreno de hoy o, si hoy no toca, el del próximo día de entreno
  /// (para la tarjeta de la pestaña Entrenos). Null si no hay ninguno en
  /// la semana (sin plan).
  DayWorkout? nextWorkout(DateTime now) {
    for (var offset = 0; offset < 7; offset++) {
      // Días de la semana a partir de hoy: con % 7, después del domingo
      // (7) vuelve el lunes (1).
      final weekday = (now.weekday - 1 + offset) % 7 + 1;
      final workout = workoutFor(weekday);
      if (workout != null) return workout;
    }
    return null;
  }

  /// Rutina del entrenador para ese día de la semana (1 = lunes), o null
  /// si no tiene ninguna o es día de descanso. Las asignaciones van por
  /// orden de día del plan ([AssignedRoutine.dayNumber]): si entrena lunes,
  /// miércoles y viernes, el miércoles es el día 2. Las antiguas, sin día,
  /// valen para todos. Si hay varias para el mismo día, gana la más nueva.
  AssignedRoutine? assignedFor(int weekday) {
    final days = plan?.days ?? const <PlanDay>[];
    // Posición del día en el plan (los días están ordenados de lunes a
    // domingo); -1 si ese día descansa.
    final position = days.indexWhere((d) => d.weekday == weekday);
    if (position == -1) return null;
    final dayNumber = position + 1;
    // La lista está ordenada de la más nueva a la más antigua.
    for (final a in assignedToMe) {
      if (a.dayNumber == null || a.dayNumber == dayNumber) return a;
    }
    return null;
  }

  /// Entreno de ese día de la semana (1 = lunes) para Inicio, o null si
  /// en el plan es día de descanso. Orden de prioridad:
  /// 1. Si el entrenador le ha asignado una rutina para ese día, esa (ver
  ///    [assignedFor]).
  /// 2. Si no, el día del plan.
  DayWorkout? workoutFor(int weekday) {
    final day = plan?.dayFor(weekday);
    if (day == null) return null;
    final assigned = assignedFor(weekday);
    if (assigned != null) {
      final routine = assigned.routine;
      return DayWorkout(
        weekday: weekday,
        name: routine.name,
        routine: routine,
        fromTrainer: true,
      );
    }
    return DayWorkout(
      weekday: weekday,
      name: day.name,
      planDay: day,
      routine: Routine(
        id: 'plan-${day.weekday}',
        name: day.title,
        description: '',
        templateName: 'Mi plan',
        exercises: [for (final e in day.exercises) e.exercise],
      ),
    );
  }

  /// Beber más de este número de veces el objetivo de agua es demasiado.
  static const waterExcessFactor = 2;

  /// Texto de la píldora de Inicio para el día [now]:
  /// - "Hoy: entreno hecho" si ya ha entrenado (aunque fuera de descanso);
  /// - "Hoy: descanso" si en su plan no le toca entrenar;
  /// - "Mar: hora de entrenar" en el resto de casos (también si aún no
  ///   tiene plan).
  String todayStatus(DateTime now) {
    if (trainedOn(now)) return 'Hoy: entreno hecho';
    final currentPlan = plan;
    if (currentPlan != null && currentPlan.dayFor(now.weekday) == null) {
      return 'Hoy: descanso';
    }
    // "Mar", "Mié"…: las tres primeras letras del nombre del día.
    final shortDay = ProfileOptions.weekdayNames[now.weekday - 1].substring(
      0,
      3,
    );
    return '$shortDay: hora de entrenar';
  }

  /// Mensaje al sumar agua, o null si no hay nada especial que decir.
  /// Solo sale al cruzar un límite (pasar de [beforeMl] a [afterMl]), no
  /// en cada vaso.
  String? waterMessage(int beforeMl, int afterMl) {
    final goal = waterGoalMl;
    final tooMuch = goal * waterExcessFactor;
    if (beforeMl <= tooMuch && afterMl > tooMuch) {
      return 'Estás bebiendo mucha agua, ten cuidado';
    }
    if (beforeMl < goal && afterMl >= goal) {
      return '¡Objetivo de agua cumplido!';
    }
    return null;
  }

  /// Objetivo de agua del perfil de la sesión (ver [waterGoalMlFor]).
  int get waterGoalMl => waterGoalMlFor(user);

  // --- Progreso: semana, peso y pasos ---

  /// Resumen de la semana que contiene [weekStart] con los datos de la
  /// sesión (ver [WeekSummary]).
  WeekSummary weekSummary(DateTime weekStart, {DateTime? today}) => WeekSummary(
    weekStart: weekStart,
    today: today ?? DateTime.now(),
    plan: plan,
    workouts: workouts,
    nutrition: nutritionLogs,
    kcalGoal: macroTargets().kcal,
    weights: weights,
    steps: steps,
    stepsGoal: stepsGoalInUse,
  );

  /// Objetivo de pasos que se usa en Progreso. Es el único sitio que lo
  /// decide: primero el que puso el entrenador y, si no hay, el del perfil.
  int get stepsGoalInUse =>
      coachSettings?.stepsGoal ??
      user?.stepsGoal ??
      UserProfile.defaultStepsGoal;

  /// True si las calorías las ha fijado un entrenador.
  bool get nutritionByCoach => coachSettings?.adjustsNutrition ?? false;

  /// True si el objetivo de pasos lo ha fijado un entrenador.
  bool get stepsByCoach => coachSettings?.stepsGoal != null;

  /// Texto de la etiqueta que acompaña a lo que ajustó el entrenador.
  String get coachLabel => hasAcceptedTrainer
      ? 'Ajustado por tu entrenador'
      : 'Ajustado por tu entrenador anterior';

  /// Peso apuntado ese día, o null. Rellena la hoja de "+ Peso".
  WeightEntry? weightOn(DateTime day) {
    for (final e in weights) {
      if (DateUtils.isSameDay(e.date, day)) return e;
    }
    return null;
  }

  /// Pasos apuntados ese día, o null.
  StepsEntry? stepsOn(DateTime day) {
    for (final e in steps) {
      if (DateUtils.isSameDay(e.date, day)) return e;
    }
    return null;
  }

  /// Últimos [limit] pesos, del más antiguo al más reciente (el orden del
  /// gráfico, de izquierda a derecha).
  List<WeightEntry> recentWeights({int limit = 12}) =>
      weights.take(limit).toList().reversed.toList();

  /// Objetivo de agua orientativo: 35 ml por kg, redondeado a 100 ml.
  /// Es un método aparte porque un getter no puede recibir parámetros.
  int waterGoalMlFor(UserProfile? profile) {
    final ml = (profile?.weightKg ?? 75) * 35;
    return (ml / 100).round() * 100;
  }
}

/// Lo que muestra Inicio en "Entreno de hoy": el día, el nombre del entreno
/// ("Empuje"), la rutina con los ejercicios (para contarlos y para empezar
/// el entreno) y si es la que ha asignado el entrenador.
class DayWorkout {
  const DayWorkout({
    required this.weekday,
    required this.name,
    required this.routine,
    this.planDay,
    this.fromTrainer = false,
  });

  /// 1 = lunes … 7 = domingo.
  final int weekday;
  final String name;
  final Routine routine;

  /// Día del plan del que sale, con sus series, repeticiones y descanso.
  /// Null si es la rutina del entrenador.
  final PlanDay? planDay;
  final bool fromTrainer;

  /// "Hoy · Martes" si es [todayWeekday]; si no, solo "Jueves".
  String dayLabel(int todayWeekday) {
    final dayName = ProfileOptions.weekdayNames[weekday.clamp(1, 7) - 1];
    return weekday == todayWeekday ? 'Hoy · $dayName' : dayName;
  }

  /// "6 ejercicios" (o "1 ejercicio").
  String get exerciseCountLabel {
    final count = routine.exercises.length;
    return '$count ${count == 1 ? 'ejercicio' : 'ejercicios'}';
  }

  /// Los ejercicios con su objetivo (series, repeticiones y descanso), como
  /// empezarán en el entrenamiento: los del plan o, si es la rutina del
  /// entrenador, con los valores por defecto. Los usa la vista previa.
  List<DraftExercise> get plannedExercises {
    final day = planDay;
    if (day != null) {
      return [for (final e in day.exercises) DraftExercise.fromPlan(e)];
    }
    return [for (final e in routine.exercises) DraftExercise.basic(e)];
  }
}

/// Litros para mostrar a partir de mililitros: hasta dos decimales, sin
/// ceros sobrantes al final y con coma decimal.
/// 250 → "0,25"; 500 → "0,5"; 1000 → "1"; 1250 → "1,25".
String formatLiters(int ml) {
  final fixed = (ml / 1000).toStringAsFixed(2); // 500 → "0.50"
  // Quita los ceros finales y, si se queda sin decimales, también el punto.
  final trimmed = fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  return trimmed.replaceAll('.', ',');
}
