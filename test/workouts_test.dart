import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/data/workout_draft.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/workouts/live_workout_screen.dart';

import 'helpers.dart';

void main() {
  testWidgets('CP-02 No se guarda un entreno sin ninguna serie marcada', (
    tester,
  ) async {
    final store = AppStore();
    await pumpScreen(tester, store, const LiveWorkoutScreen());

    final finish = find.text('Terminar entrenamiento');
    await tester.ensureVisible(finish);
    await tester.tap(finish);
    await tester.pump();

    expect(
      find.text('Marca al menos una serie para guardar el entrenamiento.'),
      findsOneWidget,
    );
    expect(store.workouts, isEmpty);
    // Sigue en la pantalla del entrenamiento.
    expect(find.text('Entrenamiento'), findsWidgets);
    // Se quita la pantalla para que se cancele el Timer del cronómetro.
    await tester.pumpWidget(const SizedBox());
  });

  test('CP-03 La duración sale del cronómetro (mínimo 1 minuto)', () {
    final start = DateTime(2026, 11, 2, 18);
    final draft = WorkoutDraft.empty(start);

    // 42 min 40 s se redondean a 43.
    expect(
      draft.durationMin(start.add(const Duration(minutes: 42, seconds: 40))),
      43,
    );
    // 20 segundos cuentan como 1 minuto, y nunca menos.
    expect(draft.durationMin(start.add(const Duration(seconds: 20))), 1);
    expect(draft.durationMin(start), 1);
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
