import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/coach_plan.dart';
import 'package:lifter_app/data/nutrition_calculator.dart';
import 'package:lifter_app/data/routine_generator.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/data/trainer_link.dart';
import 'package:lifter_app/data/week_summary.dart';
import 'package:lifter_app/data/workout_draft.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/profile/my_trainer_card.dart';
import 'package:lifter_app/screens/routines/routine_widgets.dart';
import 'package:lifter_app/screens/trainer/trainer_shell.dart';
import 'package:lifter_app/screens/workouts/exercise_card.dart';

import 'helpers.dart';

/// Plan de lunes, miércoles y viernes: el miércoles es el día 2.
const threeDayPlan = [
  PlanDay(weekday: 1, type: PlanDayType.push, exercises: []),
  PlanDay(weekday: 3, type: PlanDayType.pull, exercises: []),
  PlanDay(weekday: 5, type: PlanDayType.legs, exercises: []),
];

/// Rutina de Luis para Ana en el día [dayNumber] (null = antigua, sin día).
AssignedRoutine assignedOn(int? dayNumber, {String name = 'Push'}) =>
    AssignedRoutine(
      id: name,
      routine: Routine(
        id: name,
        name: name,
        description: '',
        templateName: 'Entrenador',
        exercises: const [bench],
      ),
      trainerId: 'trainer1',
      trainerName: 'Luis',
      userId: 'client1',
      userName: 'Ana',
      createdAt: DateTime(2026, 11, 18),
      dayNumber: dayNumber,
    );

/// Solicitud de Ana (client1) al entrenador Luis (trainer1).
TrainerLink request({String clientId = 'client1'}) =>
    TrainerLinkRules.newRequest(
      clientId: clientId,
      clientName: 'Ana',
      trainerId: 'trainer1',
      trainerName: 'Luis',
      code: 'ABC234',
      now: DateTime(2026, 11, 17),
    );

void main() {
  group('CP-17 Código de entrenador', () {
    test('Tiene 6 caracteres sin O, 0, I ni 1', () {
      for (var i = 0; i < 200; i++) {
        final code = TrainerCode.generate();
        expect(code, hasLength(6));
        expect(TrainerCode.isValidFormat(code), isTrue, reason: code);
        expect(code, isNot(matches(RegExp('[O0I1]'))));
      }
      expect(TrainerCode.alphabet, isNot(matches(RegExp('[O0I1]'))));
    });

    test('Dos códigos generados seguidos suelen ser distintos', () {
      final codes = {for (var i = 0; i < 50; i++) TrainerCode.generate()};
      // Con mil millones de combinaciones, repetir es casi imposible.
      expect(codes.length, greaterThanOrEqualTo(49));
    });

    test('Lo que escribe el usuario se normaliza y se valida', () {
      expect(TrainerCode.normalize(' ab c2de '), 'ABC2DE');
      expect(TrainerCode.isValidFormat('ABC2DE'), isTrue);
      expect(TrainerCode.isValidFormat('ABC2D'), isFalse); // 5 caracteres
      expect(TrainerCode.isValidFormat('ABC2D0'), isFalse); // lleva un 0
      expect(TrainerCode.isValidFormat('OBC2DE'), isFalse); // lleva una O
    });
  });

  group('CP-17 Estados del vínculo', () {
    test('Sin entrenador → pendiente → vinculado → desvinculado', () {
      final store = AppStore()..user = profile();
      expect(store.myTrainerState, MyTrainerState.none);

      store.myTrainerLink = request();
      expect(store.myTrainerState, MyTrainerState.pending);
      expect(store.hasAcceptedTrainer, isFalse);

      store.myTrainerLink = store.myTrainerLink?.accept();
      expect(store.myTrainerState, MyTrainerState.linked);
      expect(store.hasAcceptedTrainer, isTrue);

      store.leaveTrainer();
      expect(store.myTrainerState, MyTrainerState.none);
    });

    test('No se puede tener dos: con una solicitud o un entrenador no se '
        'envía otra', () {
      expect(
        TrainerLinkRules.validateRequest(code: 'ABC234', current: null),
        isNull,
      );
      expect(
        TrainerLinkRules.validateRequest(code: 'ABC234', current: request()),
        TrainerLinkRules.alreadyHasTrainer,
      );
      expect(
        TrainerLinkRules.validateRequest(
          code: 'ABC234',
          current: request().accept(),
        ),
        TrainerLinkRules.alreadyHasTrainer,
      );
      expect(
        TrainerLinkRules.validateRequest(code: 'AB', current: null),
        TrainerLinkRules.badFormat,
      );
    });

    test('Mis clientes son los vinculados, no a quien asigné rutinas', () {
      final store = AppStore()..user = profile();
      store.trainerLinks.addAll([request(), request(clientId: 'client2')]);
      expect(store.pendingRequests, hasLength(2));
      expect(store.myClientIds, isEmpty);

      store.acceptRequest('client1');
      expect(store.myClientIds, {'client1'});
      expect(store.pendingRequests.single.clientId, 'client2');

      // Rechazar una solicitud y desvincular a un cliente la quitan.
      store.removeClientLink('client2');
      store.removeClientLink('client1');
      expect(store.trainerLinks, isEmpty);
      expect(store.myClientIds, isEmpty);
    });

    test('fromMap y toMap del vínculo', () {
      final link = TrainerLink.fromMap(request().accept().toMap());
      expect(link.status, LinkStatus.accepted);
      expect(
        [link.clientId, link.trainerName, link.code],
        ['client1', 'Luis', 'ABC234'],
      );
    });
  });

  group('CP-17 Objetivos del entrenador', () {
    final client = profile();

    test('Las calorías del entrenador sustituyen al cálculo', () {
      final auto = NutritionCalculator.macros(client);
      final coach = NutritionCalculator.macros(client, kcalOverride: 2000);
      expect(coach.kcal, 2000);
      // La proteína es la automática, la grasa el 25 % y los hidratos, lo
      // que queda.
      expect(coach.protein, auto.protein);
      expect(coach.fat, (2000 * 0.25 / 9).roundToDouble());
      expect(
        coach.carbs,
        ((2000 - auto.protein * 4 - 2000 * 0.25 / 9 * 9) / 4).roundToDouble(),
      );

      // Con null se usa el cálculo automático.
      final none = NutritionCalculator.macros(client);
      expect([none.kcal, none.protein], [auto.kcal, auto.protein]);
    });

    test('El store usa los objetivos del entrenador si existen', () {
      final store = AppStore()..user = profile();
      final auto = store.macroTargets();
      expect(store.nutritionByCoach, isFalse);

      store.coachSettings = const CoachSettings(kcalTarget: 2200);
      expect(store.macroTargets().kcal, 2200);
      expect(store.macroTargets().protein, auto.protein);
      expect(store.nutritionByCoach, isTrue);

      // Las respuestas del cuestionario no llevan entrenador.
      expect(store.macroTargets(profile()).kcal, auto.kcal);
    });

    test('El objetivo de pasos del entrenador sustituye al del perfil', () {
      final store = AppStore()..user = (profile()..stepsGoal = 8000);
      expect(store.stepsGoalInUse, 8000);

      store.coachSettings = const CoachSettings(stepsGoal: 12000);
      expect(store.stepsGoalInUse, 12000);
      expect(store.stepsByCoach, isTrue);
      store.saveSteps(6000);
      final monday = WeekSummary.mondayOf(DateTime.now());
      expect(store.weekSummary(monday).stepsPercent, closeTo(50, 0.001));
    });

    test('Al desvincularse se mantienen hasta "Volver al automático"', () {
      final store = AppStore()..user = (profile()..stepsGoal = 8000);
      store.myTrainerLink = request().accept();
      store.coachSettings = const CoachSettings(stepsGoal: 12000);
      expect(store.coachLabel, 'Ajustado por tu entrenador');

      // Con entrenador, el cliente no puede quitarlos.
      store.resetMyCoachSettings();
      expect(store.stepsGoalInUse, 12000);

      store.leaveTrainer();
      expect(store.stepsGoalInUse, 12000);
      expect(store.coachLabel, 'Ajustado por tu entrenador anterior');

      store.resetMyCoachSettings();
      expect(store.stepsGoalInUse, 8000);
    });

    test('Validación: calorías 1.000–5.000 y pasos', () {
      expect(const CoachSettings().validate(), isNull);
      expect(const CoachSettings(kcalTarget: 999).validate(), isNotNull);
      expect(const CoachSettings(kcalTarget: 5000).validate(), isNull);
      expect(const CoachSettings(kcalTarget: 5001).validate(), isNotNull);
      expect(const CoachSettings(stepsGoal: 500).validate(), isNotNull);
      final read = CoachSettings.fromMap(
        const CoachSettings(kcalTarget: 2000, stepsGoal: 9000).toMap(),
      );
      expect([read.kcalTarget, read.stepsGoal], [2000, 9000]);
    });
  });

  group('CP-17 Plan editado por el entrenador', () {
    final catalog = readSeed().exercises;
    final client = profile();

    test('trainerNote y byTrainer se guardan y se leen', () {
      final planned = CoachPlan.mark(
        RoutineGenerator.prescribe(bench, client),
      ).copyWith(trainerNote: () => 'Baja en 3 segundos');
      final read = PlanExercise.fromMap(planned.toMap());
      expect(read.byTrainer, isTrue);
      expect(read.isCustom, isTrue);
      expect(read.trainerNote, 'Baja en 3 segundos');

      // Un plan antiguo, sin estos campos.
      final old = PlanExercise.fromMap({'exercise': bench.toMap(), 'sets': 3});
      expect([old.byTrainer, old.trainerNote], [false, null]);
    });

    test('Un ejercicio del entrenador se mantiene al actualizar el plan', () {
      final plan = RoutineGenerator.generate(client, catalog);
      final day = plan.days.first;
      final first = day.exercises.first;
      final edited = CoachPlan.update(
        day,
        first.copyWith(sets: 5, minReps: 3, trainerNote: () => 'Pesado'),
      );

      final updated = RoutineGenerator.update(
        plan.withDay(edited),
        client,
        catalog,
      ).plan;
      final kept = updated.days.first.exercises.firstWhere(
        (e) => e.exercise.id == first.exercise.id,
      );
      expect(kept.byTrainer, isTrue);
      expect([kept.sets, kept.minReps], [5, 3]);
      expect(kept.trainerNote, 'Pesado');
    });

    test('Añadir y cambiar ejercicios los marca como del entrenador', () {
      final day = RoutineGenerator.generate(client, catalog).days.first;
      final extra = catalog.firstWhere((e) => !day.contains(e.id));
      final added = CoachPlan.add(day, extra, client);
      expect(added.exercises.last.byTrainer, isTrue);

      final old = day.exercises.first.exercise.id;
      final replaced = CoachPlan.replace(day, old, extra, client);
      expect(replaced.exercises.first.exercise.id, extra.id);
      expect(replaced.exercises.first.byTrainer, isTrue);
      expect(replaced.removedExerciseIds, contains(old));
    });

    test('Avisa (sin impedirlo) si no tiene el material o está lesionado', () {
      final noBar = profile()..equipment = ['Mancuernas'];
      expect(CoachPlan.warningFor(bench, noBar), contains('barra'));
      expect(CoachPlan.warningFor(bench, client), isNull);
    });

    test('Series, repeticiones y descanso razonables', () {
      String? check(int sets, int min, int max, int rest) => CoachPlan.validate(
        sets: sets,
        minReps: min,
        maxRepsValue: max,
        restSeconds: rest,
      );
      expect(check(4, 8, 12, 90), isNull);
      expect(check(0, 8, 12, 90), isNotNull);
      expect(check(4, 12, 8, 90), isNotNull);
      expect(check(4, 8, 12, 700), isNotNull);
    });
  });

  group('CP-17 Pantallas', () {
    testWidgets('"Mi entrenador" muestra sus tres estados', (tester) async {
      final store = AppStore()..user = profile();
      await pumpScreen(
        tester,
        store,
        Scaffold(
          body: ListenableBuilder(
            listenable: store,
            builder: (_, _) => MyTrainerCard(store: store),
          ),
        ),
      );
      expect(find.text('Enviar solicitud'), findsOneWidget);

      // Un código con un formato imposible no se envía.
      await tester.enterText(find.byType(TextField), 'AB');
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();
      expect(find.text(TrainerLinkRules.badFormat), findsOneWidget);

      store.myTrainerLink = request();
      store.notifyListeners();
      await tester.pump();
      expect(find.textContaining('Solicitud enviada a Luis'), findsOneWidget);
      expect(find.text('Cancelar solicitud'), findsOneWidget);

      store.myTrainerLink = request().accept();
      store.notifyListeners();
      await tester.pump();
      expect(find.text('Luis'), findsOneWidget);
      await tester.tap(find.text('Desvincular'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desvincular'));
      await tester.pumpAndSettle();
      expect(store.myTrainerState, MyTrainerState.none);
      expect(find.text('Enviar solicitud'), findsOneWidget);
    });

    testWidgets('Panel de entrenador sin clientes, con el globo de '
        'solicitudes', (tester) async {
      final store = AppStore()..user = profile(role: UserRole.trainer);
      store.trainerLinks.add(request());
      // Desde el prompt 8, el panel es el modo entrenador (TrainerShell).
      await pumpScreen(tester, store, const TrainerShell());
      await tester.pumpAndSettle();

      // Sin clientes no falla: sale el aviso para compartir el código.
      expect(find.textContaining('Todavía no tienes clientes'), findsOneWidget);
      expect(find.text('Crear código'), findsOneWidget);
      // El globo con el número de solicitudes pendientes.
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);

      await tester.tap(find.text('1 solicitud nueva para aceptar'));
      await tester.pumpAndSettle();
      expect(find.text('Ana'), findsOneWidget);
      await tester.tap(find.text('Aceptar'));
      await tester.pumpAndSettle();
      expect(store.myClientIds, {'client1'});
      expect(store.pendingRequests, isEmpty);
    });

    testWidgets('La nota del entrenador sale en la tarjeta del ejercicio', (
      tester,
    ) async {
      final planned = CoachPlan.mark(
        RoutineGenerator.prescribe(bench, profile()),
      ).copyWith(trainerNote: () => 'Baja en 3 segundos');
      final item = DraftExercise.fromPlan(planned);
      expect(item.trainerNote, 'Baja en 3 segundos');

      Widget card(String? note) => ExerciseCard(
        number: 1,
        item: item,
        lastSets: const [],
        onChanged: () {},
        onToggleSet: (_) {},
        onAddSet: () {},
        onDeleteSet: (_) {},
        onMarkAll: () {},
        onHistory: () {},
        onMenu: (_) {},
        isFirst: true,
        isLast: true,
        trainerNote: note,
      );
      final store = AppStore()..user = profile();
      await pumpScreen(tester, store, Scaffold(body: card(item.trainerNote)));
      expect(find.textContaining('Nota de tu entrenador'), findsOneWidget);
      expect(find.textContaining('Baja en 3 segundos'), findsOneWidget);

      // Sin entrenador, la pantalla pasa null y no se ve.
      await pumpScreen(tester, store, Scaffold(body: card(null)));
      expect(find.textContaining('Nota de tu entrenador'), findsNothing);
    });
  });
  group('CP-17 Rutinas asignadas por día', () {
    AppStore clientStore() => AppStore()
      ..user = profile()
      ..plan = TrainingPlan(
        generatedAt: DateTime(2026, 11),
        days: threeDayPlan,
      );

    test('Una rutina del día 2 solo sustituye a ese día del plan', () {
      final store = clientStore()..assignedToMe.add(assignedOn(2));
      expect(store.workoutFor(1)?.fromTrainer, isFalse); // Lunes: su plan
      expect(store.workoutFor(3)?.fromTrainer, isTrue); // Miércoles: día 2
      expect(store.workoutFor(3)?.name, 'Push');
      expect(store.workoutFor(5)?.fromTrainer, isFalse); // Viernes: su plan
      expect(store.workoutFor(2), isNull); // Martes: descanso
    });

    test('Las antiguas, sin día, siguen valiendo para todos los días', () {
      final store = clientStore()
        // La lista va de la más nueva a la más antigua.
        ..assignedToMe.addAll([assignedOn(1, name: 'Nueva'), assignedOn(null)]);
      expect(store.workoutFor(1)?.name, 'Nueva');
      expect(store.workoutFor(3)?.name, 'Push');
      expect(store.workoutFor(5)?.name, 'Push');
    });

    test('El día se guarda y se lee; sin él, "Todos los días"', () {
      final map = assignedOn(3).toMap();
      expect(map['dayNumber'], 3);
      final read = AssignedRoutine.fromMap('a1', map);
      expect(read.dayNumber, 3);
      expect(read.dayLabel, 'Día 3');

      final old = AssignedRoutine.fromMap('a2', assignedOn(null).toMap());
      expect(old.dayNumber, isNull);
      expect(old.dayLabel, 'Todos los días');
    });

    testWidgets('El editor de rutinas agrupa los ejercicios por músculo', (
      tester,
    ) async {
      final store = AppStore()..user = profile();
      await pumpScreen(
        tester,
        store,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRoutineEditor(
                context,
                exercises: const [bench, squat, deadlift],
              ),
              child: const Text('Abrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      // Cerrados se ven los grupos, no los ejercicios.
      expect(find.text('Pecho'), findsOneWidget);
      expect(find.text('Piernas'), findsOneWidget);
      expect(find.text('Press de banca'), findsNothing);

      await tester.tap(find.text('Pecho'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Press de banca'));
      await tester.pumpAndSettle();
      expect(find.text('1 de 1 elegidos'), findsOneWidget);
      expect(find.text('1 ejercicios elegidos'), findsOneWidget);
    });
  });
}
