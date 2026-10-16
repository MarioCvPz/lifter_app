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
}

class WorkoutSet {
  const WorkoutSet({required this.reps, required this.weightKg});

  final int reps;
  final double weightKg;
}

class WorkoutExercise {
  const WorkoutExercise({required this.exercise, required this.sets});

  final Exercise exercise;
  final List<WorkoutSet> sets;
}

class Workout {
  const Workout({
    required this.id,
    required this.name,
    required this.date,
    required this.durationMin,
    required this.exercises,
  });

  final String id;
  final String name;
  final DateTime date;
  final int durationMin;
  final List<WorkoutExercise> exercises;
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

  double get kcal => food.kcalPer100 * grams / 100;
  double get protein => food.proteinPer100 * grams / 100;
  double get carbs => food.carbsPer100 * grams / 100;
  double get fat => food.fatPer100 * grams / 100;
}

class UserProfile {
  UserProfile({
    required this.name,
    required this.username,
    required this.email,
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
  String sex;
  double heightCm;
  double weightKg;
  String experience;
  String goal;
  int daysPerWeek;
  List<String> equipment;
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
