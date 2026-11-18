import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lifter_app/app.dart';
import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/client_overview.dart';
import 'package:lifter_app/data/nutrition_calculator.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/data/trainer_link.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/trainer/client_screen.dart';
import 'package:lifter_app/screens/trainer/trainer_shell.dart';

import 'helpers.dart';

/// Miércoles 18 de noviembre de 2026: "hoy" en todos los ejemplos.
final today = DateTime(2026, 11, 18);

/// Día [day] de noviembre de 2026 (16 = lunes, 17 = martes…).
DateTime nov(int day) => DateTime(2026, 11, day);

/// Plan de lunes, miércoles y viernes.
final plan = TrainingPlan(
  generatedAt: nov(1),
  days: const [
    PlanDay(weekday: 1, type: PlanDayType.push, exercises: []),
    PlanDay(weekday: 3, type: PlanDayType.pull, exercises: []),
    PlanDay(weekday: 5, type: PlanDayType.legs, exercises: []),
  ],
);

NutritionEntry mealOn(DateTime date) => NutritionEntry(
  id: date.toIso8601String(),
  food: rice,
  grams: 200,
  date: date,
);

/// Entreno con un comentario en su primer ejercicio.
Workout commentedWorkout(DateTime date) => workoutOn(
  date,
  exercises: const [
    WorkoutExercise(
      exercise: bench,
      sets: [WorkoutSet(reps: 10, weightKg: 50)],
      comment: 'Molestia en el hombro',
    ),
  ],
);

ClientOverview client(
  String name, {
  List<Workout> workouts = const [],
  List<NutritionEntry> nutrition = const [],
  Map<String, CoachReply> replies = const {},
}) => ClientOverview(
  user: AppUser(
    uid: name,
    profile: profile(name: name),
  ),
  today: today,
  plan: plan,
  coach: const CoachSettings(),
  // Como los carga el store: del más reciente al más antiguo.
  workouts: [...workouts]..sort((a, b) => b.date.compareTo(a.date)),
  nutrition: nutrition,
  weights: const [],
  steps: const [],
  replies: replies,
);

void main() {
  group('CP-18 Modo entrenador', () {
    test('El modo se guarda y se recupera al volver a abrir', () async {
      SharedPreferences.setMockInitialValues({});
      final store = AppStore()..user = profile(role: UserRole.trainer);
      expect(store.inTrainerMode, isFalse); // por defecto, modo usuario

      await store.setTrainerMode(true);
      expect(store.inTrainerMode, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(AppStore.trainerModeKey), isTrue);

      final reopened = AppStore()..user = profile(role: UserRole.trainer);
      await reopened.loadTrainerMode();
      expect(reopened.inTrainerMode, isTrue);
    });

    test('Quien no es entrenador siempre está en modo usuario', () async {
      // Lo dejó guardado cuando era entrenador, pero ya no lo es.
      SharedPreferences.setMockInitialValues({AppStore.trainerModeKey: true});
      final store = AppStore()..user = profile();
      await store.loadTrainerMode();
      expect(store.inTrainerMode, isFalse);

      await store.setTrainerMode(true);
      expect(store.inTrainerMode, isFalse);
    });
  });

  group('CP-18 Avisos de los clientes', () {
    final loadedFrom = ClientOverview.workoutsFrom(today);

    test('Días sin entrenar: 3 o más con días de su plan en medio', () {
      // Último el viernes 13 → 5 días, y el lunes le tocaba.
      expect(
        ClientAlert.noTraining(
          plan: plan,
          lastWorkout: nov(13),
          loadedFrom: loadedFrom,
          today: today,
        )?.text,
        '5 días sin entrenar',
      );
      // Último el lunes 16 → solo 2 días.
      expect(
        ClientAlert.noTraining(
          plan: plan,
          lastWorkout: nov(16),
          loadedFrom: loadedFrom,
          today: today,
        ),
        isNull,
      );
      // Solo entrena los sábados: 4 días, pero en medio no le tocaba.
      final saturdays = TrainingPlan(
        generatedAt: nov(1),
        days: const [
          PlanDay(weekday: 6, type: PlanDayType.legs, exercises: []),
        ],
      );
      expect(
        ClientAlert.noTraining(
          plan: saturdays,
          lastWorkout: nov(14),
          loadedFrom: loadedFrom,
          today: today,
        ),
        isNull,
      );
      // Ningún entreno cargado: se cuenta desde el primer día cargado.
      expect(
        ClientAlert.noTraining(
          plan: plan,
          lastWorkout: null,
          loadedFrom: loadedFrom,
          today: today,
        )?.text,
        'Más de 23 días sin entrenar',
      );
    });

    test('Días sin comida: 2 o más seguidos hasta ayer', () {
      final from = ClientOverview.othersFrom(today);
      String? alert(List<NutritionEntry> meals) => ClientAlert.noFood(
        nutrition: meals,
        loadedFrom: from,
        today: today,
      )?.text;

      // Comió el domingo; lunes y martes nada.
      expect(alert([mealOn(nov(15))]), 'Sin registrar comida desde el lunes');
      expect(alert([mealOn(nov(16))]), isNull); // solo el martes
      expect(alert([mealOn(today)]), isNull); // hoy ya ha apuntado
      expect(alert([]), 'Sin registrar comida desde hace más de una semana');
    });

    test('Notas sin leer: dejan de contar al marcarlas como leídas', () {
      expect(ClientAlert.unreadNotes(0), isNull);
      expect(ClientAlert.unreadNotes(1)?.text, 'Te ha dejado 1 nota');
      expect(ClientAlert.unreadNotes(2)?.text, 'Te ha dejado 2 notas');

      final workout = commentedWorkout(nov(16));
      final eva = client('Eva', workouts: [workout]);
      expect(eva.unreadNotes, 1);
      expect(
        eva.alerts.map((a) => a.kind),
        contains(ClientAlertKind.unreadNotes),
      );

      final read = eva.withReplies([
        CoachReply(
          workoutId: workout.id,
          exerciseIndex: 0,
          exerciseId: bench.id,
          readAt: today,
        ),
      ]);
      expect(read.unreadNotes, 0);
    });

    test('El store marca como leídas las notas del cliente', () {
      final store = AppStore()
        ..clientOverviews = [
          client('Eva', workouts: [commentedWorkout(nov(16))]),
        ];
      expect(store.unreadClientNotes, 1);
      store.markNotesRead('Eva');
      expect(store.unreadClientNotes, 0);
    });
  });

  group('CP-18 Lista de clientes', () {
    // Ana: sin entrenos ni comida (aviso más grave: sin entrenar).
    final ana = client('Ana');
    // Bea: entrena, pero sin comida.
    final bea = client('Bea', workouts: [workoutOn(nov(16))]);
    // Eva: al día, pero con una nota sin leer.
    final eva = client(
      'Eva',
      workouts: [commentedWorkout(nov(16))],
      nutrition: [mealOn(today)],
    );
    // Dani: al día, con 1 de 3 entrenos.
    final dani = client(
      'Dani',
      workouts: [workoutOn(nov(16))],
      nutrition: [mealOn(today)],
    );
    // Carla: al día, con 2 entrenos y 3 días de comida (mejor nota).
    final carla = client(
      'Carla',
      workouts: [workoutOn(nov(16)), workoutOn(today)],
      nutrition: [mealOn(nov(16)), mealOn(nov(17)), mealOn(today)],
    );
    final all = [carla, dani, eva, bea, ana];

    List<String> names(List<ClientOverview> list) => [
      for (final c in list) c.name,
    ];

    test('Primero los avisos (del más grave al menos) y luego por nota', () {
      expect(ana.alert?.kind, ClientAlertKind.noTraining);
      expect(bea.alert?.kind, ClientAlertKind.noFood);
      expect(eva.alert?.kind, ClientAlertKind.unreadNotes);
      expect(dani.needsAttention, isFalse);
      expect(dani.score, lessThan(carla.score));

      expect(names(ClientOverview.visible(all)), [
        'Ana',
        'Bea',
        'Eva',
        'Dani',
        'Carla',
      ]);
    });

    test('Filtros y buscador', () {
      expect(
        names(ClientOverview.visible(all, filter: ClientFilter.attention)),
        ['Ana', 'Bea', 'Eva'],
      );
      expect(
        names(ClientOverview.visible(all, filter: ClientFilter.upToDate)),
        ['Dani', 'Carla'],
      );
      expect(names(ClientOverview.visible(all, query: 'AR')), ['Carla']);
    });

    test('Subtítulo de la fila y color de la nota', () {
      expect(
        dani.subtitle,
        'Ganar masa muscular · Entrenos 1/3 · último: 16 nov',
      );
      expect(ScoreLevel.of(70), ScoreLevel.good);
      expect(ScoreLevel.of(69), ScoreLevel.fair);
      expect(ScoreLevel.of(50), ScoreLevel.fair);
      expect(ScoreLevel.of(49), ScoreLevel.low);
    });
  });

  group('CP-18 Objetivos del entrenador: calorías', () {
    test('El cliente recibe las calorías y los macros se reparten solos', () {
      final store = AppStore()
        ..user = profile()
        ..myTrainerLink = TrainerLinkRules.newRequest(
          clientId: 'c1',
          clientName: 'Ana',
          trainerId: 't1',
          trainerName: 'Luis',
          code: 'ABC234',
          now: today,
        ).accept()
        ..coachSettings = const CoachSettings(kcalTarget: 2000);
      final m = store.macroTargets();
      // Las mismas cifras que el cálculo automático con 2.000 kcal.
      final expected = NutritionCalculator.macros(
        profile(),
        kcalOverride: 2000,
      );
      expect(
        [m.kcal, m.protein, m.carbs, m.fat],
        [2000, expected.protein, expected.carbs, expected.fat],
      );
      expect(m.fat, (2000 * 0.25 / 9).roundToDouble()); // 25 % de grasa
      expect(store.nutritionByCoach, isTrue);
      expect(store.coachLabel, 'Ajustado por tu entrenador');
    });

    test('Más de 5.000 kcal no se guarda y se explica', () async {
      const tooMuch = CoachSettings(kcalTarget: 5001);
      expect(tooMuch.validate(), contains('5.000'));
      // El store valida antes de escribir, así que no llega a Firestore.
      final error = await AppStore().saveClientCoachSettings('c1', tooMuch);
      expect(error, contains('5.000'));
      expect(const CoachSettings(kcalTarget: 5000).validate(), isNull);
    });
  });

  group('CP-18 Pantallas', () {
    testWidgets('En modo entrenador sale su barra y la lista de clientes', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final trainer = profile(name: 'Luis', role: UserRole.trainer)
        ..onboardingCompleted = true;
      final store = AppStore()
        ..user = trainer
        ..profileLoaded = true
        ..clientOverviews = [
          client('Ana'),
          client(
            'Carla',
            workouts: [workoutOn(nov(16))],
            nutrition: [mealOn(today)],
          ),
        ];
      // Arranca en el último modo usado: el de entrenador. (No se prueba
      // el modo usuario aquí porque su pestaña Perfil necesita Firebase.)
      await store.setTrainerMode(true);
      await tester.pumpWidget(LifterApp(store: store));
      await tester.pumpAndSettle();

      expect(find.byType(TrainerShell), findsOneWidget);
      expect(find.bySemanticsLabel('Inicio'), findsNothing);
      expect(find.bySemanticsLabel('Clientes'), findsOneWidget);
      expect(find.bySemanticsLabel('Notas'), findsOneWidget);
      expect(find.text('Mis clientes'), findsOneWidget);
      expect(find.text('2 clientes · 1 necesita atención'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Carla'), findsOneWidget);
      expect(find.text('Usuario'), findsOneWidget); // el selector de modo
    });

    testWidgets('Ficha: al abrir Notas se leen y se pueden responder', (
      tester,
    ) async {
      final store = AppStore()
        ..user = profile(name: 'Luis', role: UserRole.trainer)
        ..clientOverviews = [
          client('Eva', workouts: [commentedWorkout(nov(16))]),
        ];
      await pumpScreen(
        tester,
        store,
        const ClientScreen(clientId: 'Eva', initialTab: ClientTab.notes),
      );
      await tester.pumpAndSettle();

      expect(find.text('"Molestia en el hombro"'), findsOneWidget);
      expect(store.unreadClientNotes, 0); // se marcó al abrir

      await tester.tap(find.text('Responder'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Baja el peso');
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Baja el peso'), findsOneWidget);
      expect(store.overviewOf('Eva')?.notes.first.replyText, 'Baja el peso');
    });
  });
}
