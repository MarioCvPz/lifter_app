import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/workouts/register_workout_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('CP-02 No se guarda un entreno sin ejercicios', (tester) async {
    final store = AppStore();
    await pumpScreen(tester, store, const RegisterWorkoutScreen());

    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text('Añade al menos un ejercicio.'), findsOneWidget);
    expect(store.workouts, isEmpty);
    // Sigue en la pantalla de registro.
    expect(find.text('Registrar entrenamiento'), findsOneWidget);
  });

  testWidgets('CP-03 Sin duración escrita se usan 5 minutos por ejercicio', (
    tester,
  ) async {
    final store = AppStore()..exercises.addAll([bench, squat]);
    await pumpScreen(tester, store, const RegisterWorkoutScreen());

    expect(find.textContaining('(0 min)'), findsOneWidget);

    for (final ex in [bench, squat]) {
      await tester.tap(find.text('Añadir ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ex.name).last);
      await tester.pumpAndSettle();
    }

    // 2 ejercicios × 5 min.
    expect(find.textContaining('(10 min)'), findsOneWidget);
    expect(Workout.minutesPerExercise, 5);
  });

  test('El volumen de un entreno es la suma de reps × kg', () {
    final w = workoutOn(
      DateTime(2026, 11, 2),
      exercises: const [
        WorkoutExercise(
          exercise: bench,
          sets: [
            WorkoutSet(reps: 10, weightKg: 60),
            WorkoutSet(reps: 8, weightKg: 70),
          ],
        ),
        WorkoutExercise(
          exercise: squat,
          sets: [WorkoutSet(reps: 5, weightKg: 100)],
        ),
      ],
    );
    // 10·60 + 8·70 + 5·100 = 600 + 560 + 500
    expect(w.volumeKg, 1660);
  });

  test('Racha de días seguidos y mejor racha', () {
    final now = DateTime.now();
    DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d, 10);
    final store = AppStore()
      ..workouts.addAll([
        workoutOn(daysAgo(0)),
        workoutOn(daysAgo(1)),
        workoutOn(daysAgo(2)),
        // Hueco el día 3: la racha actual es de 3.
        workoutOn(daysAgo(10)),
        workoutOn(daysAgo(11)),
        workoutOn(daysAgo(12)),
        workoutOn(daysAgo(13)),
      ]);

    expect(store.streakDays(), 3);
    expect(store.bestStreak(), 4);
    expect(store.trainedOn(now), isTrue);
  });
}
