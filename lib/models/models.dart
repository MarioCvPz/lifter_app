import 'package:cloud_firestore/cloud_firestore.dart';

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    required this.level,
  });

  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String level;

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
    id: m['id'] as String,
    name: m['name'] as String,
    muscleGroup: m['muscleGroup'] as String,
    equipment: m['equipment'] as String,
    level: m['level'] as String,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup,
    'equipment': equipment,
    'level': level,
  };
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
  const WorkoutExercise({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<WorkoutSet> sets;

  factory WorkoutExercise.fromMap(Map<String, dynamic> m) => WorkoutExercise(
    exercise: Exercise.fromMap(Map<String, dynamic>.from(m['exercise'])),
    sets: [
      for (final s in m['sets'] as List)
        WorkoutSet.fromMap(Map<String, dynamic>.from(s)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'exercise': exercise.toMap(),
    'sets': [for (final s in sets) s.toMap()],
  };
}

class Workout {
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
  });

  final String id;
  final String name;
  final String description;
  final String templateName;
  final List<Exercise> exercises;
  final bool isTemplate;

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

  /// Estimación: unos 10 minutos por ejercicio.
  int get estimatedMin => exercises.length * 10;

  factory Routine.fromMap(String id, Map<String, dynamic> m) => Routine(
    id: id,
    name: m['name'] as String,
    description: m['description'] as String? ?? '',
    templateName: m['templateName'] as String? ?? 'Personal',
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
    'createdAt': Timestamp.now(),
  };
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.kcalPer100,
    required this.proteinPer100,
    required this.carbsPer100,
    required this.fatPer100,
  });

  final String id;
  final String name;
  final double kcalPer100;
  final double proteinPer100;
  final double carbsPer100;
  final double fatPer100;

  factory Food.fromMap(Map<String, dynamic> m) => Food(
    id: m['id'] as String,
    name: m['name'] as String,
    kcalPer100: (m['kcalPer100'] as num).toDouble(),
    proteinPer100: (m['proteinPer100'] as num).toDouble(),
    carbsPer100: (m['carbsPer100'] as num).toDouble(),
    fatPer100: (m['fatPer100'] as num).toDouble(),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
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
    this.goal = 'Hipertrofia',
    this.daysPerWeek = 4,
    this.equipment = const ['Barra', 'Mancuernas', 'Máquinas'],
  });

  String name;
  String username;
  String email;

  /// Solo lectura desde la app: lo cambia un admin (o la consola de
  /// Firebase). Por eso no va en [toMap].
  final UserRole role;
  String sex;
  double heightCm;
  double weightKg;
  String experience;
  String goal;
  int daysPerWeek;
  List<String> equipment;

  factory UserProfile.fromMap(Map<String, dynamic> m) => UserProfile(
    name: m['name'] as String? ?? '',
    username: m['username'] as String? ?? '',
    email: m['email'] as String? ?? '',
    role: UserRole.fromName(m['role'] as String?),
    sex: m['sex'] as String? ?? 'Hombre',
    heightCm: (m['heightCm'] as num?)?.toDouble() ?? 178,
    weightKg: (m['weightKg'] as num?)?.toDouble() ?? 78,
    experience: m['experience'] as String? ?? 'Intermedio',
    goal: m['goal'] as String? ?? 'Hipertrofia',
    daysPerWeek: (m['daysPerWeek'] as num?)?.toInt() ?? 4,
    equipment: List<String>.from(
      m['equipment'] as List? ?? const ['Barra', 'Mancuernas', 'Máquinas'],
    ),
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'username': username,
    'email': email,
    'sex': sex,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'experience': experience,
    'goal': goal,
    'daysPerWeek': daysPerWeek,
    'equipment': equipment,
  };
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
  });

  final String id;
  final Routine routine;
  final String trainerId;
  final String trainerName;
  final String userId;
  final String userName;
  final DateTime createdAt;

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
    );
  }

  Map<String, dynamic> toMap() => {
    ...routine.toMap(),
    'trainerId': trainerId,
    'trainerName': trainerName,
    'userId': userId,
    'userName': userName,
    'createdAt': Timestamp.fromDate(createdAt),
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
