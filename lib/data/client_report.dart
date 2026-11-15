import '../models/models.dart';

/// Estadísticas de un usuario en las últimas [weeks] semanas (la última es la
/// actual, de lunes a hoy). Las usan la ficha de cliente del entrenador y los
/// informes en Excel/PDF. Solo calcula: no lee de Firestore.
class ClientReport {
  ClientReport({
    required this.user,
    required List<Workout> workouts,
    this.weeks = 4,
    this.assignedRoutineIds = const {},
    DateTime? now,
  }) : now = now ?? DateTime.now(),
       all = [...workouts]..sort((a, b) => b.date.compareTo(a.date)) {
    final today = this.now;
    final monday = DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1),
    );
    weekStarts = [
      for (var i = weeks - 1; i >= 0; i--)
        DateTime(monday.year, monday.month, monday.day - 7 * i),
    ];
    inPeriod = all.where((w) => !w.date.isBefore(weekStarts.first)).toList();
  }

  final AppUser user;
  final int weeks;
  final DateTime now;

  /// Ids de las rutinas que le ha asignado el entrenador del informe.
  final Set<String> assignedRoutineIds;

  /// Todos sus entrenos, del más reciente al más antiguo.
  final List<Workout> all;

  /// Lunes de cada semana del periodo, de la más antigua a la actual.
  late final List<DateTime> weekStarts;

  /// Entrenos dentro del periodo.
  late final List<Workout> inPeriod;

  String get name =>
      user.profile.name.isEmpty ? '(sin nombre)' : user.profile.name;
  int get daysPerWeek => user.profile.daysPerWeek;

  int get sessions => inPeriod.length;
  int get minutes => inPeriod.fold(0, (s, w) => s + w.durationMin);
  double get volumeKg => inPeriod.fold(0, (s, w) => s + w.volumeKg);
  int get sets => inPeriod.fold(
    0,
    (s, w) => s + w.exercises.fold(0, (t, e) => t + e.sets.length),
  );

  double get sessionsPerWeek => weeks == 0 ? 0 : sessions / weeks;

  /// Sesiones hechas frente a las previstas (días/semana × semanas), en %.
  /// Puede pasar de 100 si entrena más de lo previsto.
  double get adherencePct {
    final planned = daysPerWeek * weeks;
    return planned == 0 ? 0 : sessions * 100 / planned;
  }

  /// Sesiones del periodo hechas desde una rutina asignada por el entrenador.
  int get assignedSessions => inPeriod
      .where(
        (w) => w.routineId != null && assignedRoutineIds.contains(w.routineId),
      )
      .length;

  DateTime? get lastWorkout => all.isEmpty ? null : all.first.date;

  /// Días desde el último entreno (null si nunca ha entrenado).
  int? get daysSinceLast {
    final last = lastWorkout;
    if (last == null) return null;
    final a = DateTime(now.year, now.month, now.day);
    final b = DateTime(last.year, last.month, last.day);
    return a.difference(b).inHours ~/ 24;
  }

  /// Sesiones de cada semana del periodo (misma posición que [weekStarts]).
  List<int> get sessionsByWeek => [for (final w in _byWeek) w.length];

  /// Volumen (kg) de cada semana del periodo.
  List<double> get volumeByWeek => [
    for (final w in _byWeek) w.fold(0.0, (s, x) => s + x.volumeKg),
  ];

  List<List<Workout>> get _byWeek {
    final buckets = [for (var i = 0; i < weeks; i++) <Workout>[]];
    for (final w in inPeriod) {
      for (var i = weeks - 1; i >= 0; i--) {
        if (!w.date.isBefore(weekStarts[i])) {
          buckets[i].add(w);
          break;
        }
      }
    }
    return buckets;
  }

  /// Ejercicios más hechos en el periodo: veces, series y peso máximo.
  List<ExerciseSummary> topExercises({int limit = 5}) {
    final map = <String, ExerciseSummary>{};
    for (final w in inPeriod) {
      for (final e in w.exercises) {
        final s = map[e.exercise.name] ??= ExerciseSummary(e.exercise.name);
        s.times++;
        s.sets += e.sets.length;
        for (final set in e.sets) {
          if (set.weightKg > s.bestKg) s.bestKg = set.weightKg;
        }
      }
    }
    final list = map.values.toList()
      ..sort(
        (a, b) => b.times != a.times
            ? b.times.compareTo(a.times)
            : b.sets.compareTo(a.sets),
      );
    return list.take(limit).toList();
  }

  /// Comentarios de sus ejercicios en el periodo, del más reciente al más
  /// antiguo (como mucho [limit]). Así el entrenador ve, por ejemplo,
  /// "Molestia en el hombro en la última serie".
  List<ExerciseComment> recentComments({int limit = 5}) => [
    for (final w in inPeriod)
      for (final e in w.exercises)
        if ((e.comment ?? '').isNotEmpty)
          (date: w.date, exercise: e.exercise.name, text: e.comment ?? ''),
  ].take(limit).toList();
}

/// Comentario que el cliente dejó en un ejercicio durante un entreno.
typedef ExerciseComment = ({DateTime date, String exercise, String text});

class ExerciseSummary {
  ExerciseSummary(this.name);

  final String name;
  int times = 0;
  int sets = 0;
  double bestKg = 0;
}

/// Fecha corta dd/mm.
String shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Fecha dd/mm/aaaa.
String longDate(DateTime d) => '${shortDate(d)}/${d.year}';
