import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/week_summary.dart';
import 'package:lifter_app/models/models.dart';

import 'helpers.dart';

/// Semana de las pruebas: del lunes 16 al domingo 22 de noviembre de 2026.
final monday = DateTime(2026, 11, 16);

/// Día [i] de la semana (0 = lunes … 6 = domingo).
DateTime dayOf(int i) => DateTime(2026, 11, 16 + i);

/// Alimento de 100 kcal por 100 g: los gramos son las kcal.
const kcalFood = Food(
  id: 'k',
  name: 'Prueba',
  kcalPer100: 100,
  proteinPer100: 0,
  carbsPer100: 0,
  fatPer100: 0,
);

NutritionEntry meal(DateTime day, double kcal) => NutritionEntry(
  id: '${day.toIso8601String()}-$kcal',
  food: kcalFood,
  grams: kcal,
  date: DateTime(day.year, day.month, day.day, 14),
);

/// Plan con un día de cada tipo en esos días de la semana (1 = lunes).
TrainingPlan planOn(Map<int, PlanDayType> days) => TrainingPlan(
  generatedAt: DateTime(2026, 11, 1),
  days: [
    for (final MapEntry(key: weekday, value: type) in days.entries)
      PlanDay(weekday: weekday, type: type, exercises: const []),
  ],
);

/// Lunes empuje, martes tirón, viernes pierna y domingo brazos.
final fourDayPlan = planOn({
  1: PlanDayType.push,
  2: PlanDayType.pull,
  5: PlanDayType.legs,
  7: PlanDayType.arms,
});

WeekSummary summary({
  DateTime? today,
  TrainingPlan? plan,
  List<Workout> workouts = const [],
  List<NutritionEntry> nutrition = const [],
  List<WeightEntry> weights = const [],
  List<StepsEntry> steps = const [],
  int stepsGoal = 10000,
}) => WeekSummary(
  weekStart: monday,
  today: today ?? dayOf(2), // miércoles
  plan: plan,
  workouts: workouts,
  nutrition: nutrition,
  kcalGoal: 2000,
  weights: weights,
  steps: steps,
  stepsGoal: stepsGoal,
);

List<StepsEntry> stepsOn(List<int> counts) => [
  for (final (i, count) in counts.indexed)
    StepsEntry(date: dayOf(i), steps: count),
];

void main() {
  group('CP-16 Resumen de la semana', () {
    test('Entrenos: hecho, pendiente, no hecho y descanso según hoy', () {
      // Hoy es miércoles. Entrenó el lunes y el martes no.
      final s = summary(plan: fourDayPlan, workouts: [workoutOn(dayOf(0))]);

      expect(s.workoutStatuses, [
        WorkoutDayStatus.done, // lunes
        WorkoutDayStatus.missed, // martes: ya pasó
        WorkoutDayStatus.rest,
        WorkoutDayStatus.rest,
        WorkoutDayStatus.pending, // viernes: aún no ha llegado
        WorkoutDayStatus.rest,
        WorkoutDayStatus.pending, // domingo
      ]);
      expect(s.plannedWorkouts, 4);
      expect(s.doneWorkouts, 1);

      // Hoy, si toca y aún no ha entrenado, está pendiente.
      final todayPlanned = summary(plan: fourDayPlan, today: dayOf(1));
      expect(todayPlanned.workoutStatuses[1], WorkoutDayStatus.pending);
    });

    test('Nutrición: cumplido dentro del ±10 %, registrado fuera, vacío', () {
      final s = summary(
        nutrition: [
          meal(dayOf(0), 2000), // justo el objetivo
          meal(dayOf(1), 1000),
          meal(dayOf(1), 1200), // 2200: +10 %, en el límite
          meal(dayOf(2), 1790), // −10,5 %
          meal(dayOf(3), 2500), // +25 %
        ],
      );

      expect(s.nutritionStatuses, [
        NutritionDayStatus.onTarget,
        NutritionDayStatus.onTarget,
        NutritionDayStatus.logged,
        NutritionDayStatus.logged,
        NutritionDayStatus.empty,
        NutritionDayStatus.empty,
        NutritionDayStatus.empty,
      ]);
      expect(s.nutritionDaysOnTarget, 2);
      expect(s.nutritionDaysLogged, 4); // cumplidos + registrados
    });

    test('Pasos: media de los días apuntados y % limitado a 100', () {
      final s = summary(steps: stepsOn([8000, 6400]));
      expect(s.averageSteps, 7200);
      expect(s.stepsPercent, closeTo(72, 0.001));

      final lots = summary(steps: stepsOn([15000, 13000]));
      expect(lots.averageSteps, 14000);
      expect(lots.stepsPercent, 100);

      final none = summary();
      expect(none.averageSteps, isNull);
      expect(none.stepsPercent, 0);
    });

    test('Peso medio y diferencia con la semana anterior', () {
      final lastWeek = DateTime(2026, 11, 12);
      final s = summary(
        weights: [
          WeightEntry(date: dayOf(0), kg: 78.0),
          WeightEntry(date: dayOf(3), kg: 78.8),
          WeightEntry(date: lastWeek, kg: 78.7),
        ],
      );
      expect(s.averageWeight, closeTo(78.4, 0.001));
      expect(s.weightChange, closeTo(-0.3, 0.001));

      // Sin pesos la semana anterior no hay diferencia.
      final onlyThisWeek = summary(
        weights: [WeightEntry(date: dayOf(0), kg: 78.0)],
      );
      expect(onlyThisWeek.averageWeight, 78.0);
      expect(onlyThisWeek.weightChange, isNull);

      // Y sin pesos esta semana, tampoco hay media.
      final none = summary(weights: [WeightEntry(date: lastWeek, kg: 78.7)]);
      expect(none.averageWeight, isNull);
      expect(none.weightChange, isNull);
    });

    test('Nota: 3/4 entrenos, 5/7 nutrición y 72 % de pasos → 73', () {
      // Domingo por la noche: entrenó lunes, martes y viernes (no el
      // domingo); comió 5 días; 7.200 pasos de media.
      final s = summary(
        today: dayOf(6),
        plan: fourDayPlan,
        workouts: [
          for (final i in [0, 1, 4]) workoutOn(dayOf(i)),
        ],
        nutrition: [for (var i = 0; i < 5; i++) meal(dayOf(i), 2000)],
        steps: stepsOn([8000, 6400]),
      );

      expect(s.workoutScore, 0.75);
      expect(s.nutritionScore, closeTo(5 / 7, 0.0001));
      // 0,5 · 0,75 + 0,3 · 0,714 + 0,2 · 0,72 = 0,733 → 73
      expect(s.score, 73);
      // La semana anterior no tiene nada: 0 entrenos de 4, sin comidas
      // ni pasos → 0 puntos.
      expect(s.previousWeek.score, 0);
      expect(s.scoreChange, 73);
    });

    test('Sin días planificados, la parte de entrenos vale 1', () {
      expect(summary().workoutScore, 1);
      expect(summary().score, 50); // solo la mitad de entrenos
    });

    group('Consejo', () {
      // Cuatro días con comida apuntada: no salta el consejo de nutrición.
      final fourMeals = [for (var i = 0; i < 4; i++) meal(dayOf(i), 2000)];

      test('1. Entrenos pendientes', () {
        final s = summary(plan: fourDayPlan, workouts: [workoutOn(dayOf(0))]);
        expect(
          s.advice,
          'Te quedan Pierna (viernes) y Brazos (domingo). Si los haces, '
          'cierras la semana de entreno.',
        );

        // En singular si solo queda uno.
        final one = summary(plan: fourDayPlan, today: dayOf(5));
        expect(
          one.advice,
          'Te queda Brazos (domingo). Si lo haces, cierras la semana de '
          'entreno.',
        );
      });

      test('2. Semana de entreno completada', () {
        final s = summary(
          plan: planOn({1: PlanDayType.push, 2: PlanDayType.pull}),
          workouts: [workoutOn(dayOf(0)), workoutOn(dayOf(1))],
        );
        expect(s.advice, WeekSummary.completedAdvice);
      });

      test('3. Menos de 4 días de nutrición', () {
        final s = summary(nutrition: fourMeals.take(3).toList());
        expect(s.advice, WeekSummary.nutritionAdvice);
      });

      test('4. Faltan pasos (redondeado a la centena)', () {
        final s = summary(nutrition: fourMeals, steps: stepsOn([7250]));
        expect(s.advice, 'Te faltan unos 2.800 pasos al día para tu objetivo.');
      });

      test('5. Buena semana', () {
        final s = summary(nutrition: fourMeals, steps: stepsOn([10000]));
        expect(s.advice, WeekSummary.goodWeekAdvice);
      });
    });

    test('Nombre de la semana y semanas que se pueden ver', () {
      final today = dayOf(2);
      expect(WeekSummary.weekLabel(monday, today), 'Esta semana');
      expect(
        WeekSummary.weekLabel(DateTime(2026, 11, 9), today),
        'Semana pasada',
      );
      expect(WeekSummary.weekLabel(DateTime(2026, 11, 2), today), '2–8 nov');
      expect(
        WeekSummary.weekLabel(DateTime(2026, 10, 26), today),
        '26 oct – 1 nov',
      );

      // Hasta la semana en que se creó la cuenta, y 12 como mucho.
      final threeWeeksAgo = DateTime(2026, 10, 28);
      expect(WeekSummary.weeksBackAllowed(threeWeeksAgo, today), 3);
      expect(WeekSummary.weeksBackAllowed(DateTime(2025, 1, 1), today), 12);
      expect(WeekSummary.weeksBackAllowed(null, today), 12);
    });
  });
}
