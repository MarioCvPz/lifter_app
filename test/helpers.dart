import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/theme/app_theme.dart';

// Utilidades comunes de los tests. El AppStore se crea sin start(), así que
// no conecta con Firebase: los datos se meten a mano en sus listas.

const bench = Exercise(
  id: 'ex1',
  name: 'Press de banca',
  muscleGroup: 'Pecho',
  equipment: 'Barra',
  level: 'Intermedio',
);

const squat = Exercise(
  id: 'ex2',
  name: 'Sentadilla',
  muscleGroup: 'Piernas',
  equipment: 'Barra',
  level: 'Intermedio',
);

const deadlift = Exercise(
  id: 'ex3',
  name: 'Peso muerto',
  muscleGroup: 'Espalda',
  equipment: 'Barra',
  level: 'Avanzado',
);

const chicken = Food(
  id: 'f1',
  name: 'Pechuga de pollo',
  kcalPer100: 110,
  proteinPer100: 23,
  carbsPer100: 0,
  fatPer100: 1.5,
);

const rice = Food(
  id: 'f2',
  name: 'Arroz blanco cocido',
  kcalPer100: 130,
  proteinPer100: 2.7,
  carbsPer100: 28,
  fatPer100: 0.3,
);

Workout workoutOn(
  DateTime date, {
  List<WorkoutExercise>? exercises,
  String? routineId,
}) => Workout(
  id: date.toIso8601String(),
  name: 'Sesión',
  date: date,
  durationMin: 30,
  routineId: routineId,
  exercises:
      exercises ??
      const [
        WorkoutExercise(
          exercise: bench,
          sets: [WorkoutSet(reps: 10, weightKg: 50)],
        ),
      ],
);

UserProfile profile({
  String name = 'Ana',
  double weightKg = 70,
  String goal = 'Hipertrofia',
  int daysPerWeek = 4,
  UserRole role = UserRole.user,
}) => UserProfile(
  name: name,
  username: name.toLowerCase(),
  email: '${name.toLowerCase()}@test.com',
  weightKg: weightKg,
  goal: goal,
  daysPerWeek: daysPerWeek,
  role: role,
);

/// Monta [child] con el tema de la app y el store, en pantalla de móvil.
Future<void> pumpScreen(
  WidgetTester tester,
  AppStore store,
  Widget child,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    SessionScope(
      store: store,
      child: MaterialApp(theme: AppTheme.dark(), home: child),
    ),
  );
}
