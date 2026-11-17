import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/routine_generator.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';

import 'helpers.dart';

/// Fecha fija para que dos planes generados sean comparables.
final fixedDate = DateTime(2026, 11, 10);

/// Perfil para el generador. Por defecto: intermedio, ganar masa muscular,
/// lunes a jueves, 60 minutos, gimnasio con todo el material y sin
/// lesiones.
UserProfile planProfile({
  String experience = 'Intermedio',
  TrainingGoal goal = TrainingGoal.muscleGain,
  List<int> trainingDays = const [1, 2, 3, 4],
  int sessionMinutes = 60,
  List<String> equipment = ProfileOptions.equipment,
  List<String> injuries = const [],
  TrainingPlace trainingPlace = TrainingPlace.gym,
}) => UserProfile(
  name: 'Ana',
  username: 'ana',
  email: 'ana@test.com',
  experience: experience,
  goal: goal,
  daysPerWeek: trainingDays.length,
  trainingDays: trainingDays,
  sessionMinutes: sessionMinutes,
  equipment: equipment,
  injuries: injuries,
  trainingPlace: trainingPlace,
);

/// Todos los ejercicios del plan, de todos los días.
List<Exercise> allExercises(TrainingPlan plan) => [
  for (final day in plan.days)
    for (final e in day.exercises) e.exercise,
];

/// Día de entreno de ese día de la semana; el test falla si es de descanso.
PlanDay dayOn(TrainingPlan plan, int weekday) =>
    plan.dayFor(weekday) ?? fail('El día $weekday no es de entreno');

List<String> namesOf(PlanDay day) => [
  for (final e in day.exercises) e.exercise.name,
];

void main() {
  final catalog = readSeed().exercises;
  Exercise named(String name) => catalog.firstWhere((e) => e.name == name);

  test('CP-14 La estructura depende de los días (2 a 6) y del nivel', () {
    const week = [1, 2, 3, 4, 5, 6];
    for (var days = 2; days <= 6; days++) {
      final profile = planProfile(trainingDays: week.take(days).toList());
      final plan = RoutineGenerator.generate(profile, catalog);
      expect(plan.structure, RoutineGenerator.structures[days]);
    }

    // Excepción: principiante con 3 días → tres full body.
    final beginner = planProfile(
      experience: 'Principiante',
      trainingDays: [1, 3, 5],
    );
    final plan = RoutineGenerator.generate(beginner, catalog);
    expect(plan.structure, [
      PlanDayType.fullBodyA,
      PlanDayType.fullBodyB,
      PlanDayType.fullBodyC,
    ]);
    // Los tipos se reparten en los días elegidos, de lunes a domingo.
    expect([for (final d in plan.days) d.weekday], [1, 3, 5]);
  });

  test('CP-14 El número de ejercicios depende de los minutos', () {
    for (final (minutes, count) in [(45, 5), (60, 6), (90, 8)]) {
      final profile = planProfile(sessionMinutes: minutes);
      final plan = RoutineGenerator.generate(profile, catalog);
      for (final day in plan.days) {
        expect(day.exercises, hasLength(count), reason: '$minutes min');
      }
    }
  });

  test('CP-14 Solo con peso corporal recibe solo ejercicios de peso '
      'corporal', () {
    // En casa: en el gimnasio el peso corporal solo entra en los huecos de
    // core, así que con solo ese material el plan saldría casi vacío.
    final profile = planProfile(
      equipment: ['Peso corporal'],
      trainingPlace: TrainingPlace.home,
    );
    final exercises = allExercises(RoutineGenerator.generate(profile, catalog));

    expect(exercises, isNotEmpty);
    for (final e in exercises) {
      expect(e.equipment, 'Peso corporal', reason: e.name);
    }
  });

  test('CP-14 Con lesión de rodilla no recibe ejercicios que la carguen', () {
    final profile = planProfile(
      trainingDays: [1, 2, 3, 4, 5, 6],
      sessionMinutes: 90,
      injuries: ['Rodilla'],
    );
    final exercises = allExercises(RoutineGenerator.generate(profile, catalog));

    expect(exercises, isNotEmpty);
    for (final e in exercises) {
      expect(e.stressedZones, isNot(contains('Rodilla')), reason: e.name);
    }
  });

  test('CP-14 Un principiante no recibe ejercicios avanzados si hay '
      'alternativas', () {
    final profile = planProfile(
      experience: 'Principiante',
      trainingDays: [1, 2, 3, 4, 5],
      sessionMinutes: 90,
    );
    final plan = RoutineGenerator.generate(profile, catalog);

    for (final e in allExercises(plan)) {
      // Si es de un nivel superior, es porque no había otro de su patrón.
      if (!RoutineGenerator.levelAllowed(e, profile)) {
        expect(
          RoutineGenerator.candidates(e.pattern, profile, catalog),
          isEmpty,
          reason: e.name,
        );
      }
    }
    expect(allExercises(plan).map((e) => e.level), isNot(contains('Avanzado')));
  });

  test('CP-14 No hay ejercicios repetidos en un mismo día', () {
    for (var days = 2; days <= 6; days++) {
      final profile = planProfile(
        trainingDays: [1, 2, 3, 4, 5, 6].take(days).toList(),
        sessionMinutes: 90,
      );
      for (final day in RoutineGenerator.generate(profile, catalog).days) {
        final ids = [for (final e in day.exercises) e.exercise.id];
        expect(ids.toSet(), hasLength(ids.length), reason: day.name);
      }
    }
  });

  test('CP-14 Con el mismo perfil se obtiene el mismo plan', () {
    final profile = planProfile(trainingDays: [1, 2, 3, 4, 5, 6]);
    final first = RoutineGenerator.generate(profile, catalog, now: fixedDate);
    final second = RoutineGenerator.generate(profile, catalog, now: fixedDate);

    expect(
      [for (final d in second.days) d.toMap()],
      [for (final d in first.days) d.toMap()],
    );
  });

  test('CP-14 Series, repeticiones y descanso según objetivo y nivel', () {
    PlanExercise prescribe(String name, UserProfile profile) =>
        RoutineGenerator.prescribe(named(name), profile);
    const compound = 'Press de banca';
    const isolation = 'Press francés';

    // Fuerza, intermedio: 4×4–6 en multiarticular, 3×8–12 en aislamiento.
    final strength = planProfile(goal: TrainingGoal.strength);
    final heavy = prescribe(compound, strength);
    expect([heavy.sets, heavy.minReps, heavy.maxReps], [4, 4, 6]);
    expect(heavy.restSeconds, 150);
    final light = prescribe(isolation, strength);
    expect([light.sets, light.minReps, light.maxReps], [3, 8, 12]);

    // Ganar masa muscular: 8–12 y 90 s.
    final gain = prescribe(compound, planProfile());
    expect([gain.minReps, gain.maxReps, gain.restSeconds], [8, 12, 90]);

    // Perder grasa, principiante: siempre 3 series, 10–15 y 60 s.
    final beginner = planProfile(
      experience: 'Principiante',
      goal: TrainingGoal.fatLoss,
    );
    final loss = prescribe(compound, beginner);
    expect([loss.sets, loss.minReps, loss.maxReps], [3, 10, 15]);
    expect(loss.restSeconds, 60);
  });

  test('CP-14 En el gimnasio: sin bandas y peso corporal solo sin '
      'alternativa', () {
    final profile = planProfile(
      experience: 'Avanzado',
      trainingDays: [1, 2, 3, 4, 5, 6],
      sessionMinutes: 90,
    );
    final plan = RoutineGenerator.generate(profile, catalog);

    for (final day in plan.days) {
      final inDay = {for (final e in day.exercises) e.exercise.id};
      for (final e in day.exercises.map((p) => p.exercise)) {
        expect(e.equipment, isNot('Bandas elásticas'), reason: e.name);
        if (e.equipment != RoutineGenerator.bodyweightEquipment) continue;
        // Si es de peso corporal, no quedaba ningún ejercicio de gimnasio
        // de su patrón que se pudiera poner en ese día.
        final gymAlternatives = catalog.where(
          (c) =>
              c.pattern == e.pattern &&
              !inDay.contains(c.id) &&
              RoutineGenerator.gymEquipment.contains(c.equipment) &&
              RoutineGenerator.isDoable(c, profile),
        );
        expect(gymAlternatives, isEmpty, reason: '${day.name}: ${e.name}');
      }
    }
    // Prefiere los de su nivel: un avanzado recibe ejercicios de avanzado.
    expect(allExercises(plan).map((e) => e.level), contains('Avanzado'));
  });

  test('CP-14 En el gimnasio con lesión de codo, Empuje no lleva peso '
      'corporal ni bandas', () {
    // Antes, el segundo hueco de empuje horizontal se quedaba sin
    // ejercicios de gimnasio y recibía "Flexiones declinadas".
    final profile = planProfile(injuries: ['Codo']);
    final plan = RoutineGenerator.generate(profile, catalog);
    final push = plan.days.firstWhere((d) => d.type == PlanDayType.push);

    expect(push.exercises, isNotEmpty);
    expect(namesOf(push), isNot(contains('Flexiones declinadas')));
    for (final e in push.exercises.map((p) => p.exercise)) {
      expect(RoutineGenerator.gymEquipment, contains(e.equipment));
      expect(e.stressedZones, isNot(contains('Codo')), reason: e.name);
    }
    // El hueco se rellena con otro ejercicio de pecho de gimnasio.
    expect(namesOf(push), contains('Cruce de poleas'));
  });

  test('CP-14 En el gimnasio, el peso corporal solo entra en los huecos de '
      'core', () {
    final profile = planProfile(
      experience: 'Avanzado',
      trainingDays: [1, 2, 3, 4, 5, 6],
      sessionMinutes: 90,
      injuries: ['Codo', 'Hombro'],
    );
    for (final e in allExercises(RoutineGenerator.generate(profile, catalog))) {
      expect(e.equipment, isNot('Bandas elásticas'), reason: e.name);
      if (e.equipment == RoutineGenerator.bodyweightEquipment) {
        expect(e.pattern, MovementPattern.core, reason: e.name);
      }
    }
  });

  test('CP-14 En casa se siguen usando mancuernas, bandas y peso '
      'corporal', () {
    final profile = planProfile(
      trainingPlace: TrainingPlace.home,
      trainingDays: [1, 2, 3, 4, 5],
      sessionMinutes: 90,
      equipment: ['Mancuernas', 'Bandas elásticas', 'Peso corporal'],
    );
    final used = {
      for (final e in allExercises(RoutineGenerator.generate(profile, catalog)))
        e.equipment,
    };

    expect(used, {'Mancuernas', 'Bandas elásticas', 'Peso corporal'});
  });

  test('Orden de preferencia: multiarticular primero y después el nivel', () {
    Exercise make(String id, String level, {required bool compound}) =>
        Exercise(
          id: id,
          name: id,
          muscleGroup: 'Pecho',
          equipment: 'Barra',
          level: level,
          isCompound: compound,
        );
    final advancedIsolation = make('a-ais', 'Avanzado', compound: false);
    final beginnerCompound = make('p-mul', 'Principiante', compound: true);
    final advancedCompound = make('a-mul', 'Avanzado', compound: true);
    final beginnerIsolation = make('p-ais', 'Principiante', compound: false);

    final ordered = RoutineGenerator.byPreference([
      advancedIsolation,
      beginnerCompound,
      advancedCompound,
      beginnerIsolation,
    ], planProfile(experience: 'Avanzado'));

    // Un multiarticular de principiante va antes que un aislamiento de
    // avanzado; dentro de cada tipo, primero el nivel del usuario.
    expect(ordered, [
      advancedCompound,
      beginnerCompound,
      advancedIsolation,
      beginnerIsolation,
    ]);
  });

  group('CP-14 Actualizar el plan', () {
    final pushUps = named('Flexiones');
    final dumbbellPress = named('Press banca con mancuernas');
    final splitSquat = named('Sentadilla búlgara');
    final barbellBench = named('Press de banca');

    /// Plan de 4 días (Empuje · Tirón · Pierna · Brazos) con cambios del
    /// usuario: en Empuje ha quitado el press de banca y ha añadido
    /// flexiones y press con mancuernas; en Brazos ha añadido la búlgara.
    TrainingPlan editedPlan(UserProfile profile) {
      final base = RoutineGenerator.generate(profile, catalog);
      PlanExercise custom(Exercise e) =>
          RoutineGenerator.prescribe(e, profile, isCustom: true);
      return TrainingPlan(
        generatedAt: base.generatedAt,
        days: [
          for (final day in base.days)
            switch (day.type) {
              PlanDayType.push => PlanDay(
                weekday: day.weekday,
                type: day.type,
                exercises: [
                  for (final e in day.exercises)
                    if (e.exercise.id != barbellBench.id) e,
                  custom(pushUps),
                  custom(dumbbellPress),
                ],
                removedExerciseIds: [barbellBench.id],
              ),
              PlanDayType.arms => PlanDay(
                weekday: day.weekday,
                type: day.type,
                exercises: [...day.exercises, custom(splitSquat)],
              ),
              _ => day,
            },
        ],
      );
    }

    final fourDays = planProfile();
    final current = editedPlan(fourDays);

    test('Con el mismo perfil no cambia nada ni hay avisos', () {
      final result = RoutineGenerator.update(current, fourDays, catalog);

      expect(result.warnings, isEmpty);
      final push = result.plan.days.first;
      expect(
        namesOf(push),
        containsAll(['Flexiones', 'Press banca con mancuernas']),
      );
      expect(namesOf(push), isNot(contains('Press de banca')));
      expect(namesOf(result.plan.days.last), contains('Sentadilla búlgara'));
    });

    test('Al cambiar los días se mantienen los añadidos y no vuelven '
        'los quitados', () {
      // Otros 4 días de la semana: la estructura es la misma.
      final otherDays = planProfile(trainingDays: [1, 3, 5, 6]);
      final result = RoutineGenerator.update(current, otherDays, catalog);
      final push = dayOn(result.plan, 1);

      expect(result.warnings, isEmpty);
      expect(push.type, PlanDayType.push);
      expect(namesOf(push), contains('Flexiones'));
      expect(namesOf(push), isNot(contains('Press de banca')));
      expect(push.removedExerciseIds, contains(barbellBench.id));
      expect(
        push.exercises.firstWhere((e) => e.exercise.id == pushUps.id).isCustom,
        isTrue,
      );
    });

    test('Si ya no tiene el material, se cambia o se quita con '
        'aviso', () {
      final noDumbbells = planProfile(
        trainingDays: [1, 3, 5],
        equipment: [
          for (final e in ProfileOptions.equipment)
            if (e != 'Mancuernas') e,
        ],
      );
      final result = RoutineGenerator.update(current, noDumbbells, catalog);
      final push = dayOn(result.plan, 1);

      expect(result.warnings, hasLength(2));
      expect(
        result.warnings.first,
        startsWith('Hemos cambiado Press banca con mancuernas por '),
      );
      expect(
        result.warnings.first,
        endsWith('porque ya no tienes mancuernas.'),
      );
      expect(
        result.warnings.last,
        'Hemos quitado Sentadilla búlgara porque ya no tienes mancuernas.',
      );
      // El sustituto no es el press de banca que el usuario había quitado.
      expect(namesOf(push), isNot(contains('Press de banca')));
      expect(namesOf(push), contains('Flexiones'));
      for (final e in allExercises(result.plan)) {
        expect(e.equipment, isNot('Mancuernas'), reason: e.name);
      }
    });

    test('Si su día desaparece, el ejercicio pasa a otro día con '
        'aviso', () {
      // Con 3 días ya no hay día de Brazos.
      final threeDays = planProfile(trainingDays: [1, 3, 5]);
      final result = RoutineGenerator.update(current, threeDays, catalog);

      expect(result.warnings, [
        'Hemos movido Sentadilla búlgara al día de Pierna (miércoles) '
            'porque ya no tienes día de Brazos.',
      ]);
      final legs = dayOn(result.plan, 3);
      expect(legs.type, PlanDayType.legs);
      expect(namesOf(legs), contains('Sentadilla búlgara'));
    });
  });

  group('Cambios del usuario en el plan', () {
    /// Store sin Firebase con un plan de lunes a jueves (Empuje el lunes).
    AppStore storeWithPlan({int sessionMinutes = 60}) {
      final user = planProfile(sessionMinutes: sessionMinutes);
      return AppStore()
        ..exercises.addAll(catalog)
        ..user = user
        ..plan = RoutineGenerator.generate(user, catalog);
    }

    PlanDay monday(AppStore store) =>
        dayOn(store.plan ?? fail('El store no tiene plan'), 1);

    test('Añadir marca el ejercicio como del usuario y no lo repite', () {
      final store = storeWithPlan();
      final pushUps = named('Flexiones');

      expect(store.addPlanExercise(1, pushUps), isNull);
      expect(monday(store).exercises.last.exercise.id, pushUps.id);
      expect(monday(store).exercises.last.isCustom, isTrue);

      expect(
        store.addPlanExercise(1, pushUps),
        'Ese ejercicio ya está en el entreno del día.',
      );
      // El domingo no es de entreno.
      expect(store.addPlanExercise(7, pushUps), 'Ese día no es de entreno.');
    });

    test('Quitar guarda el id y sustituir deja el nuevo en su lugar', () {
      final store = storeWithPlan();
      final first = monday(store).exercises[0].exercise;
      final second = monday(store).exercises[1].exercise;

      store.removePlanExercise(1, first.id);
      expect(monday(store).contains(first.id), isFalse);
      expect(monday(store).removedExerciseIds, [first.id]);

      final pushUps = named('Flexiones');
      store.replacePlanExercise(1, second.id, pushUps);
      final replaced = monday(store).exercises.first;
      expect(replaced.exercise.id, pushUps.id);
      expect(replaced.isCustom, isTrue);
      expect(monday(store).removedExerciseIds, [first.id, second.id]);

      // Si vuelve a añadir uno que había quitado, deja de estar quitado.
      store.addPlanExercise(1, first);
      expect(monday(store).removedExerciseIds, [second.id]);
    });

    test('Sugeridos: los patrones que quedan fuera por los minutos', () {
      final store = storeWithPlan(sessionMinutes: 45);
      final day = monday(store);
      final suggestions = store.planSuggestions(day);

      // Con 45 min, Empuje usa 5 patrones; fuera quedan tríceps y core.
      expect(suggestions, isNotEmpty);
      for (final e in suggestions) {
        expect([
          MovementPattern.triceps,
          MovementPattern.core,
        ], contains(e.pattern));
        expect(day.contains(e.id), isFalse, reason: e.name);
      }

      // Con 90 min no queda ningún patrón fuera.
      final full = storeWithPlan(sessionMinutes: 90);
      expect(full.planSuggestions(monday(full)), isEmpty);
    });

    test('Solo cambian el plan los datos de entrenamiento', () {
      final before = planProfile();
      final renamed = before.copy()..name = 'Otra';
      final reordered = before.copy()
        ..equipment = before.equipment.reversed.toList();
      final moreDays = before.copy()..trainingDays = [1, 2, 3, 4, 5];

      expect(before.sameTrainingAs(renamed), isTrue);
      expect(before.sameTrainingAs(reordered), isTrue);
      expect(before.sameTrainingAs(moreDays), isFalse);
    });

    test('Un plan antiguo se detecta y al actualizarlo sigue las reglas '
        'nuevas sin perder lo del usuario', () {
      final profile = planProfile();
      final bands = catalog.firstWhere(
        (e) => e.equipment == 'Bandas elásticas',
      );
      final pushUps = named('Flexiones');
      // Plan de la versión anterior: con un ejercicio de bandas puesto por
      // el generador y unas flexiones añadidas por el usuario.
      final old = TrainingPlan(
        generatedAt: DateTime(2026, 11, 10),
        days: [
          PlanDay(
            weekday: 1,
            type: PlanDayType.push,
            exercises: [
              RoutineGenerator.prescribe(bands, profile),
              RoutineGenerator.prescribe(pushUps, profile, isCustom: true),
            ],
          ),
        ],
      );
      expect(RoutineGenerator.isOutdated(old), isTrue);

      final updated = RoutineGenerator.update(
        old,
        profile,
        catalog,
        now: RoutineGenerator.rulesDate,
      ).plan;
      expect(RoutineGenerator.isOutdated(updated), isFalse);
      final monday = dayOn(updated, 1);
      expect(monday.contains(bands.id), isFalse);
      expect(monday.contains(pushUps.id), isTrue); // es del usuario
    });
  });
}
