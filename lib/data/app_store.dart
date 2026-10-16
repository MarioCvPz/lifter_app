import 'package:flutter/material.dart';

import '../models/models.dart';

class AppStore extends ChangeNotifier {
  bool isLoggedIn = false;
  UserProfile? user;

  final List<Exercise> exercises = const [
    Exercise(
      id: 'ex1',
      name: 'Press de banca',
      muscleGroup: 'Pecho',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex2',
      name: 'Sentadilla',
      muscleGroup: 'Piernas',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex3',
      name: 'Peso muerto',
      muscleGroup: 'Espalda',
      equipment: 'Barra',
      level: 'Avanzado',
    ),
    Exercise(
      id: 'ex4',
      name: 'Dominadas',
      muscleGroup: 'Espalda',
      equipment: 'Peso corporal',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex5',
      name: 'Press militar',
      muscleGroup: 'Hombros',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex6',
      name: 'Remo con barra',
      muscleGroup: 'Espalda',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex7',
      name: 'Curl de bíceps',
      muscleGroup: 'Brazos',
      equipment: 'Mancuernas',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex8',
      name: 'Extensión de tríceps',
      muscleGroup: 'Brazos',
      equipment: 'Polea',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex9',
      name: 'Zancadas',
      muscleGroup: 'Piernas',
      equipment: 'Mancuernas',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex10',
      name: 'Plancha',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      level: 'Principiante',
    ),
  ];

  late final List<Routine> routines;
  late final List<Workout> workouts;
  late final List<Food> foods;
  late final List<NutritionEntry> nutritionLogs;

  AppStore() {
    routines = [
      Routine(
        id: 'tpl-full',
        name: 'Full body 3 días',
        description: 'Plantilla para 3 días semanales. Cuerpo completo.',
        templateName: 'Full body',
        isTemplate: true,
        exercises: [exercises[1], exercises[0], exercises[3], exercises[9]],
      ),
      Routine(
        id: 'tpl-ul',
        name: 'Torso / Pierna',
        description: 'Plantilla de 4 días: dos de torso y dos de pierna.',
        templateName: 'Torso/Pierna',
        isTemplate: true,
        exercises: [exercises[0], exercises[5], exercises[1], exercises[2]],
      ),
      Routine(
        id: 'tpl-ppl',
        name: 'Push / Pull / Legs',
        description: 'Plantilla de 6 días o 3 días según disponibilidad.',
        templateName: 'Push/Pull/Legs',
        isTemplate: true,
        exercises: [exercises[0], exercises[4], exercises[5], exercises[1]],
      ),
      Routine(
        id: 'usr-1',
        name: 'Mi rutina de fuerza',
        description: 'Rutina propia (solo en memoria, no se guarda).',
        templateName: 'Personal',
        exercises: [exercises[2], exercises[1], exercises[4]],
      ),
    ];

    workouts = [
      Workout(
        id: 'w1',
        name: 'Torso A',
        date: DateTime.now().subtract(const Duration(days: 1)),
        durationMin: 62,
        exercises: [
          WorkoutExercise(
            exercise: exercises[0],
            sets: const [
              WorkoutSet(reps: 8, weightKg: 70),
              WorkoutSet(reps: 8, weightKg: 72.5),
              WorkoutSet(reps: 6, weightKg: 75),
            ],
          ),
          WorkoutExercise(
            exercise: exercises[5],
            sets: const [
              WorkoutSet(reps: 10, weightKg: 50),
              WorkoutSet(reps: 10, weightKg: 52.5),
            ],
          ),
        ],
      ),
      Workout(
        id: 'w2',
        name: 'Pierna',
        date: DateTime.now().subtract(const Duration(days: 3)),
        durationMin: 55,
        exercises: [
          WorkoutExercise(
            exercise: exercises[1],
            sets: const [
              WorkoutSet(reps: 6, weightKg: 90),
              WorkoutSet(reps: 6, weightKg: 95),
            ],
          ),
        ],
      ),
    ];

    foods = const [
      Food(
        id: 'f1',
        name: 'Pechuga de pollo',
        kcalPer100: 110,
        proteinPer100: 23,
        carbsPer100: 0,
        fatPer100: 1.5,
      ),
      Food(
        id: 'f2',
        name: 'Arroz blanco cocido',
        kcalPer100: 130,
        proteinPer100: 2.7,
        carbsPer100: 28,
        fatPer100: 0.3,
      ),
      Food(
        id: 'f3',
        name: 'Huevo entero',
        kcalPer100: 143,
        proteinPer100: 13,
        carbsPer100: 1.1,
        fatPer100: 9.5,
      ),
      Food(
        id: 'f4',
        name: 'Plátano',
        kcalPer100: 89,
        proteinPer100: 1.1,
        carbsPer100: 23,
        fatPer100: 0.3,
      ),
      Food(
        id: 'f5',
        name: 'Avena',
        kcalPer100: 379,
        proteinPer100: 13,
        carbsPer100: 67,
        fatPer100: 6.5,
      ),
      Food(
        id: 'f6',
        name: 'Yogur griego',
        kcalPer100: 97,
        proteinPer100: 9,
        carbsPer100: 3.6,
        fatPer100: 5,
      ),
    ];

    nutritionLogs = [
      NutritionEntry(
        id: 'n1',
        food: foods[4],
        grams: 80,
        date: DateTime.now(),
      ),
      NutritionEntry(
        id: 'n2',
        food: foods[0],
        grams: 180,
        date: DateTime.now(),
      ),
    ];
  }

  String? login({required String email, required String password}) {
    if (!_validEmail(email)) return 'Introduce un correo válido.';
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    user = UserProfile(
      name: 'Mario',
      username: 'mario',
      email: email.trim(),
    );
    isLoggedIn = true;
    notifyListeners();
    return null;
  }

  String? register({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty) return 'El nombre no puede estar vacío.';
    if (!_validEmail(email)) return 'Introduce un correo válido.';
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    user = UserProfile(
      name: name.trim(),
      username: name.trim().toLowerCase().replaceAll(' ', ''),
      email: email.trim(),
    );
    isLoggedIn = true;
    notifyListeners();
    return null;
  }

  void logout() {
    isLoggedIn = false;
    user = null;
    notifyListeners();
  }

  void updateProfile(UserProfile next) {
    user = next;
    notifyListeners();
  }

  void addWorkout(Workout workout) {
    workouts.insert(0, workout);
    notifyListeners();
  }

  void addRoutine(Routine routine) {
    routines.insert(0, routine);
    notifyListeners();
  }

  void addNutrition(NutritionEntry entry) {
    nutritionLogs.insert(0, entry);
    notifyListeners();
  }

  void removeNutrition(String id) {
    nutritionLogs.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  DailyMacros macrosFor(DateTime day) {
    final ofDay = nutritionLogs.where((e) => _sameDay(e.date, day));
    return DailyMacros(
      kcal: ofDay.fold(0, (s, e) => s + e.kcal),
      protein: ofDay.fold(0, (s, e) => s + e.protein),
      carbs: ofDay.fold(0, (s, e) => s + e.carbs),
      fat: ofDay.fold(0, (s, e) => s + e.fat),
    );
  }

  List<NutritionEntry> nutritionFor(DateTime day) {
    return nutritionLogs.where((e) => _sameDay(e.date, day)).toList();
  }

  Routine recommendedRoutine() {
    final days = user?.daysPerWeek ?? 4;
    if (days <= 3) return routines.firstWhere((r) => r.id == 'tpl-full');
    if (days <= 4) return routines.firstWhere((r) => r.id == 'tpl-ul');
    return routines.firstWhere((r) => r.id == 'tpl-ppl');
  }

  bool _validEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class SessionScope extends InheritedNotifier<AppStore> {
  const SessionScope({
    super.key,
    required AppStore store,
    required super.child,
  }) : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope no encontrado');
    return scope!.notifier!;
  }
}
