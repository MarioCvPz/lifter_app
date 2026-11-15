import '../models/models.dart';

/// Resultado de actualizar el plan: el plan nuevo y los avisos para el
/// usuario (por ejemplo, "Hemos cambiado Zancadas por Sentadilla goblet
/// porque ya no tienes mancuernas.").
class PlanUpdate {
  const PlanUpdate({required this.plan, required this.warnings});

  final TrainingPlan plan;
  final List<String> warnings;
}

/// Genera el plan semanal de entrenamiento a partir del perfil y del
/// catálogo de ejercicios. Cada regla está en su propio método:
/// estructura → huecos → elegir ejercicio → series y repeticiones → días.
///
/// Es Dart puro (sin Flutter ni Firebase) y no usa nada aleatorio: con el
/// mismo perfil y el mismo catálogo devuelve siempre el mismo plan.
class RoutineGenerator {
  RoutineGenerator._();

  // ------------------------------------------------------------ Tablas --

  /// Tipos de día según cuántos días entrena a la semana.
  static const structures = <int, List<PlanDayType>>{
    2: [PlanDayType.fullBodyA, PlanDayType.fullBodyB],
    3: [PlanDayType.push, PlanDayType.legs, PlanDayType.pull],
    4: [PlanDayType.push, PlanDayType.pull, PlanDayType.legs, PlanDayType.arms],
    5: [
      PlanDayType.push,
      PlanDayType.pull,
      PlanDayType.legs,
      PlanDayType.upper,
      PlanDayType.legsB,
    ],
    6: [
      PlanDayType.push,
      PlanDayType.pull,
      PlanDayType.legs,
      PlanDayType.push,
      PlanDayType.pull,
      PlanDayType.legsB,
    ],
  };

  /// Excepción: un principiante con 3 días hace tres full body.
  static const beginnerThreeDays = [
    PlanDayType.fullBodyA,
    PlanDayType.fullBodyB,
    PlanDayType.fullBodyC,
  ];

  /// Patrones de cada tipo de día, por orden de prioridad. Se usan los
  /// primeros según los minutos de la sesión ([slotsByMinutes]).
  static const dayPatterns = <PlanDayType, List<MovementPattern>>{
    PlanDayType.fullBodyA: [
      MovementPattern.squat,
      MovementPattern.horizontalPush,
      MovementPattern.verticalPull,
      MovementPattern.hinge,
      MovementPattern.lateralDelt,
      MovementPattern.core,
      MovementPattern.biceps,
      MovementPattern.triceps,
    ],
    PlanDayType.fullBodyB: [
      MovementPattern.hinge,
      MovementPattern.verticalPush,
      MovementPattern.horizontalPull,
      MovementPattern.unilateral,
      MovementPattern.chestIsolation,
      MovementPattern.core,
      MovementPattern.triceps,
      MovementPattern.biceps,
    ],
    PlanDayType.fullBodyC: [
      MovementPattern.squat,
      MovementPattern.horizontalPull,
      MovementPattern.horizontalPush,
      MovementPattern.glute,
      MovementPattern.rearDelt,
      MovementPattern.core,
      MovementPattern.hamstringIsolation,
      MovementPattern.biceps,
    ],
    PlanDayType.push: [
      MovementPattern.horizontalPush,
      MovementPattern.horizontalPush,
      MovementPattern.verticalPush,
      MovementPattern.chestIsolation,
      MovementPattern.lateralDelt,
      MovementPattern.triceps,
      MovementPattern.triceps,
      MovementPattern.core,
    ],
    PlanDayType.pull: [
      MovementPattern.verticalPull,
      MovementPattern.horizontalPull,
      MovementPattern.horizontalPull,
      MovementPattern.verticalPull,
      MovementPattern.rearDelt,
      MovementPattern.biceps,
      MovementPattern.biceps,
      MovementPattern.core,
    ],
    PlanDayType.legs: [
      MovementPattern.squat,
      MovementPattern.hinge,
      MovementPattern.unilateral,
      MovementPattern.quadIsolation,
      MovementPattern.hamstringIsolation,
      MovementPattern.calf,
      MovementPattern.core,
      MovementPattern.glute,
    ],
    PlanDayType.legsB: [
      MovementPattern.hinge,
      MovementPattern.squat,
      MovementPattern.glute,
      MovementPattern.hamstringIsolation,
      MovementPattern.unilateral,
      MovementPattern.calf,
      MovementPattern.core,
      MovementPattern.quadIsolation,
    ],
    PlanDayType.upper: [
      MovementPattern.horizontalPush,
      MovementPattern.horizontalPull,
      MovementPattern.verticalPush,
      MovementPattern.verticalPull,
      MovementPattern.lateralDelt,
      MovementPattern.biceps,
      MovementPattern.triceps,
      MovementPattern.chestIsolation,
    ],
    PlanDayType.arms: [
      MovementPattern.biceps,
      MovementPattern.triceps,
      MovementPattern.biceps,
      MovementPattern.triceps,
      MovementPattern.lateralDelt,
      MovementPattern.rearDelt,
      MovementPattern.biceps,
      MovementPattern.core,
    ],
  };

  /// Ejercicios por día según los minutos de la sesión.
  static const slotsByMinutes = <int, int>{45: 5, 60: 6, 90: 8};

  // Repeticiones (mínimo y máximo). Un record `(min: 4, max: 6)` es como
  // un pequeño objeto inmutable con dos campos, parecido a un record de
  // Java.
  static const strengthReps = (min: 4, max: 6);
  static const hypertrophyReps = (min: 8, max: 12);
  static const enduranceReps = (min: 10, max: 15);

  // Descanso entre series, en segundos.
  static const strengthRest = 150;
  static const hypertrophyRest = 90;
  static const enduranceRest = 60;

  // Series.
  static const beginnerSets = 3;
  static const compoundSets = 4;
  static const isolationSets = 3;

  /// Palabra del nombre que distingue un press inclinado de uno plano.
  static const inclineWord = 'inclinado';

  // Preferencia de material en el gimnasio: primero el de gimnasio; el peso
  // corporal solo si no hay ninguno de esos para el hueco; las bandas
  // elásticas, nunca.
  static const gymEquipment = [
    'Barra',
    'Mancuernas',
    'Máquinas',
    'Polea',
    'Barra de dominadas',
  ];
  static const bodyweightEquipment = 'Peso corporal';

  /// Desde cuándo valen las reglas actuales. Un plan generado antes es de
  /// una versión anterior del generador y se actualiza la próxima vez que
  /// el usuario guarde sus ajustes. Es el día siguiente al cambio para que
  /// también cuenten como antiguos los planes creados ese mismo día con las
  /// reglas anteriores. Si se cambian las reglas, hay que mover esta fecha.
  static final rulesDate = DateTime(2026, 11, 12);

  /// True si [plan] se generó con una versión anterior de las reglas.
  static bool isOutdated(TrainingPlan plan) =>
      plan.generatedAt.isBefore(rulesDate);

  // -------------------------------------------------------- Generador --

  /// Plan completo para [profile] con los ejercicios de [catalog].
  /// [now] permite fijar la fecha en los tests.
  static TrainingPlan generate(
    UserProfile profile,
    List<Exercise> catalog, {
    DateTime? now,
  }) {
    final types = structure(profile);
    final weekdays = trainingWeekdays(profile);
    // Ejercicios ya usados en cada tipo de día, para no repetirlos si ese
    // tipo sale dos veces en la semana.
    final usedByType = <PlanDayType, Set<String>>{};
    final days = <PlanDay>[];

    for (var i = 0; i < types.length && i < weekdays.length; i++) {
      final type = types[i];
      final usedInWeek = usedByType.putIfAbsent(type, () => {});
      final exercises = buildDay(type, profile, catalog, usedInWeek);
      usedInWeek.addAll([for (final e in exercises) e.id]);
      days.add(
        PlanDay(
          weekday: weekdays[i],
          type: type,
          exercises: [for (final e in exercises) prescribe(e, profile)],
        ),
      );
    }
    return TrainingPlan(generatedAt: now ?? DateTime.now(), days: days);
  }

  // ----------------------------------------------------------- Reglas --

  /// Regla 1: tipos de día según el número de días elegidos (de 2 a 6).
  static List<PlanDayType> structure(UserProfile profile) {
    final days = profile.trainingDays.length.clamp(2, 6);
    if (days == 3 && profile.experience == Routine.levels.first) {
      return beginnerThreeDays;
    }
    // Siempre existe: [days] está entre 2 y 6, que son las claves.
    return structures[days] ?? const [];
  }

  /// Regla 5: días de la semana del usuario, de lunes a domingo. El primer
  /// tipo de día va al primero de estos días, y así sucesivamente.
  static List<int> trainingWeekdays(UserProfile profile) {
    return {...profile.trainingDays}.toList()..sort();
  }

  /// Regla 2: cuántos ejercicios caben según los minutos. Se usa la fila
  /// más alta que no pase de los minutos (30 min cuenta como 45).
  static int slotCount(int minutes) {
    var count = slotsByMinutes.values.first;
    for (final entry in slotsByMinutes.entries) {
      if (minutes >= entry.key) count = entry.value;
    }
    return count;
  }

  /// Regla 2: patrones de un día, recortados según los minutos.
  static List<MovementPattern> slots(PlanDayType type, int minutes) {
    final patterns = dayPatterns[type] ?? const <MovementPattern>[];
    return patterns.take(slotCount(minutes)).toList();
  }

  /// Ejercicios de un día: rellena cada hueco y pone los multiarticulares
  /// antes que los de aislamiento.
  static List<Exercise> buildDay(
    PlanDayType type,
    UserProfile profile,
    List<Exercise> catalog,
    Set<String> usedInWeek,
  ) {
    final chosen = <Exercise>[];
    MovementPattern? lastPattern;
    Exercise? lastPick;

    for (final pattern in slots(type, profile.sessionMinutes)) {
      // Dos huecos seguidos de empuje horizontal: uno plano y otro
      // inclinado si se puede.
      final pairedWith =
          pattern == MovementPattern.horizontalPush && pattern == lastPattern
          ? lastPick
          : null;
      final pick = pickExercise(
        pattern,
        profile,
        catalog,
        usedToday: {for (final e in chosen) e.id},
        usedInWeek: usedInWeek,
        pairedWith: pairedWith,
      );
      lastPattern = pattern;
      lastPick = pick;
      if (pick != null) chosen.add(pick); // sin candidato, se salta
    }
    return compoundsFirst(chosen);
  }

  /// Regla 3: elige el ejercicio de un hueco, o null si no hay ninguno.
  /// Primero busca respetando el nivel; si no hay nada, lo ignora. El
  /// material y las lesiones nunca se ignoran. Entre los candidatos
  /// prefiere, por este orden:
  /// 1. uno no usado en el otro día del mismo tipo y que varíe el ángulo
  ///    respecto a [pairedWith] (plano/inclinado);
  /// 2. uno no usado en el otro día del mismo tipo;
  /// 3. uno que varíe el ángulo;
  /// 4. el primero de la lista.
  static Exercise? pickExercise(
    MovementPattern pattern,
    UserProfile profile,
    List<Exercise> catalog, {
    Set<String> usedToday = const {},
    Set<String> usedInWeek = const {},
    Exercise? pairedWith,
  }) {
    var options = candidates(pattern, profile, catalog, exclude: usedToday);
    if (options.isEmpty) {
      options = candidates(
        pattern,
        profile,
        catalog,
        exclude: usedToday,
        ignoreLevel: true,
      );
    }
    if (options.isEmpty) return null;

    bool newThisWeek(Exercise e) => !usedInWeek.contains(e.id);
    bool variesAngle(Exercise e) =>
        pairedWith == null || isIncline(e) != isIncline(pairedWith);

    return _firstWhere(options, (e) => newThisWeek(e) && variesAngle(e)) ??
        _firstWhere(options, newThisWeek) ??
        _firstWhere(options, variesAngle) ??
        options.first;
  }

  /// Ejercicios del catálogo de ese patrón que el usuario puede hacer, sin
  /// los de [exclude], ordenados por preferencia:
  /// 1. filtros obligatorios: material, lesiones y (si no se ignora) nivel;
  /// 2. material propio del lugar ([preferPlaceEquipment]);
  /// 3. orden por tipo y nivel ([byPreference]).
  static List<Exercise> candidates(
    MovementPattern pattern,
    UserProfile profile,
    List<Exercise> catalog, {
    Set<String> exclude = const {},
    bool ignoreLevel = false,
  }) {
    final valid = [
      for (final e in catalog)
        if (e.pattern == pattern &&
            !exclude.contains(e.id) &&
            isDoable(e, profile) &&
            (ignoreLevel || levelAllowed(e, profile)))
          e,
    ];
    return byPreference(preferPlaceEquipment(valid, profile), profile);
  }

  /// En el gimnasio, se queda con los ejercicios de [gymEquipment]; si no
  /// hay ninguno, con los de peso corporal; las bandas nunca entran. En casa
  /// y al aire libre no cambia nada.
  static List<Exercise> preferPlaceEquipment(
    List<Exercise> valid,
    UserProfile profile,
  ) {
    if (profile.trainingPlace != TrainingPlace.gym) return valid;
    final gym = [
      for (final e in valid)
        if (gymEquipment.contains(e.equipment)) e,
    ];
    if (gym.isNotEmpty) return gym;
    return [
      for (final e in valid)
        if (e.equipment == bodyweightEquipment) e,
    ];
  }

  /// Ordena los candidatos: primero los multiarticulares y después los de
  /// aislamiento. Dentro de cada grupo, por nivel ([byLevel]). Así, en un
  /// hueco con multiarticulares, un avanzado recibe primero un
  /// multiarticular de avanzado.
  static List<Exercise> byPreference(
    List<Exercise> exercises,
    UserProfile profile,
  ) => [
    ...byLevel(exercises.where((e) => e.isCompound), profile),
    ...byLevel(exercises.where((e) => !e.isCompound), profile),
  ];

  /// Primero los del mismo nivel que el usuario, luego los de nivel
  /// inferior (y, solo si se ignoró el nivel, los de nivel superior).
  /// Dentro de cada nivel, en el orden del catálogo. Se agrupa a mano en
  /// vez de usar `sort` porque `sort` no garantiza mantener ese orden.
  static List<Exercise> byLevel(
    Iterable<Exercise> exercises,
    UserProfile profile,
  ) {
    final ranks = {for (final e in exercises) levelRank(e, profile)}.toList()
      ..sort();
    return [
      for (final rank in ranks)
        for (final e in exercises)
          if (levelRank(e, profile) == rank) e,
    ];
  }

  /// Cuánto se aleja el nivel del ejercicio del del usuario: 0 = el mismo,
  /// 1 = un nivel por debajo, 2 = dos por debajo. Los de nivel superior van
  /// después de todos los inferiores.
  static int levelRank(Exercise exercise, UserProfile profile) {
    final below = _userLevel(profile) - Routine.levels.indexOf(exercise.level);
    return below >= 0 ? below : Routine.levels.length - below;
  }

  /// True si el usuario tiene el material y el ejercicio no carga ninguna
  /// de sus zonas lesionadas. Estas dos condiciones nunca se ignoran.
  static bool isDoable(Exercise exercise, UserProfile profile) =>
      whyNotDoable(exercise, profile) == null;

  /// Motivo por el que el usuario no puede hacer el ejercicio, para los
  /// avisos ("porque ya no tienes mancuernas"), o null si sí puede.
  static String? whyNotDoable(Exercise exercise, UserProfile profile) {
    if (!profile.equipment.contains(exercise.equipment)) {
      return 'porque ya no tienes ${exercise.equipment.toLowerCase()}';
    }
    for (final zone in exercise.stressedZones) {
      if (profile.injuries.contains(zone)) {
        return 'porque carga una zona lesionada (${zone.toLowerCase()})';
      }
    }
    return null;
  }

  /// True si el nivel del ejercicio no supera el del usuario
  /// (principiante → solo principiante; avanzado → todos).
  static bool levelAllowed(Exercise exercise, UserProfile profile) =>
      Routine.levels.indexOf(exercise.level) <= _userLevel(profile);

  /// Posición del nivel del usuario en [Routine.levels] (0 = principiante).
  /// Si la experiencia es desconocida, intermedio, el valor por defecto del
  /// perfil.
  static int _userLevel(UserProfile profile) {
    final index = Routine.levels.indexOf(profile.experience);
    return index < 0 ? 1 : index;
  }

  /// True si es un press inclinado (lo dice su nombre).
  static bool isIncline(Exercise exercise) =>
      exercise.name.toLowerCase().contains(inclineWord);

  /// Los multiarticulares delante, sin cambiar el orden dentro de cada
  /// grupo.
  static List<Exercise> compoundsFirst(List<Exercise> exercises) => [
    ...exercises.where((e) => e.isCompound),
    ...exercises.where((e) => !e.isCompound),
  ];

  /// Regla 4: series, repeticiones y descanso según objetivo y nivel.
  static PlanExercise prescribe(
    Exercise exercise,
    UserProfile profile, {
    bool isCustom = false,
  }) {
    final reps = repRange(profile.goal, exercise.isCompound);
    return PlanExercise(
      exercise: exercise,
      sets: setsFor(exercise, profile),
      minReps: reps.min,
      maxReps: reps.max,
      restSeconds: restFor(profile.goal),
      isCustom: isCustom,
    );
  }

  /// Repeticiones según el objetivo. En fuerza, los de aislamiento usan el
  /// rango de hipertrofia.
  static ({int min, int max}) repRange(TrainingGoal goal, bool isCompound) {
    return switch (goal) {
      TrainingGoal.strength => isCompound ? strengthReps : hypertrophyReps,
      TrainingGoal.muscleGain ||
      TrainingGoal.bodyRecomposition => hypertrophyReps,
      TrainingGoal.fatLoss || TrainingGoal.generalHealth => enduranceReps,
    };
  }

  /// Descanso entre series según el objetivo.
  static int restFor(TrainingGoal goal) {
    return switch (goal) {
      TrainingGoal.strength => strengthRest,
      TrainingGoal.muscleGain ||
      TrainingGoal.bodyRecomposition => hypertrophyRest,
      TrainingGoal.fatLoss || TrainingGoal.generalHealth => enduranceRest,
    };
  }

  /// Series: 3 para principiante; si no, 4 en multiarticulares y 3 en
  /// aislamiento.
  static int setsFor(Exercise exercise, UserProfile profile) {
    if (profile.experience == Routine.levels.first) return beginnerSets;
    return exercise.isCompound ? compoundSets : isolationSets;
  }

  // ---------------------------------------- Actualizar el plan (paso 3) --

  /// Plan nuevo para [profile] que respeta los cambios que el usuario hizo
  /// en [current]:
  /// 1. Se genera el plan base con el perfil nuevo.
  /// 2. Cada día antiguo pasa sus cambios al día nuevo del mismo tipo
  ///    (Empuje → Empuje): se quitan los ejercicios que había quitado y se
  ///    vuelven a poner los que había añadido o sustituido (`isCustom`).
  /// 3. Excepción 1: si un ejercicio del usuario ya no se puede hacer, se
  ///    cambia por otro del mismo patrón (o se quita si no hay ninguno).
  /// 4. Excepción 2: si su tipo de día ya no existe, el ejercicio pasa al
  ///    primer día de la semana que tenga su patrón.
  /// Devuelve el plan y los avisos en español para el usuario.
  static PlanUpdate update(
    TrainingPlan current,
    UserProfile profile,
    List<Exercise> catalog, {
    DateTime? now,
  }) {
    final base = generate(profile, catalog, now: now);
    // Copias que se pueden modificar: un PlanDay es inmutable.
    final exercisesByDay = [
      for (final d in base.days) [...d.exercises],
    ];
    final removedByDay = List.generate(base.days.length, (_) => <String>{});
    final warnings = <String>[];

    for (final (oldIndex, oldDay) in current.days.indexed) {
      final target = _sameTypeDay(base, current, oldIndex);
      if (target != null) {
        // Lo que había quitado no vuelve.
        removedByDay[target].addAll(oldDay.removedExerciseIds);
        exercisesByDay[target].removeWhere(
          (e) => oldDay.removedExerciseIds.contains(e.exercise.id),
        );
      }
      for (final custom in oldDay.exercises.where((e) => e.isCustom)) {
        final exercise = custom.exercise;
        // Su día del mismo tipo o, si ya no existe, el primero con su
        // patrón (excepción 2).
        final day = target ?? _dayWithPattern(base, exercise.pattern);
        if (day == null) {
          warnings.add(
            'Hemos quitado ${exercise.name} porque ya no tienes día de '
            '${oldDay.name}.',
          );
          continue;
        }
        final kept = _keepCustom(
          exercise,
          profile,
          catalog,
          // No se elige un sustituto que ya esté en el día ni uno que el
          // usuario haya quitado.
          {
            for (final e in exercisesByDay[day]) e.exercise.id,
            ...removedByDay[day],
          },
          warnings,
        );
        if (kept == null) continue;
        if (target == null) {
          warnings.add(
            'Hemos movido ${kept.name} al ${_dayLabel(base.days[day])} '
            'porque ya no tienes día de ${oldDay.name}.',
          );
        }
        _addCustom(exercisesByDay[day], kept, profile);
      }
    }

    final days = [
      for (final (i, d) in base.days.indexed)
        PlanDay(
          weekday: d.weekday,
          type: d.type,
          exercises: _compoundsFirstInPlan(exercisesByDay[i]),
          removedExerciseIds: removedByDay[i].toList(),
        ),
    ];
    return PlanUpdate(
      plan: TrainingPlan(generatedAt: base.generatedAt, days: days),
      warnings: warnings,
    );
  }

  /// Índice del día de [base] que corresponde al día [oldIndex] de [old]:
  /// el del mismo tipo y la misma vez en la semana (el segundo Empuje con
  /// el segundo Empuje). Si ya no hay tantos, el primero de ese tipo. Null
  /// si el tipo ha desaparecido.
  static int? _sameTypeDay(TrainingPlan base, TrainingPlan old, int oldIndex) {
    final type = old.days[oldIndex].type;
    final occurrence = old.days
        .take(oldIndex)
        .where((d) => d.type == type)
        .length;
    final sameType = [
      for (final (i, d) in base.days.indexed)
        if (d.type == type) i,
    ];
    if (sameType.isEmpty) return null;
    return occurrence < sameType.length ? sameType[occurrence] : sameType.first;
  }

  /// Índice del primer día de la semana cuya lista de patrones incluye
  /// [pattern], o null si ninguno.
  static int? _dayWithPattern(TrainingPlan plan, MovementPattern pattern) {
    for (final (i, d) in plan.days.indexed) {
      final patterns = dayPatterns[d.type] ?? const <MovementPattern>[];
      if (patterns.contains(pattern)) return i;
    }
    return null;
  }

  /// El ejercicio del usuario si aún lo puede hacer (excepción 1). Si no,
  /// otro del mismo patrón que sí pueda y no esté en [exclude] (con
  /// aviso), o null si no hay ninguno (con aviso).
  static Exercise? _keepCustom(
    Exercise exercise,
    UserProfile profile,
    List<Exercise> catalog,
    Set<String> exclude,
    List<String> warnings,
  ) {
    final reason = whyNotDoable(exercise, profile);
    if (reason == null) return exercise;
    final replacement = pickExercise(
      exercise.pattern,
      profile,
      catalog,
      usedToday: exclude,
    );
    warnings.add(
      replacement == null
          ? 'Hemos quitado ${exercise.name} $reason.'
          : 'Hemos cambiado ${exercise.name} por ${replacement.name} $reason.',
    );
    return replacement;
  }

  /// Añade un ejercicio del usuario al día. Si el generador ya lo había
  /// puesto, solo lo marca como del usuario para no repetirlo.
  static void _addCustom(
    List<PlanExercise> dayExercises,
    Exercise exercise,
    UserProfile profile,
  ) {
    dayExercises.removeWhere((e) => e.exercise.id == exercise.id);
    dayExercises.add(prescribe(exercise, profile, isCustom: true));
  }

  static List<PlanExercise> _compoundsFirstInPlan(List<PlanExercise> list) => [
    ...list.where((e) => e.exercise.isCompound),
    ...list.where((e) => !e.exercise.isCompound),
  ];

  /// "día de Pierna (miércoles)".
  static String _dayLabel(PlanDay day) =>
      'día de ${day.name} (${day.weekdayName.toLowerCase()})';

  // ------------------------------------------ Sugeridos (paso 5) --

  /// "Sugeridos para este día": los ejercicios de los patrones del día que
  /// quedaron fuera por los minutos (por ejemplo, con 45 min un día de
  /// Empuje usa 5 de sus 8 patrones; aquí salen los de los 3 restantes).
  /// Se filtran por material, nivel y lesiones, y no incluyen los que ya
  /// están en el día ni los que el usuario quitó. Con 90 min no queda
  /// ningún patrón fuera y la lista está vacía.
  static List<Exercise> suggestionsFor(
    PlanDay day,
    UserProfile profile,
    List<Exercise> catalog,
  ) {
    final patterns = dayPatterns[day.type] ?? const <MovementPattern>[];
    final leftOut = patterns.skip(slotCount(profile.sessionMinutes)).toSet();
    final exclude = {
      for (final e in day.exercises) e.exercise.id,
      ...day.removedExerciseIds,
    };
    return [
      for (final pattern in leftOut)
        ...candidates(pattern, profile, catalog, exclude: exclude),
    ];
  }

  /// Primer elemento que cumple [test], o null si ninguno.
  static Exercise? _firstWhere(
    List<Exercise> list,
    bool Function(Exercise) test,
  ) {
    for (final e in list) {
      if (test(e)) return e;
    }
    return null;
  }
}
