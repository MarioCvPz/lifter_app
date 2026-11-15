import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/nutrition_calculator.dart';
import 'package:lifter_app/models/models.dart';

/// Perfil de prueba con la edad indicada (la fecha de nacimiento se calcula
/// desde hoy, para que la edad no cambie con el paso del tiempo).
UserProfile person({
  required String sex,
  required int age,
  required double weightKg,
  required double heightCm,
  required ActivityLevel activity,
  required TrainingGoal goal,
}) {
  final today = DateTime.now();
  return UserProfile(
    name: 'Prueba',
    username: 'prueba',
    email: 'prueba@test.com',
    sex: sex,
    birthDate: DateTime(today.year - age, today.month, today.day),
    weightKg: weightKg,
    heightCm: heightCm,
    activityLevel: activity,
    goal: goal,
  );
}

void main() {
  test('CP-12 Ejemplo: hombre, 22 años, 78 kg, 178 cm, ligeramente activo, '
      'ganar masa muscular', () {
    final p = person(
      sex: 'Hombre',
      age: 22,
      weightKg: 78,
      heightCm: 178,
      activity: ActivityLevel.lightlyActive,
      goal: TrainingGoal.muscleGain,
    );

    // 10 × 78 + 6,25 × 178 − 5 × 22 + 5 = 1.787,5
    expect(NutritionCalculator.bmr(p), closeTo(1787.5, 0.01));
    // 1.787,5 × 1,4 = 2.502,5
    expect(NutritionCalculator.maintenance(p), closeTo(2502.5, 0.01));
    // 2.502,5 + 250 = 2.752,5
    expect(NutritionCalculator.targetCalories(p), closeTo(2752.5, 0.01));

    final m = NutritionCalculator.macros(p);
    expect(m.kcal, 2753);
    expect(m.protein, 140); // 78 × 1,8 = 140,4
    expect(m.fat, 76); // 2.752,5 × 0,25 / 9 = 76,5
    expect(m.carbs, 376); // (2.752,5 − 561,6 − 688,1) / 4 = 375,7
  });

  test('CP-12 Mujer: 35 años, 62 kg, 165 cm, activa, perder grasa', () {
    final p = person(
      sex: 'Mujer',
      age: 35,
      weightKg: 62,
      heightCm: 165,
      activity: ActivityLevel.active,
      goal: TrainingGoal.fatLoss,
    );

    // 10 × 62 + 6,25 × 165 − 5 × 35 − 161 = 1.315,25
    expect(NutritionCalculator.bmr(p), closeTo(1315.25, 0.01));
    // 1.315,25 × 1,5 = 1.972,875
    expect(NutritionCalculator.maintenance(p), closeTo(1972.875, 0.01));

    final m = NutritionCalculator.macros(p);
    expect(m.kcal, 1623); // 1.972,875 − 350 = 1.622,875
    expect(m.protein, 112); // 62 × 1,8 = 111,6
    expect(m.fat, 45); // 1.622,875 × 0,25 / 9 = 45,08
    expect(m.carbs, 193); // (1.622,875 − 446,4 − 405,72) / 4 = 192,69
  });

  test('CP-12 Límite de seguridad: las calorías no bajan del basal', () {
    // Mujer mayor, pequeña y sedentaria que quiere perder grasa: el
    // déficit de 350 kcal la dejaría por debajo de su metabolismo basal.
    final p = person(
      sex: 'Mujer',
      age: 70,
      weightKg: 45,
      heightCm: 150,
      activity: ActivityLevel.sedentary,
      goal: TrainingGoal.fatLoss,
    );

    final bmr = NutritionCalculator.bmr(p);
    // 10 × 45 + 6,25 × 150 − 5 × 70 − 161 = 876,5
    expect(bmr, closeTo(876.5, 0.01));
    // 876,5 × 1,3 − 350 = 789,45, que es menos que el basal…
    expect(NutritionCalculator.maintenance(p) - 350, lessThan(bmr));
    // …así que el objetivo se queda en el basal.
    expect(NutritionCalculator.targetCalories(p), closeTo(876.5, 0.01));
    expect(NutritionCalculator.macros(p).kcal, 877);
  });

  test('CP-12 Peso de referencia: 130 kg y 1,75 m', () {
    final p = person(
      sex: 'Hombre',
      age: 30,
      weightKg: 130,
      heightCm: 175,
      activity: ActivityLevel.sedentary,
      goal: TrainingGoal.fatLoss,
    );

    // 25 × 1,75² = 76,5625 kg, menor que los 130 kg reales.
    expect(NutritionCalculator.referenceWeightKg(p), closeTo(76.56, 0.01));
    // 76,5625 × 1,8 = 137,8 → 138 g (con el peso real serían 234 g).
    expect(NutritionCalculator.macros(p).protein, 138);
  });

  test('CP-12 Sin fecha de nacimiento se usan 30 años', () {
    final withoutDate = UserProfile(
      name: 'Prueba',
      username: 'prueba',
      email: 'prueba@test.com',
      weightKg: 80,
      heightCm: 180,
    );
    final thirty = person(
      sex: 'Hombre',
      age: 30,
      weightKg: 80,
      heightCm: 180,
      activity: ActivityLevel.sedentary,
      goal: TrainingGoal.muscleGain,
    );

    expect(withoutDate.age, isNull);
    expect(
      NutritionCalculator.bmr(withoutDate),
      NutritionCalculator.bmr(thirty),
    );
  });
}
