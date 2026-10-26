import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_store.dart';
import 'catalog.dart';

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

  /// Objetivo diario orientativo según peso y objetivo del perfil:
  /// mantenimiento ≈ 33 kcal/kg, ajustado por objetivo; proteína y grasa
  /// por kg de peso y el resto de calorías en hidratos.
  DailyMacros macroTargets() {
    final weight = user?.weightKg ?? 75;
    final goal = user?.goal ?? 'Salud general';
    final factor = switch (goal) {
      'Pérdida de grasa' => 0.85,
      'Hipertrofia' => 1.10,
      'Fuerza' => 1.05,
      _ => 1.0,
    };
    final kcal = weight * 33 * factor;
    final protein = weight * (goal == 'Salud general' ? 1.6 : 2.0);
    final fat = weight * 0.9;
    final carbs = ((kcal - protein * 4 - fat * 9) / 4).clamp(
      0,
      double.infinity,
    );
    return DailyMacros(
      kcal: kcal,
      protein: protein,
      carbs: carbs.toDouble(),
      fat: fat,
    );
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

  /// Objetivo de agua orientativo: 35 ml por kg, redondeado a 100 ml.
  int get waterGoalMl {
    final ml = (user?.weightKg ?? 75) * 35;
    return (ml / 100).round() * 100;
  }

  /// Plantilla que encaja con los días por semana del perfil.
  Routine recommendedRoutine() {
    final days = user?.daysPerWeek ?? 4;
    final id = days <= 3
        ? 'tpl-full'
        : days <= 4
        ? 'tpl-ul'
        : 'tpl-ppl';
    return routineTemplates.firstWhere((r) => r.id == id);
  }
}
