import 'dart:math' as math;

import '../models/models.dart';
import 'formatters.dart';

/// Estado de un día en la tarjeta "Entrenos" de Progreso.
enum WorkoutDayStatus {
  /// Ha entrenado ese día (aunque fuera de descanso).
  done,

  /// Toca entrenar según el plan y el día aún no ha pasado (hoy incluido).
  pending,

  /// Tocaba entrenar, el día ya pasó y no entrenó.
  missed,

  /// Día de descanso en el plan.
  rest,
}

/// Estado de un día en la tarjeta "Nutrición" de Progreso.
enum NutritionDayStatus {
  /// Ha comido dentro del ±10 % de su objetivo de calorías.
  onTarget,

  /// Hay comida apuntada, pero fuera de ese margen.
  logged,

  /// No hay nada apuntado.
  empty,
}

/// Resumen de una semana (de lunes a domingo) para la pestaña Progreso:
/// entrenos, nutrición, pasos, peso, la nota de 0 a 100 y un consejo.
///
/// Es Dart puro: recibe los datos ya cargados y no lee ni escribe nada,
/// así que se prueba con tests normales. Los cálculos van en getters
/// (`late final` los calcula la primera vez que se piden y los guarda).
class WeekSummary {
  WeekSummary({
    required DateTime weekStart,
    required DateTime today,
    required this.plan,
    required this.workouts,
    required this.nutrition,
    required this.kcalGoal,
    required this.weights,
    required this.steps,
    required this.stepsGoal,
  }) : monday = mondayOf(weekStart),
       today = DateTime(today.year, today.month, today.day);

  // --------------------------------------------------------- Constantes --

  /// Peso de cada parte en la nota (suman 1).
  static const workoutWeight = 0.5;
  static const nutritionWeight = 0.3;
  static const stepsWeight = 0.2;

  /// Margen sobre el objetivo de calorías para contar el día como
  /// cumplido: ±10 %.
  static const kcalTolerance = 0.10;

  /// Con menos días de nutrición registrados, el consejo pide apuntar la
  /// comida.
  static const minNutritionDays = 4;

  static const daysInWeek = 7;

  /// Semanas hacia atrás que se pueden ver como mucho.
  static const maxWeeksBack = 12;

  static const completedAdvice = '¡Semana de entreno completada!';
  static const nutritionAdvice =
      'Apunta lo que comes para que tu nota de nutrición suba.';
  static const goodWeekAdvice = 'Buena semana. Sigue así.';

  // ------------------------------------------------------------- Datos --

  /// Lunes de la semana, a las 00:00.
  final DateTime monday;

  /// Hoy a las 00:00: decide qué días ya han pasado.
  final DateTime today;

  /// Plan actual. No se guarda el historial de planes, así que las semanas
  /// pasadas también se comparan con el plan de ahora.
  final TrainingPlan? plan;
  final List<Workout> workouts;
  final List<NutritionEntry> nutrition;
  final double kcalGoal;
  final List<WeightEntry> weights;
  final List<StepsEntry> steps;
  final int stepsGoal;

  /// Los siete días de la semana, de lunes a domingo. Se crean con el
  /// constructor de fecha (día + i) para no fallar con el cambio de hora.
  late final List<DateTime> days = [
    for (var i = 0; i < daysInWeek; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];

  // ---------------------------------------------------------- Entrenos --

  /// Estado de cada día, de lunes a domingo.
  late final List<WorkoutDayStatus> workoutStatuses = [
    for (final day in days) _workoutStatusOn(day),
  ];

  WorkoutDayStatus _workoutStatusOn(DateTime day) {
    if (workouts.any((w) => _sameDay(w.date, day))) {
      return WorkoutDayStatus.done;
    }
    if (plan?.dayFor(day.weekday) == null) return WorkoutDayStatus.rest;
    return day.isBefore(today)
        ? WorkoutDayStatus.missed
        : WorkoutDayStatus.pending;
  }

  /// Días de entreno del plan en la semana.
  late final int plannedWorkouts = days
      .where((day) => plan?.dayFor(day.weekday) != null)
      .length;

  /// Días en los que ha entrenado.
  late final int doneWorkouts = workoutStatuses
      .where((s) => s == WorkoutDayStatus.done)
      .length;

  /// Parte de la nota de entrenos (de 0 a 1): hechos / planificados. Si no
  /// había ninguno planificado, 1. Si entrena más días de los previstos,
  /// no pasa de 1.
  double get workoutScore =>
      plannedWorkouts == 0 ? 1 : math.min(doneWorkouts / plannedWorkouts, 1);

  /// Días del plan que aún quedan por hacer esta semana.
  List<PlanDay> get pendingPlanDays => [
    for (final (i, day) in days.indexed)
      if (workoutStatuses[i] == WorkoutDayStatus.pending)
        ?plan?.dayFor(day.weekday),
  ];

  // --------------------------------------------------------- Nutrición --

  /// Calorías comidas ese día.
  double kcalOn(DateTime day) => nutrition
      .where((e) => _sameDay(e.date, day))
      .fold(0, (total, e) => total + e.kcal);

  /// Estado de cada día, de lunes a domingo.
  late final List<NutritionDayStatus> nutritionStatuses = [
    for (final day in days) _nutritionStatusOn(day),
  ];

  NutritionDayStatus _nutritionStatusOn(DateTime day) {
    if (!nutrition.any((e) => _sameDay(e.date, day))) {
      return NutritionDayStatus.empty;
    }
    final difference = (kcalOn(day) - kcalGoal).abs();
    return difference <= kcalGoal * kcalTolerance
        ? NutritionDayStatus.onTarget
        : NutritionDayStatus.logged;
  }

  /// Días con el objetivo cumplido.
  late final int nutritionDaysOnTarget = nutritionStatuses
      .where((s) => s == NutritionDayStatus.onTarget)
      .length;

  /// Días con algo apuntado (cumplidos + registrados).
  late final int nutritionDaysLogged = nutritionStatuses
      .where((s) => s != NutritionDayStatus.empty)
      .length;

  /// Parte de la nota de nutrición (de 0 a 1): días registrados / 7.
  double get nutritionScore => nutritionDaysLogged / daysInWeek;

  // ------------------------------------------------------------- Pasos --

  late final List<StepsEntry> _stepsInWeek = [
    for (final e in steps)
      if (_inWeek(e.date)) e,
  ];

  /// Media de pasos de los días apuntados, o null si no hay ninguno.
  int? get averageSteps {
    if (_stepsInWeek.isEmpty) return null;
    final total = _stepsInWeek.fold(0, (sum, e) => sum + e.steps);
    return (total / _stepsInWeek.length).round();
  }

  /// Media de pasos sobre el objetivo, en % (de 0 a 100).
  double get stepsPercent {
    final average = averageSteps ?? 0;
    if (stepsGoal <= 0) return 100;
    return math.min(average / stepsGoal * 100, 100);
  }

  // -------------------------------------------------------------- Peso --

  /// Peso medio de la semana, o null si no hay registros.
  double? get averageWeight {
    final inWeek = [
      for (final e in weights)
        if (_inWeek(e.date)) e.kg,
    ];
    if (inWeek.isEmpty) return null;
    return inWeek.reduce((a, b) => a + b) / inWeek.length;
  }

  /// Diferencia con el peso medio de la semana anterior, o null si alguna
  /// de las dos no tiene registros.
  double? get weightChange {
    final current = averageWeight;
    final previous = previousWeek.averageWeight;
    if (current == null || previous == null) return null;
    return current - previous;
  }

  // -------------------------------------------------------------- Nota --

  /// Nota de 0 a 100:
  /// round(100 × (0,5 × entrenos + 0,3 × nutrición + 0,2 × pasos)).
  int get score =>
      (100 *
              (workoutWeight * workoutScore +
                  nutritionWeight * nutritionScore +
                  stepsWeight * stepsPercent / 100))
          .round();

  /// La semana anterior, con los mismos datos.
  late final WeekSummary previousWeek = WeekSummary(
    weekStart: DateTime(monday.year, monday.month, monday.day - daysInWeek),
    today: today,
    plan: plan,
    workouts: workouts,
    nutrition: nutrition,
    kcalGoal: kcalGoal,
    weights: weights,
    steps: steps,
    stepsGoal: stepsGoal,
  );

  /// Puntos que sube (positivo) o baja (negativo) la nota respecto a la
  /// semana anterior.
  int get scoreChange => score - previousWeek.score;

  // ----------------------------------------------------------- Consejo --

  /// Un consejo, por este orden de prioridad:
  /// 1. los entrenos que quedan; 2. semana de entreno completada;
  /// 3. apuntar la comida; 4. los pasos que faltan; 5. buena semana.
  String get advice {
    final pending = pendingPlanDays;
    if (pending.isNotEmpty) return _pendingAdvice(pending);
    if (plannedWorkouts > 0 && doneWorkouts >= plannedWorkouts) {
      return completedAdvice;
    }
    if (nutritionDaysLogged < minNutritionDays) return nutritionAdvice;
    final missing = stepsGoal - (averageSteps ?? 0);
    if (missing > 0) {
      return 'Te faltan unos ${formatThousands(_roundUpToHundreds(missing))} '
          'pasos al día para tu objetivo.';
    }
    return goodWeekAdvice;
  }

  /// "Te quedan Pierna (viernes) y Brazos (domingo). Si los haces, cierras
  /// la semana de entreno." (en singular si solo queda uno).
  static String _pendingAdvice(List<PlanDay> pending) {
    final names = [
      for (final day in pending)
        '${day.name} (${day.weekdayName.toLowerCase()})',
    ];
    final single = names.length == 1;
    return 'Te ${single ? 'queda' : 'quedan'} ${_joinWithAnd(names)}. '
        'Si ${single ? 'lo' : 'los'} haces, cierras la semana de entreno.';
  }

  /// "A", "A y B", "A, B y C".
  static String _joinWithAnd(List<String> items) {
    if (items.length == 1) return items.first;
    final allButLast = items.sublist(0, items.length - 1).join(', ');
    return '$allButLast y ${items.last}';
  }

  /// "Unos X pasos": se redondea hacia arriba a la centena (30 → 100).
  static int _roundUpToHundreds(int value) => (value + 99) ~/ 100 * 100;

  // ---------------------------------------------- Semanas y etiquetas --

  /// Lunes de la semana de [day], a las 00:00.
  static DateTime mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - 1));

  /// Semanas completas entre el lunes de [from] y el de [to].
  static int weeksBetween(DateTime from, DateTime to) {
    final a = mondayOf(from);
    final b = mondayOf(to);
    // En UTC no hay cambio de hora, así que la resta da días exactos.
    final days = DateTime.utc(
      b.year,
      b.month,
      b.day,
    ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
    return days ~/ daysInWeek;
  }

  /// Cuántas semanas hacia atrás se pueden ver: hasta la semana en la que
  /// se creó la cuenta y, como mucho, [maxWeeksBack]. Sin fecha de la
  /// cuenta, [maxWeeksBack].
  static int weeksBackAllowed(DateTime? accountCreatedAt, DateTime today) {
    if (accountCreatedAt == null) return maxWeeksBack;
    return weeksBetween(accountCreatedAt, today).clamp(0, maxWeeksBack);
  }

  /// Nombre de la semana que empieza en [monday]: "Esta semana", "Semana
  /// pasada" o las fechas ("10–16 nov", "27 oct – 2 nov").
  static String weekLabel(DateTime monday, DateTime today) {
    switch (weeksBetween(monday, today)) {
      case 0:
        return 'Esta semana';
      case 1:
        return 'Semana pasada';
    }
    final start = mondayOf(monday);
    final end = DateTime(start.year, start.month, start.day + 6);
    if (start.month == end.month) {
      return '${start.day}–${shortDate(end)}';
    }
    return '${shortDate(start)} – ${shortDate(end)}';
  }

  // --------------------------------------------------------- Ayudantes --

  bool _inWeek(DateTime date) => days.any((day) => _sameDay(date, day));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
