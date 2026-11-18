import 'package:cloud_firestore/cloud_firestore.dart';

/// Patrón de movimiento de un ejercicio. Lo usará el generador de rutinas
/// para repartir los ejercicios. En Firestore y en el JSON se guarda [key]
/// (en español, como viene en `assets/seed/catalog.json`).
enum MovementPattern {
  horizontalPush('empuje_horizontal', 'Empuje horizontal'),
  verticalPush('empuje_vertical', 'Empuje vertical'),
  horizontalPull('tiron_horizontal', 'Tirón horizontal'),
  verticalPull('tiron_vertical', 'Tirón vertical'),
  squat('sentadilla', 'Sentadilla'),
  hinge('bisagra', 'Bisagra de cadera'),
  unilateral('unilateral', 'Unilateral'),
  glute('gluteo', 'Glúteo'),
  chestIsolation('pecho_aislamiento', 'Pecho (aislamiento)'),
  lateralDelt('hombro_lateral', 'Hombro lateral'),
  rearDelt('hombro_posterior', 'Hombro posterior'),
  biceps('biceps', 'Bíceps'),
  triceps('triceps', 'Tríceps'),
  quadIsolation('cuadriceps_aislamiento', 'Cuádriceps (aislamiento)'),
  hamstringIsolation('femoral_aislamiento', 'Femoral (aislamiento)'),
  calf('gemelo', 'Gemelo'),
  core('core', 'Core'),

  /// Para las copias antiguas de ejercicios, que no tienen patrón.
  other('otro', 'Otro');

  const MovementPattern(this.key, this.label);
  final String key;
  final String label;

  /// Busca por [key] (o por el nombre del enum); si no existe, "otro".
  static MovementPattern fromName(String? name) {
    return MovementPattern.values.firstWhere(
      (p) => p.key == name || p.name == name,
      orElse: () => MovementPattern.other,
    );
  }
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.level,
    this.pattern = MovementPattern.other,
    this.isCompound = false,
    this.stressedZones = const [],
  });

  /// Valores del campo `type` en Firestore y en el JSON.
  static const compoundType = 'multiarticular';
  static const isolationType = 'aislamiento';

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String level;
  final MovementPattern pattern;

  /// True si es multiarticular (mueve varias articulaciones, como la
  /// sentadilla); false si es de aislamiento (como el curl de bíceps).
  final bool isCompound;

  /// Zonas que carga el ejercicio, con los nombres de
  /// [ProfileOptions.injuries], para poder evitarlo si hay una lesión.
  final List<String> stressedZones;

  /// Los entrenos, rutinas y plantillas guardan copias antiguas de los
  /// ejercicios sin `pattern`, `type` ni `stressedZones`: se leen con
  /// valores por defecto (patrón "otro", aislamiento y sin zonas).
  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
    id: m['id'] as String,
    name: m['name'] as String,
    muscleGroup: m['muscleGroup'] as String,
    equipment: m['equipment'] as String,
    level: m['level'] as String,
    pattern: MovementPattern.fromName(m['pattern'] as String?),
    isCompound: m['type'] == compoundType,
    stressedZones: [
      for (final zone in m['stressedZones'] as List? ?? const [])
        ProfileOptions.injuryNamed(zone as String),
    ],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'level': level,
    'pattern': pattern.key,
    'type': isCompound ? compoundType : isolationType,
    'stressedZones': stressedZones,
  };

  // Los ejercicios llegan de Firestore y se recrean en cada lectura, así que
  // se comparan por id (p. ej. para saber si ya está elegido en un editor).
  @override
  bool operator ==(Object other) => other is Exercise && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class WorkoutSet {
  const WorkoutSet({required this.reps, required this.weightKg});

  final int reps;
  final double weightKg;

  factory WorkoutSet.fromMap(Map<String, dynamic> m) => WorkoutSet(
    reps: (m['reps'] as num).toInt(),
    weightKg: (m['weightKg'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {'reps': reps, 'weightKg': weightKg};
}

class WorkoutExercise {
  const WorkoutExercise({
    required this.exercise,
    required this.sets,
    this.comment,
  });

  final Exercise exercise;
  final List<WorkoutSet> sets;

  /// Comentario del usuario sobre este ejercicio en este entreno (por
  /// ejemplo, "Molestia en el hombro en la última serie"). Lo ve también
  /// su entrenador. Null si no escribió nada.
  final String? comment;

  /// Los entrenos antiguos no tienen `comment`: se leen con null.
  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
    exercise: Exercise.fromMap(Map<String, dynamic>.from(m['exercise'])),
    sets: [
      for (final s in m['sets'] as List)
        WorkoutSet.fromMap(Map<String, dynamic>.from(s)),
    ],
    comment: m['comment'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'exercise': exercise.toMap(),
    'sets': [for (final s in sets) s.toMap()],
    // Solo se guarda si hay comentario, como `routineId` en Workout.
    'comment': ?comment,
  };
}

class Workout {
  /// Minutos que se cuentan por ejercicio cuando no se indica la duración.
  static const minutesPerExercise = 5;

  const Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.durationMin,
    required this.exercises,
    this.routineId,
  });

  final String id;
  final String name;
  final DateTime date;
  final int durationMin;
  final List<WorkoutExercise> exercises;

  /// Rutina de la que salió este entreno, si salió de una.
  final String? routineId;

  /// Volumen total: suma de reps × kg de todas las series.
  double get volumeKg => exercises.fold(
    0,
    (total, ex) =>
        total + ex.sets.fold(0, (s, set) => s + set.reps * set.weightKg),
  );

  factory Workout.fromMap(String id, Map<String, dynamic> m) => Workout(
    id: id,
    routineId: m['routineId'] as String?,
    name: m['name'] as String,
    date: (m['date'] as Timestamp).toDate(),
    durationMin: (m['durationMin'] as num).toInt(),
    exercises: [
      for (final e in m['exercises'] as List)
        WorkoutExercise.fromMap(Map<String, dynamic>.from(e)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'date': Timestamp.fromDate(date),
    'durationMin': durationMin,
    'exercises': [for (final e in exercises) e.toMap()],
    'routineId': ?routineId,
  };
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.description,
    required this.templateName,
    required this.exercises,
    this.isTemplate = false,
    this.recommendedDays,
  });

  final String id;
  final String name;
  final String description;
  final String templateName;
  final List<Exercise> exercises;
  final bool isTemplate;

  /// Solo plantillas: días por semana para los que se recomienda.
  final int? recommendedDays;

  static const levels = ['Principiante', 'Intermedio', 'Avanzado'];

  /// Nivel de la rutina: el del ejercicio más exigente.
  String get level {
    var max = 0;
    for (final e in exercises) {
      final i = levels.indexOf(e.level);
      if (i > max) max = i;
    }
    return levels[max];
  }

  List<String> get muscleGroups =>
      {for (final e in exercises) e.muscleGroup}.toList();

  /// Estimación: los mismos minutos por ejercicio que un entreno sin duración.
  int get estimatedMin => exercises.length * Workout.minutesPerExercise;

  factory Routine.fromMap(
    String id,
    Map<String, dynamic> m, {
    bool isTemplate = false,
  }) => Routine(
    id: id,
    name: m['name'] as String,
    description: m['description'] as String? ?? '',
    templateName: m['templateName'] as String? ?? 'Personal',
    isTemplate: isTemplate,
    recommendedDays: (m['recommendedDays'] as num?)?.toInt(),
    exercises: [
      for (final e in m['exercises'] as List)
        Exercise.fromMap(Map<String, dynamic>.from(e)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'description': description,
    'templateName': templateName,
    'exercises': [for (final e in exercises) e.toMap()],
    'recommendedDays': ?recommendedDays,
    'createdAt': Timestamp.now(),
  };
}

/// Tipo de alimento. Sirve para filtrar el catálogo de nutrición. En
/// Firestore se guarda [name] (por ejemplo `"meat"`), como en [UserRole].
enum FoodCategory {
  meat('Carnes'),
  fish('Pescados y mariscos'),
  eggsDairy('Huevos y lácteos'),
  grains('Cereales y tubérculos'),
  legumes('Legumbres'),
  vegetables('Verduras'),
  fruits('Frutas'),
  nuts('Frutos secos y semillas'),
  fats('Aceites y grasas'),
  drinks('Bebidas'),
  sweets('Dulces y snacks'),
  supplements('Suplementos'),
  other('Otros');

  const FoodCategory(this.label);
  final String label;

  /// Los alimentos antiguos no tienen categoría: se tratan como [other].
  static FoodCategory fromName(String? name) {
    return FoodCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => FoodCategory.other,
    );
  }
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
    this.category = FoodCategory.other,
  });

  final String id;
  final String name;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;
  final FoodCategory category;

  factory Food.fromMap(Map<String, dynamic> m) => Food(
    id: m['id'] as String,
    name: m['name'] as String,
    kcalPer100: (m['kcalPer100'] as num).toDouble(),
    proteinPer100: (m['proteinPer100'] as num).toDouble(),
    carbsPer100: (m['carbsPer100'] as num).toDouble(),
    fatPer100: (m['fatPer100'] as num).toDouble(),
    category: FoodCategory.fromName(m['category'] as String?),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'category': category.name,
    'kcalPer100': kcalPer100,
    'proteinPer100': proteinPer100,
    'carbsPer100': carbsPer100,
    'fatPer100': fatPer100,
  };
}

class NutritionEntry {
  const NutritionEntry({
    required this.id,
    required this.food,
    required this.grams,
    required this.date,
  });

  final String id;
  final Food food;
  final double grams;
  final DateTime date;

  factory NutritionEntry.fromMap(String id, Map<String, dynamic> m) =>
      NutritionEntry(
        id: id,
        food: Food.fromMap(Map<String, dynamic>.from(m['food'])),
        grams: (m['grams'] as num).toDouble(),
        date: (m['date'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
    'food': food.toMap(),
    'grams': grams,
    'date': Timestamp.fromDate(date),
  };

  double get kcal => food.kcalPer100 * grams / 100;
  double get protein => food.proteinPer100 * grams / 100;
  double get carbs => food.carbsPer100 * grams / 100;
  double get fat => food.fatPer100 * grams / 100;
}

/// Id del documento de un registro diario (agua, peso, pasos): la fecha en
/// formato aaaa-mm-dd, por ejemplo "2026-11-17". Como hay un documento por
/// día, registrar dos veces el mismo día sobrescribe el anterior.
String dayKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Días hacia atrás en los que se puede registrar el peso o los pasos.
const maxLogDaysBack = 365;

/// Mensaje de error si no se puede registrar un peso o unos pasos en [day]
/// (un día futuro o de hace más de [maxLogDaysBack] días), o null si sí.
/// [now] es la fecha de hoy (se pasa para poder probarlo).
String? validateLogDay(DateTime day, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(day.year, day.month, day.day);
  if (date.isAfter(today)) return 'No puedes registrar días futuros.';
  final oldest = DateTime(today.year, today.month, today.day - maxLogDaysBack);
  if (date.isBefore(oldest)) {
    return 'Solo puedes registrar hasta hace un año.';
  }
  return null;
}

/// Peso corporal de un día (`users/{uid}/weights/{aaaa-mm-dd}`).
class WeightEntry {
  const WeightEntry({required this.date, required this.kg});

  /// Límites razonables para el peso de una persona adulta.
  static const minKg = 30.0;
  static const maxKg = 250.0;

  /// Día del registro, a las 00:00.
  final DateTime date;
  final double kg;

  /// Mensaje de error si [kg] no es válido, o null si lo es.
  static String? validate(double? kg) {
    if (kg == null) return 'Escribe tu peso en kg.';
    if (kg < minKg || kg > maxKg) {
      return 'El peso tiene que estar entre ${minKg.round()} y '
          '${maxKg.round()} kg.';
    }
    return null;
  }

  factory WeightEntry.fromMap(Map<String, dynamic> m) => WeightEntry(
    date: (m['date'] as Timestamp).toDate(),
    kg: (m['kg'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap() => {'date': Timestamp.fromDate(date), 'kg': kg};
}

/// Pasos de un día (`users/{uid}/steps/{aaaa-mm-dd}`).
class StepsEntry {
  const StepsEntry({required this.date, required this.steps});

  static const minSteps = 0;
  static const maxSteps = 100000;

  /// Día del registro, a las 00:00.
  final DateTime date;
  final int steps;

  /// Mensaje de error si [steps] no es válido, o null si lo es.
  static String? validate(int? steps) {
    if (steps == null) return 'Escribe los pasos (un número entero).';
    if (steps < minSteps || steps > maxSteps) {
      return 'Los pasos tienen que estar entre $minSteps y 100.000.';
    }
    return null;
  }

  factory StepsEntry.fromMap(Map<String, dynamic> m) => StepsEntry(
    date: (m['date'] as Timestamp).toDate(),
    steps: (m['steps'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'date': Timestamp.fromDate(date),
    'steps': steps,
  };
}

enum UserRole {
  user('Usuario'),
  trainer('Entrenador'),
  admin('Admin');

  const UserRole(this.label);
  final String label;

  static UserRole fromName(String? name) {
    return UserRole.values.firstWhere(
      (r) => r.name == name,
      orElse: () => UserRole.user,
    );
  }
}

/// Opciones compartidas por el cuestionario y la edición del perfil.
class ProfileOptions {
  /// Solo dos opciones porque la fórmula de calorías depende del sexo.
  static const sexes = ['Hombre', 'Mujer'];

  /// Explicación de cada nivel de [Routine.levels], en el mismo orden.
  static const experienceDescriptions = [
    'Menos de 6 meses entrenando',
    'De 6 meses a 2 años',
    'Más de 2 años',
  ];
  static const minTrainingDays = 2;
  static const maxTrainingDays = 6;
  static const trainingDays = [1, 2, 3, 4, 5, 6, 7];
  static const weekdayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const weekdayNames = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];
  static const sessionMinutes = [45, 60, 90];

  /// Texto de cada duración. La última opción cubre también las sesiones
  /// más largas.
  static String sessionLabel(int minutes) =>
      minutes == sessionMinutes.last ? '$minutes min o más' : '$minutes min';

  /// Duración guardada en Firestore ajustada a las opciones actuales: los
  /// perfiles antiguos con 30 min (opción que ya no existe) pasan a 45.
  static int sessionMinutesFrom(int minutes) =>
      minutes < sessionMinutes.first ? sessionMinutes.first : minutes;
  static const equipment = [
    'Barra',
    'Mancuernas',
    'Máquinas',
    'Polea',
    'Peso corporal',
    'Bandas elásticas',
    'Barra de dominadas',
  ];
  static const injuries = [
    'Hombro',
    'Codo',
    'Muñeca',
    'Cuello',
    'Espalda baja',
    'Cadera',
    'Rodilla',
    'Tobillo',
  ];

  /// Nombre de la lesión tal como aparece en [injuries], sin importar
  /// mayúsculas: el JSON del catálogo trae las zonas en minúscula
  /// ("espalda baja") y el cuestionario las guarda con mayúscula
  /// ("Espalda baja"). Así se pueden comparar directamente.
  static String injuryNamed(String zone) {
    return injuries.firstWhere(
      (injury) => injury.toLowerCase() == zone.toLowerCase(),
      orElse: () => zone,
    );
  }
}

/// Nivel de actividad habitual, sin contar los entrenamientos.
enum ActivityLevel {
  sedentary('Sedentario', 'Trabajo sentado y me muevo poco', 1.3),
  lightlyActive('Ligeramente activo', 'Camino algo durante el día', 1.4),
  active('Activo', 'Paso bastante tiempo de pie o caminando', 1.5),
  veryActive('Muy activo', 'Hago trabajo físico o me muevo mucho', 1.6);

  const ActivityLevel(this.label, this.description, this.activityFactor);
  final String label;
  final String description;

  /// Multiplica el metabolismo basal para obtener las calorías de
  /// mantenimiento. Ya tiene en cuenta que el usuario entrena.
  final double activityFactor;

  /// Busca por nombre del enum; si no existe, usa la opción menos activa.
  static ActivityLevel fromName(String? name) {
    return ActivityLevel.values.firstWhere(
      (level) => level.name == name,
      orElse: () => ActivityLevel.sedentary,
    );
  }
}

/// Objetivo de entrenamiento mostrado al usuario y guardado en Firestore.
enum TrainingGoal {
  muscleGain('Ganar masa muscular', 250),
  fatLoss('Perder grasa', -350),
  bodyRecomposition('Recomposición corporal', -150),
  strength('Ganar fuerza', 150),
  generalHealth('Salud general', 0);

  const TrainingGoal(this.label, this.calorieAdjustment);
  final String label;

  /// Kcal que se suman (superávit) o restan (déficit) a las de
  /// mantenimiento para conseguir el objetivo.
  final int calorieAdjustment;

  /// Acepta nombres actuales y textos usados por perfiles antiguos.
  static TrainingGoal fromName(String? name) {
    return switch (name) {
      'Hipertrofia' => TrainingGoal.muscleGain,
      'Pérdida de grasa' => TrainingGoal.fatLoss,
      'Fuerza' => TrainingGoal.strength,
      'Salud general' => TrainingGoal.generalHealth,
      _ => TrainingGoal.values.firstWhere(
        (goal) => goal.name == name || goal.label == name,
        orElse: () => TrainingGoal.generalHealth,
      ),
    };
  }
}

/// Lugar habitual de entrenamiento y material sugerido para ese lugar.
enum TrainingPlace {
  gym('Gimnasio', ProfileOptions.equipment),
  home('Casa', ['Mancuernas', 'Bandas elásticas', 'Peso corporal']),
  outdoors('Al aire libre', ['Peso corporal', 'Bandas elásticas']);

  const TrainingPlace(this.label, this.defaultEquipment);
  final String label;
  final List<String> defaultEquipment;

  /// Busca por nombre del enum; si no existe, usa el gimnasio.
  static TrainingPlace fromName(String? name) {
    return TrainingPlace.values.firstWhere(
      (place) => place.name == name,
      orElse: () => TrainingPlace.gym,
    );
  }
}

class UserProfile {
  UserProfile({
    required this.name,
    required this.username,
    required this.email,
    this.role = UserRole.user,
    this.sex = 'Hombre',
    this.heightCm = 178,
    this.weightKg = 78,
    this.experience = 'Intermedio',
    this.goal = TrainingGoal.muscleGain,
    this.daysPerWeek = 4,
    this.equipment = ProfileOptions.equipment,
    this.surname = '',
    this.birthDate,
    this.activityLevel = ActivityLevel.sedentary,
    this.trainingDays = const [1, 2, 3, 4],
    this.sessionMinutes = 60,
    this.trainingPlace = TrainingPlace.gym,
    this.injuries = const [],
    this.onboardingCompleted = false,
    this.stepsGoal = defaultStepsGoal,
    this.trainerCode,
  });

  /// Objetivo de pasos diario si el perfil no tiene uno.
  static const defaultStepsGoal = 10000;

  /// Límites del objetivo de pasos que puede poner el usuario.
  static const minStepsGoal = 1000;
  static const maxStepsGoal = 50000;

  /// Mensaje de error si [goal] no es un objetivo de pasos válido, o null.
  static String? validateStepsGoal(int goal) {
    if (goal < minStepsGoal || goal > maxStepsGoal) {
      return 'El objetivo tiene que estar entre 1.000 y 50.000 pasos.';
    }
    return null;
  }

  String name;
  String username;
  String email;
  String surname;

  /// Solo lectura desde la app: lo cambia un admin (o la consola de
  /// Firebase). Por eso no va en [toMap].
  final UserRole role;
  String sex;

  /// La altura y el peso valen 0 en una cuenta nueva hasta que se completa
  /// el cuestionario (ver `AuthService`).
  double heightCm;
  double weightKg;
  String experience;
  TrainingGoal goal;
  int daysPerWeek;
  List<String> equipment;
  DateTime? birthDate;
  ActivityLevel activityLevel;
  List<int> trainingDays;
  int sessionMinutes;
  TrainingPlace trainingPlace;
  List<String> injuries;
  bool onboardingCompleted;

  /// Pasos al día que quiere alcanzar (para la pestaña Progreso).
  int stepsGoal;

  /// Código activo de un entrenador (`trainerCodes/{code}`), o null si no
  /// es entrenador o aún no ha abierto "Mi código".
  String? trainerCode;

  /// Edad en años, o `null` mientras no haya fecha de nacimiento.
  int? get age {
    final date = birthDate;
    if (date == null) return null;

    final today = DateTime.now();
    var years = today.year - date.year;
    if (today.month < date.month ||
        (today.month == date.month && today.day < date.day)) {
      years--;
    }
    return years;
  }

  /// Copia independiente del perfil, para editarla en un formulario sin
  /// cambiar el original hasta guardar. Reutiliza toMap/fromMap para no
  /// olvidar ningún campo; el rol se añade a mano porque toMap no lo lleva.
  UserProfile copy() => UserProfile.fromMap({...toMap(), 'role': role.name});

  /// True si [other] tiene los mismos datos de los que depende el plan de
  /// entrenamiento: días, minutos, material, lesiones, objetivo y
  /// experiencia. Si alguno cambia, hay que actualizar el plan.
  bool sameTrainingAs(UserProfile other) =>
      _sameItems(trainingDays, other.trainingDays) &&
      sessionMinutes == other.sessionMinutes &&
      _sameItems(equipment, other.equipment) &&
      _sameItems(injuries, other.injuries) &&
      goal == other.goal &&
      experience == other.experience;

  /// True si las dos listas tienen los mismos elementos, sin importar el
  /// orden (marcar "Barra" y luego "Polea" es lo mismo que al revés).
  static bool _sameItems<T>(List<T> a, List<T> b) =>
      a.toSet().length == b.toSet().length && a.toSet().containsAll(b);

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] as String? ?? '',
    username: m['username'] as String? ?? '',
    email: m['email'] as String? ?? '',
    role: UserRole.fromName(m['role'] as String?),
    sex: m['sex'] == 'Mujer' ? 'Mujer' : 'Hombre',
    heightCm: (m['heightCm'] as num?)?.toDouble() ?? 178,
    weightKg: (m['weightKg'] as num?)?.toDouble() ?? 78,
    experience: m['experience'] as String? ?? 'Intermedio',
    goal: TrainingGoal.fromName(m['goal'] as String?),
    daysPerWeek: (m['daysPerWeek'] as num?)?.toInt() ?? 4,
    // Solo el material que sigue siendo una opción: así se ignoran los
    // que ya no existen (por ejemplo "Kettlebell", que se quitó).
    equipment: [
      for (final item in m['equipment'] as List? ?? ProfileOptions.equipment)
        if (ProfileOptions.equipment.contains(item)) item as String,
    ],
    surname: m['surname'] as String? ?? '',
    birthDate: (m['birthDate'] as Timestamp?)?.toDate(),
    activityLevel: ActivityLevel.fromName(m['activityLevel'] as String?),
    trainingDays: [
      for (final day in m['trainingDays'] as List? ?? const [1, 2, 3, 4])
        (day as num).toInt(),
    ],
    sessionMinutes: ProfileOptions.sessionMinutesFrom(
      (m['sessionMinutes'] as num?)?.toInt() ?? 60,
    ),
    trainingPlace: TrainingPlace.fromName(m['trainingPlace'] as String?),
    injuries: List<String>.from(m['injuries'] as List? ?? const []),
    onboardingCompleted: m['onboardingCompleted'] as bool? ?? false,
    // Los perfiles de antes de la pestaña Progreso no tienen objetivo.
    stepsGoal: (m['stepsGoal'] as num?)?.toInt() ?? defaultStepsGoal,
    trainerCode: m['trainerCode'] as String?,
  );

  Map<String, dynamic> toMap() {
    final date = birthDate;
    return {
      'name': name,
      'username': username,
      'email': email,
      'surname': surname,
      'sex': sex,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'experience': experience,
      'goal': goal.name,
      'daysPerWeek': daysPerWeek,
      'equipment': equipment,
      'birthDate': date == null ? null : Timestamp.fromDate(date),
      'activityLevel': activityLevel.name,
      'trainingDays': trainingDays,
      'sessionMinutes': sessionMinutes,
      'trainingPlace': trainingPlace.name,
      'injuries': injuries,
      'onboardingCompleted': onboardingCompleted,
      'stepsGoal': stepsGoal,
      'trainerCode': trainerCode,
    };
  }
}

/// Usuario visto desde los paneles de admin y entrenador.
class AppUser {
  const AppUser({required this.uid, required this.profile});

  final String uid;
  final UserProfile profile;
}

/// Rutina que un entrenador asigna a un usuario. Se guarda en la colección
/// `assignedRoutines` para que la lean los dos.
class AssignedRoutine {
  const AssignedRoutine({
    required this.id,
    required this.routine,
    required this.trainerId,
    required this.trainerName,
    required this.userId,
    required this.userName,
    required this.createdAt,
    this.dayNumber,
  });

  final String id;
  final Routine routine;
  final String trainerId;
  final String trainerName;
  final String userId;
  final String userName;
  final DateTime createdAt;

  /// Día del plan del cliente en el que va la rutina, por orden: 1 = su
  /// primer día de entreno de la semana, 2 = el segundo… Se guarda el orden
  /// y no el día de la semana para que siga valiendo si el cliente cambia
  /// qué días entrena. Null en las asignaciones antiguas, que iban en todos
  /// los días de entreno.
  final int? dayNumber;

  /// "Día 2", o "Todos los días" en las asignaciones antiguas.
  String get dayLabel =>
      dayNumber == null ? 'Todos los días' : 'Día $dayNumber';

  factory AssignedRoutine.fromMap(String id, Map<String, dynamic> m) {
    final routine = Routine.fromMap(id, m);
    return AssignedRoutine(
      id: id,
      routine: Routine(
        id: id,
        name: routine.name,
        description: routine.description,
        templateName: 'Entrenador',
        exercises: routine.exercises,
      ),
      trainerId: m['trainerId'] as String,
      trainerName: m['trainerName'] as String? ?? 'Entrenador',
      userId: m['userId'] as String,
      userName: m['userName'] as String? ?? '',
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dayNumber: (m['dayNumber'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
    ...routine.toMap(),
    'trainerId': trainerId,
    'trainerName': trainerName,
    'userId': userId,
    'userName': userName,
    'createdAt': Timestamp.fromDate(createdAt),
    'dayNumber': ?dayNumber,
  };
}

class DailyMacros {
  const DailyMacros({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}

// ------------------------------------------------- Plan de entrenamiento --

/// Tipo de día del plan semanal. Los patrones de cada tipo están en
/// `RoutineGenerator`.
enum PlanDayType {
  fullBodyA('Full body A'),
  fullBodyB('Full body B'),
  fullBodyC('Full body C'),
  push('Empuje'),
  pull('Tirón'),
  legs('Pierna'),
  legsB('Pierna B'),
  upper('Torso'),
  arms('Brazos');

  const PlanDayType(this.label);
  final String label;

  /// Busca por nombre del enum; si no existe, Full body A.
  static PlanDayType fromName(String? name) {
    return PlanDayType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => PlanDayType.fullBodyA,
    );
  }
}

/// Un ejercicio del plan con sus series, repeticiones y descanso.
class PlanExercise {
  const PlanExercise({
    required this.exercise,
    required this.sets,
    required this.minReps,
    required this.maxReps,
    required this.restSeconds,
    this.isCustom = false,
    this.byTrainer = false,
    this.trainerNote,
  });

  /// Copia del ejercicio, como en los entrenos: si el admin lo cambia o lo
  /// borra del catálogo, el plan se sigue viendo bien.
  final Exercise exercise;
  final int sets;
  final int minReps;
  final int maxReps;
  final int restSeconds;

  /// True si lo ha añadido o sustituido el usuario (o su entrenador): se
  /// conserva al actualizar el plan.
  final bool isCustom;

  /// True si lo ha añadido o cambiado el entrenador. Siempre va con
  /// [isCustom], para que el generador no lo quite.
  final bool byTrainer;

  /// Nota del entrenador para este ejercicio, o null si no hay.
  final String? trainerNote;

  /// Copia con los campos indicados cambiados. [trainerNote] usa una
  /// función para poder ponerlo a null (borrar la nota):
  /// `copyWith(trainerNote: () => null)`.
  PlanExercise copyWith({
    int? sets,
    int? minReps,
    int? maxReps,
    int? restSeconds,
    bool? isCustom,
    bool? byTrainer,
    String? Function()? trainerNote,
  }) => PlanExercise(
    exercise: exercise,
    sets: sets ?? this.sets,
    minReps: minReps ?? this.minReps,
    maxReps: maxReps ?? this.maxReps,
    restSeconds: restSeconds ?? this.restSeconds,
    isCustom: isCustom ?? this.isCustom,
    byTrainer: byTrainer ?? this.byTrainer,
    trainerNote: trainerNote == null ? this.trainerNote : trainerNote(),
  );

  factory PlanExercise.fromMap(Map<String, dynamic> m) => PlanExercise(
    exercise: Exercise.fromMap(Map<String, dynamic>.from(m['exercise'])),
    sets: (m['sets'] as num?)?.toInt() ?? 3,
    minReps: (m['minReps'] as num?)?.toInt() ?? 8,
    maxReps: (m['maxReps'] as num?)?.toInt() ?? 12,
    restSeconds: (m['restSeconds'] as num?)?.toInt() ?? 90,
    isCustom: m['isCustom'] as bool? ?? false,
    // Los planes de antes del entrenador no tienen estos campos.
    byTrainer: m['byTrainer'] as bool? ?? false,
    trainerNote: m['trainerNote'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'exercise': exercise.toMap(),
    'sets': sets,
    'minReps': minReps,
    'maxReps': maxReps,
    'restSeconds': restSeconds,
    'isCustom': isCustom,
    'byTrainer': byTrainer,
    'trainerNote': trainerNote,
  };
}

/// Un día de entreno del plan.
class PlanDay {
  const PlanDay({
    required this.weekday,
    required this.type,
    required this.exercises,
    this.removedExerciseIds = const [],
  });

  /// 1 = lunes … 7 = domingo, como `UserProfile.trainingDays`.
  final int weekday;
  final PlanDayType type;
  final List<PlanExercise> exercises;

  /// Ejercicios que el usuario ha quitado de este día: no vuelven al
  /// actualizar el plan.
  final List<String> removedExerciseIds;

  /// Nombre para mostrar, por ejemplo "Empuje".
  String get name => type.label;

  /// "Martes". Si un documento trae un día fuera de 1–7, se acota para no
  /// salirse de la lista.
  String get weekdayName =>
      ProfileOptions.weekdayNames[weekday.clamp(1, 7) - 1];

  /// "Martes · Empuje", para los títulos.
  String get title => '$weekdayName · $name';

  /// True si el ejercicio está en el día.
  bool contains(String exerciseId) =>
      exercises.any((e) => e.exercise.id == exerciseId);

  // Los cambios del usuario devuelven un día nuevo en lugar de modificar
  // este (es inmutable, como un String en Java).

  /// El día con [added] al final. Si lo había quitado antes, deja de
  /// estar en [removedExerciseIds].
  PlanDay withExercise(PlanExercise added) => _copy(
    exercises: [...exercises, added],
    removed: removedExerciseIds.where((id) => id != added.exercise.id),
  );

  /// El día sin ese ejercicio. Su id se guarda en [removedExerciseIds]
  /// para que no vuelva al actualizar el plan.
  PlanDay withoutExercise(String exerciseId) => _copy(
    exercises: exercises.where((e) => e.exercise.id != exerciseId),
    removed: {...removedExerciseIds, exerciseId},
  );

  /// El día con [replacement] en el lugar de [oldId]. El antiguo cuenta
  /// como quitado.
  PlanDay replacing(String oldId, PlanExercise replacement) => _copy(
    exercises: [
      for (final e in exercises) e.exercise.id == oldId ? replacement : e,
    ],
    removed: {
      ...removedExerciseIds,
      oldId,
    }.where((id) => id != replacement.exercise.id),
  );

  /// El día con [changed] en el lugar del ejercicio con su mismo id (por
  /// ejemplo, con otras series o una nota).
  PlanDay updating(PlanExercise changed) => _copy(
    exercises: [
      for (final e in exercises)
        e.exercise.id == changed.exercise.id ? changed : e,
    ],
    removed: removedExerciseIds,
  );

  PlanDay _copy({
    required Iterable<PlanExercise> exercises,
    required Iterable<String> removed,
  }) => PlanDay(
    weekday: weekday,
    type: type,
    exercises: exercises.toList(),
    removedExerciseIds: removed.toList(),
  );

  factory PlanDay.fromMap(Map<String, dynamic> m) => PlanDay(
    weekday: (m['weekday'] as num?)?.toInt() ?? 1,
    type: PlanDayType.fromName(m['type'] as String?),
    exercises: [
      for (final e in m['exercises'] as List? ?? const [])
        PlanExercise.fromMap(Map<String, dynamic>.from(e)),
    ],
    removedExerciseIds: List<String>.from(
      m['removedExerciseIds'] as List? ?? const [],
    ),
  );

  Map<String, dynamic> toMap() => {
    'weekday': weekday,
    'type': type.name,
    'exercises': [for (final e in exercises) e.toMap()],
    'removedExerciseIds': removedExerciseIds,
  };
}

/// Plan semanal generado a partir del perfil. Se guarda entero en un solo
/// documento: `users/{uid}/plan/current`.
class TrainingPlan {
  const TrainingPlan({required this.generatedAt, required this.days});

  final DateTime generatedAt;

  /// Días de entreno, ordenados de lunes a domingo.
  final List<PlanDay> days;

  /// Estructura de la semana (por ejemplo Empuje · Pierna · Tirón). Sale de
  /// los días, así que nunca puede quedar desincronizada.
  List<PlanDayType> get structure => [for (final d in days) d.type];

  /// Entreno de ese día de la semana, o null si es de descanso.
  PlanDay? dayFor(int weekday) {
    for (final day in days) {
      if (day.weekday == weekday) return day;
    }
    return null;
  }

  /// El plan con [day] en lugar del día de la misma fecha de la semana.
  TrainingPlan withDay(PlanDay day) => TrainingPlan(
    generatedAt: generatedAt,
    days: [for (final d in days) d.weekday == day.weekday ? day : d],
  );

  factory TrainingPlan.fromMap(Map<String, dynamic> m) => TrainingPlan(
    generatedAt: (m['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    days: [
      for (final d in m['days'] as List? ?? const [])
        PlanDay.fromMap(Map<String, dynamic>.from(d)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'generatedAt': Timestamp.fromDate(generatedAt),
    'days': [for (final d in days) d.toMap()],
  };
}

/// Estado de una solicitud de entrenador. "Sin entrenador" no se guarda:
/// es que no existe el documento `trainerLinks/{clientId}`.
enum LinkStatus {
  pending('Pendiente'),
  accepted('Vinculado');

  const LinkStatus(this.label);
  final String label;

  static LinkStatus fromName(String? name) {
    return LinkStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => LinkStatus.pending,
    );
  }
}

/// Vínculo entre un cliente y su entrenador (`trainerLinks/{clientId}`).
/// El id del documento es el uid del cliente, así que solo puede tener uno.
/// Es inmutable: aceptar devuelve un vínculo nuevo.
class TrainerLink {
  const TrainerLink({
    required this.clientId,
    required this.clientName,
    required this.trainerId,
    required this.trainerName,
    required this.code,
    required this.status,
    required this.createdAt,
  });

  final String clientId;
  final String clientName;
  final String trainerId;
  final String trainerName;

  /// Código con el que se envió la solicitud.
  final String code;
  final LinkStatus status;
  final DateTime createdAt;

  bool get isPending => status == LinkStatus.pending;
  bool get isAccepted => status == LinkStatus.accepted;

  /// El mismo vínculo, ya aceptado por el entrenador.
  TrainerLink accept() => TrainerLink(
    clientId: clientId,
    clientName: clientName,
    trainerId: trainerId,
    trainerName: trainerName,
    code: code,
    status: LinkStatus.accepted,
    createdAt: createdAt,
  );

  factory TrainerLink.fromMap(Map<String, dynamic> m) => TrainerLink(
    clientId: m['clientId'] as String? ?? '',
    clientName: m['clientName'] as String? ?? '',
    trainerId: m['trainerId'] as String? ?? '',
    trainerName: m['trainerName'] as String? ?? 'Entrenador',
    code: m['code'] as String? ?? '',
    status: LinkStatus.fromName(m['status'] as String?),
    createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'clientId': clientId,
    'clientName': clientName,
    'trainerId': trainerId,
    'trainerName': trainerName,
    'code': code,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

/// Objetivos que el entrenador pone a su cliente
/// (`users/{clientId}/coach/settings`): calorías y pasos. Un campo null
/// significa "usa el cálculo automático". Los macros (proteína, grasa e
/// hidratos) no los fija el entrenador: la app los reparte a partir de las
/// calorías, igual que en el cálculo automático.
class CoachSettings {
  const CoachSettings({this.kcalTarget, this.stepsGoal});

  static const minKcal = 1000;

  /// Más no es saludable.
  static const maxKcal = 5000;

  final int? kcalTarget;
  final int? stepsGoal;

  /// True si no ajusta nada (todo automático).
  bool get isEmpty => kcalTarget == null && stepsGoal == null;

  /// True si cambia las calorías.
  bool get adjustsNutrition => kcalTarget != null;

  /// Mensaje de error si algún valor está fuera de rango, o null. Los null
  /// (automático) siempre valen.
  String? validate() {
    final kcal = kcalTarget;
    if (kcal != null && (kcal < minKcal || kcal > maxKcal)) {
      return 'Las calorías tienen que estar entre 1.000 y 5.000 kcal.';
    }
    final steps = stepsGoal;
    return steps == null ? null : UserProfile.validateStepsGoal(steps);
  }

  /// Si un documento antiguo trae otros campos (como `proteinTarget`), se
  /// ignoran.
  factory CoachSettings.fromMap(Map<String, dynamic> m) => CoachSettings(
    kcalTarget: (m['kcalTarget'] as num?)?.toInt(),
    stepsGoal: (m['stepsGoal'] as num?)?.toInt(),
  );

  Map<String, dynamic> toMap() => {
    'kcalTarget': kcalTarget,
    'stepsGoal': stepsGoal,
    'updatedAt': Timestamp.now(),
  };
}

/// Lo que el entrenador hace con una nota (comentario) que su cliente dejó
/// en un ejercicio: marcarla como leída y, si quiere, responderla. Se
/// guarda en `users/{clientId}/coachReplies/{id}`, un documento por nota,
/// con el id de [idFor]. Así el cliente lee sus respuestas con una sola
/// escucha y el entrenador sabe qué notas no ha leído (las que no tienen
/// documento o tienen [readAt] a null).
class CoachReply {
  const CoachReply({
    required this.workoutId,
    required this.exerciseIndex,
    required this.exerciseId,
    this.reply,
    this.readAt,
  });

  /// Texto máximo de una respuesta.
  static const maxLength = 300;

  final String workoutId;

  /// Posición del ejercicio dentro del entreno (los entrenos guardados no
  /// cambian, así que identifica el ejercicio aunque se repita).
  final int exerciseIndex;
  final String exerciseId;

  /// Respuesta del entrenador, o null si solo la ha leído.
  final String? reply;

  /// Cuándo la leyó el entrenador, o null si aún no.
  final DateTime? readAt;

  String get id => idFor(workoutId, exerciseIndex);
  bool get isRead => readAt != null;

  /// Id del documento de la nota del ejercicio [exerciseIndex] del entreno
  /// [workoutId], por ejemplo "abc123_2".
  static String idFor(String workoutId, int exerciseIndex) =>
      '${workoutId}_$exerciseIndex';

  /// Mensaje de error si la respuesta no es válida, o null si lo es.
  static String? validate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 'Escribe una respuesta.';
    if (trimmed.length > maxLength) {
      return 'Como mucho $maxLength caracteres.';
    }
    return null;
  }

  CoachReply copyWith({String? reply, DateTime? readAt}) => CoachReply(
    workoutId: workoutId,
    exerciseIndex: exerciseIndex,
    exerciseId: exerciseId,
    reply: reply ?? this.reply,
    readAt: readAt ?? this.readAt,
  );

  factory CoachReply.fromMap(Map<String, dynamic> m) => CoachReply(
    workoutId: m['workoutId'] as String? ?? '',
    exerciseIndex: (m['exerciseIndex'] as num?)?.toInt() ?? 0,
    exerciseId: m['exerciseId'] as String? ?? '',
    reply: m['reply'] as String?,
    readAt: (m['readAt'] as Timestamp?)?.toDate(),
  );

  Map<String, dynamic> toMap() => {
    'workoutId': workoutId,
    'exerciseIndex': exerciseIndex,
    'exerciseId': exerciseId,
    'reply': ?reply,
    if (readAt case final read?) 'readAt': Timestamp.fromDate(read),
    'updatedAt': Timestamp.now(),
  };
}
