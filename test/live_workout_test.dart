import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/catalog.dart';
import 'package:lifter_app/data/client_report.dart';
import 'package:lifter_app/data/routine_generator.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/data/workout_draft.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/workouts/live_workout_screen.dart';

import 'helpers.dart';

// Tests del entrenamiento en directo (prompt 5). La lógica está en
// WorkoutDraft, que es Dart puro: se prueba sin Firebase ni pantallas.

/// Hora fija de inicio, para que las duraciones sean exactas.
final start = DateTime(2026, 11, 11, 18);

/// Rutina de dos ejercicios (3 series vacías cada uno).
const pushRoutine = Routine(
  id: 'r1',
  name: 'Empuje',
  description: '',
  templateName: 'Personal',
  exercises: [bench, squat],
);

/// Perfil para el plan: lunes y jueves, 45 minutos, gimnasio.
UserProfile planUser({
  List<String> equipment = ProfileOptions.equipment,
  List<String> injuries = const [],
}) => UserProfile(
  name: 'Ana',
  username: 'ana',
  email: 'ana@test.com',
  daysPerWeek: 2,
  trainingDays: const [1, 4],
  sessionMinutes: 45,
  equipment: equipment,
  injuries: injuries,
  trainingPlace: TrainingPlace.gym,
);

/// Escribe reps y kg en la serie y la marca con ✓.
void markSet(DraftExercise item, int index, {required int reps, double? kg}) {
  item.sets[index]
    ..reps = reps
    ..weightKg = kg;
  expect(item.toggleSet(index, null), isNull);
}

void main() {
  final catalog = readSeed().exercises;

  test('CP-15 Solo se guardan las series marcadas y los ejercicios con '
      'alguna', () {
    final draft = WorkoutDraft.fromRoutine(pushRoutine, start);
    final benchItem = draft.exercises[0];
    markSet(benchItem, 0, reps: 10, kg: 60);
    markSet(benchItem, 1, reps: 8, kg: 70);
    // La tercera serie tiene valores pero no está marcada.
    benchItem.sets[2]
      ..reps = 6
      ..weightKg = 80;
    // La sentadilla no tiene ninguna serie marcada.

    final workout = draft.toWorkout(id: 'w1', date: start, durationMin: 50);

    expect(workout.exercises.length, 1);
    expect(workout.exercises.single.exercise, bench);
    expect(workout.exercises.single.sets.length, 2);
    expect(workout.volumeKg, 10 * 60 + 8 * 70);
    expect(workout.routineId, 'r1');
  });

  test('CP-15 Sin ninguna serie marcada no se puede guardar', () {
    final draft = WorkoutDraft.fromRoutine(pushRoutine, start);
    draft.exercises[0].sets[0].reps = 10; // escrita, pero sin marcar

    expect(
      draft.finishError(),
      'Marca al menos una serie para guardar el entrenamiento.',
    );
  });

  test('CP-15 Resumen "X de Y series · Z kg levantados"', () {
    final draft = WorkoutDraft.fromRoutine(pushRoutine, start);
    expect(draft.summary, '0 de 6 series · 0 kg levantados');

    markSet(draft.exercises[0], 0, reps: 10, kg: 60);
    markSet(draft.exercises[1], 0, reps: 5, kg: 102.5);
    draft.exercises[1].addSet();

    // 600 + 512,5 kg, y 7 series en total al añadir una.
    expect(draft.summary, '2 de 7 series · 1112,5 kg levantados');
  });

  test('CP-15 La duración sale del tiempo transcurrido (mínimo 1 min)', () {
    final draft = WorkoutDraft.empty(start);

    expect(draft.durationMin(start.add(const Duration(minutes: 64))), 64);
    expect(
      draft.durationMin(start.add(const Duration(minutes: 9, seconds: 29))),
      9,
    );
    expect(draft.durationMin(start.add(const Duration(seconds: 10))), 1);
    // Si el reloj del móvil se atrasa, tampoco baja de 1.
    expect(draft.durationMin(start.subtract(const Duration(minutes: 5))), 1);
  });

  test('CP-15 El comentario se guarda y un entreno antiguo sin él se lee '
      'bien', () {
    final draft = WorkoutDraft.fromRoutine(pushRoutine, start);
    markSet(draft.exercises[0], 0, reps: 10, kg: 60);
    draft.exercises[0].comment = '  Molestia en el hombro  ';

    final saved = draft.toWorkout(id: 'w1', date: start, durationMin: 40);
    // Ida y vuelta como si pasara por Firestore.
    final read = Workout.fromMap('w1', saved.toMap());
    expect(read.exercises.single.comment, 'Molestia en el hombro');

    // Un documento antiguo no tiene el campo `comment`.
    final old = Workout.fromMap('w0', {
      'name': 'Sesión',
      'date': saved.toMap()['date'],
      'durationMin': 30,
      'exercises': [
        {
          'exercise': bench.toMap(),
          'sets': [
            {'reps': 10, 'weightKg': 50},
          ],
        },
      ],
    });
    expect(old.exercises.single.comment, isNull);
    // Sin comentario, tampoco se escribe la clave en Firestore.
    expect(old.exercises.single.toMap().containsKey('comment'), isFalse);
  });

  test('CP-15 El entrenador ve los comentarios recientes del cliente', () {
    final now = DateTime.now();
    final report = ClientReport(
      user: AppUser(uid: 'u1', profile: profile()),
      workouts: [
        workoutOn(
          now,
          exercises: const [
            WorkoutExercise(
              exercise: bench,
              sets: [WorkoutSet(reps: 8, weightKg: 60)],
              comment: 'Molestia en el hombro',
            ),
            WorkoutExercise(
              exercise: squat,
              sets: [WorkoutSet(reps: 5, weightKg: 100)],
            ),
          ],
        ),
      ],
    );

    final comments = report.recentComments();
    expect(comments.length, 1);
    expect(comments.single.text, 'Molestia en el hombro');
    expect(comments.single.exercise, bench.name);
  });

  test('CP-15 "Sustituir" propone el mismo patrón, con su material y sin '
      'cargar sus lesiones', () {
    final user = planUser(
      equipment: const ['Mancuernas', 'Peso corporal'],
      injuries: const ['Hombro'],
    );
    final store = AppStore()
      ..user = user
      ..exercises.addAll(catalog);
    final benchPress = catalog.firstWhere(
      (e) => e.pattern == MovementPattern.horizontalPush,
    );

    final options = store.substituteSuggestions(benchPress);

    expect(options, isNotEmpty);
    expect(options, isNot(contains(benchPress)));
    for (final e in options) {
      expect(e.pattern, benchPress.pattern, reason: e.name);
      expect(user.equipment, contains(e.equipment), reason: e.name);
      expect(e.stressedZones.contains('Hombro'), isFalse, reason: e.name);
    }
  });

  group('CP-15 Guardar los cambios en el plan', () {
    late AppStore store;
    late PlanDay monday;
    late WorkoutDraft draft;
    late String removedId;
    late Exercise added;

    setUp(() {
      final user = planUser();
      store = AppStore()
        ..user = user
        ..exercises.addAll(catalog)
        ..plan = RoutineGenerator.generate(user, catalog);
      monday = store.plan!.dayFor(1)!;

      // Durante el entreno: quita el último y añade uno que no estaba.
      draft = WorkoutDraft.fromPlanDay(monday, start);
      removedId = draft.exercises.last.exercise.id;
      draft.removeAt(draft.exercises.length - 1);
      added = catalog.firstWhere((e) => !monday.contains(e.id));
      draft.insert(added);
    });

    test('con "Sí", el día del plan queda con los cambios', () {
      expect(draft.hasChanges, isTrue);

      // Lo que hace la pantalla al pulsar "Sí".
      store.updatePlanDay(draft.applyToPlanDay(monday, store.user!));

      final saved = store.plan!.dayFor(1)!;
      expect(saved.contains(removedId), isFalse);
      expect(saved.removedExerciseIds, contains(removedId));
      expect(saved.contains(added.id), isTrue);
      final addedPlan = saved.exercises.firstWhere(
        (e) => e.exercise.id == added.id,
      );
      expect(addedPlan.isCustom, isTrue);
      // El resto del plan no cambia.
      expect(store.plan!.dayFor(4)!.exercises.length, greaterThan(0));
    });

    test('con "Solo hoy", el plan no cambia', () {
      final before = monday.toMap();

      // "Solo hoy" no llama a updatePlanDay: el plan sigue igual, y
      // calcular el día cambiado tampoco toca el original.
      draft.applyToPlanDay(monday, store.user!);

      expect(store.plan!.dayFor(1)!.toMap(), before);
      expect(monday.toMap(), before);
    });

    test('cambiar solo el orden no cuenta como cambio', () {
      final reordered = WorkoutDraft.fromPlanDay(monday, start)..move(0, 1);
      expect(reordered.hasChanges, isFalse);
    });

    test('al sustituir, el nuevo ocupa el hueco y el antiguo cuenta como '
        'quitado', () {
      final replaced = WorkoutDraft.fromPlanDay(monday, start);
      final old = replaced.exercises.first.exercise;
      final substitute = store
          .substituteSuggestions(old, exclude: replaced.exerciseIds)
          .first;
      replaced.replaceAt(0, substitute);

      final day = replaced.applyToPlanDay(monday, store.user!);
      expect(day.exercises.first.exercise, substitute);
      expect(day.exercises.first.isCustom, isTrue);
      expect(day.removedExerciseIds, contains(old.id));
    });
  });

  testWidgets('CP-15 La pantalla muestra los ejercicios de la rutina y el '
      'resumen cambia al marcar una serie', (tester) async {
    await pumpScreen(
      tester,
      AppStore(),
      const LiveWorkoutScreen(routine: pushRoutine),
    );

    expect(find.text('Empuje'), findsOneWidget);
    expect(find.text(bench.name), findsOneWidget);
    expect(find.text(squat.name), findsOneWidget);
    expect(find.text('0 de 6 series · 0 kg levantados'), findsOneWidget);

    // Primera serie del press de banca: 60 kg × 10.
    await tester.enterText(find.byType(TextField).at(0), '60');
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.tap(find.byTooltip('Marcar serie como hecha').first);
    await tester.pump();

    expect(find.text('1 de 6 series · 600 kg levantados'), findsOneWidget);
    // Con el descanso automático, aparece la barra de descanso.
    expect(find.text('Saltar'), findsOneWidget);

    // Se quita la pantalla para que se cancele el Timer del cronómetro.
    await tester.pumpWidget(const SizedBox());
  });

  // ---------------------------- Otros cálculos (sin caso de prueba) --

  test('Al marcar una serie vacía se usan los valores de la última vez', () {
    final item = DraftExercise.basic(bench);
    const lastTime = [WorkoutSet(reps: 10, weightKg: 60)];

    // La segunda serie de hoy usa la última serie que hizo.
    expect(DraftExercise.hintFor(lastTime, 1), lastTime.first);
    expect(item.toggleSet(0, DraftExercise.hintFor(lastTime, 0)), isNull);
    expect(item.sets[0].reps, 10);
    expect(item.sets[0].weightKg, 60);

    // Sin pista ni repeticiones, no se marca.
    expect(item.toggleSet(1, null), isNotNull);
    expect(item.sets[1].done, isFalse);
  });

  test('Validación de las series', () {
    expect(DraftExercise.validateSet(10, 60), isNull);
    expect(DraftExercise.validateSet(10, 0), isNull); // peso corporal
    expect(DraftExercise.validateSet(null, 60), isNotNull);
    expect(DraftExercise.validateSet(0, 60), isNotNull);
    expect(DraftExercise.validateSet(101, 60), isNotNull);
    expect(DraftExercise.validateSet(10, -1), isNotNull);
    expect(DraftExercise.validateSet(10, 501), isNotNull);
  });

  test('Cuenta atrás del descanso: +15 s, −15 s y fin', () {
    final rest = RestCountdown()..start(90, start);
    rest.add(RestCountdown.step, start);
    expect(rest.remainingSeconds(start), 105);
    rest.add(-RestCountdown.step, start);
    expect(rest.remainingSeconds(start), 90);

    expect(rest.finishIfDue(start.add(const Duration(seconds: 89))), isFalse);
    expect(rest.finishIfDue(start.add(const Duration(seconds: 90))), isTrue);
    expect(rest.isRunning, isFalse);
    // Solo avisa una vez.
    expect(rest.finishIfDue(start.add(const Duration(seconds: 91))), isFalse);
  });

  test('Formatos del cronómetro, el descanso y la vista previa', () {
    expect(formatClock(const Duration(minutes: 5, seconds: 7)), '05:07');
    expect(formatClock(const Duration(hours: 1, minutes: 2)), '1:02:00');
    expect(formatRest(90), '1:30');
    expect(formatRest(30), '0:30');
    expect(DraftExercise.basic(bench).previewLabel, '3 series · 1:30');
  });

  test('Catálogo por grupo muscular y en orden alfabético', () {
    final groups = exercisesByMuscle(catalog);
    expect(groups.keys.toList(), muscleGroups);
    for (final list in groups.values) {
      final names = [for (final e in list) e.name.toLowerCase()];
      expect(names, [...names]..sort());
    }
  });

  test('El próximo entreno es el de hoy o el siguiente día del plan', () {
    final user = planUser(); // lunes y jueves
    final store = AppStore()
      ..user = user
      ..plan = RoutineGenerator.generate(user, catalog);

    expect(store.nextWorkout(DateTime(2026, 11, 9))!.weekday, 1); // lunes
    expect(store.nextWorkout(DateTime(2026, 11, 10))!.weekday, 4); // martes
    expect(store.nextWorkout(DateTime(2026, 11, 13))!.weekday, 1); // viernes
  });
}
