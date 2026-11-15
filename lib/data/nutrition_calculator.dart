import 'dart:math' as math;

import '../models/models.dart';

/// Calcula las calorías y los macronutrientes diarios a partir del perfil.
/// Cada regla está en su propio método y cada uno usa el anterior:
/// basal → mantenimiento → calorías objetivo → macros.
///
/// No depende de Flutter ni de Firebase, así que se prueba con tests
/// normales. Es como una clase de utilidades de Java (`Math`): solo tiene
/// constantes y métodos estáticos, y no se puede instanciar.
class NutritionCalculator {
  NutritionCalculator._();

  /// Edad que se usa si el perfil no tiene fecha de nacimiento (perfiles
  /// antiguos).
  static const defaultAge = 30;

  // Coeficientes de la fórmula de Mifflin-St Jeor.
  static const bmrPerKg = 10.0;
  static const bmrPerCm = 6.25;
  static const bmrPerYear = 5.0;
  static const bmrMaleConstant = 5.0;
  static const bmrFemaleConstant = -161.0;

  /// Valor de `UserProfile.sex` que usa la fórmula de mujer.
  static const femaleSex = 'Mujer';

  /// Gramos de proteína por kg de peso de referencia. La ISSN (International
  /// Society of Sports Nutrition) recomienda de 1,4 a 2,0 g/kg a quien
  /// entrena; 1,8 está en la parte alta del rango.
  static const proteinPerKg = 1.8;

  /// IMC con el que se calcula el peso de referencia.
  static const referenceBmi = 25.0;

  /// Parte de las calorías que se reserva a la grasa (25 %).
  static const fatCaloriesShare = 0.25;

  static const kcalPerGramFat = 9;
  static const kcalPerGramProteinOrCarbs = 4;

  /// Metabolismo basal (kcal que gasta el cuerpo en reposo) con la fórmula
  /// de Mifflin-St Jeor (1990), la más precisa en adultos:
  /// - hombre: 10 × peso(kg) + 6,25 × altura(cm) − 5 × edad + 5
  /// - mujer:  10 × peso(kg) + 6,25 × altura(cm) − 5 × edad − 161
  static double bmr(UserProfile profile) {
    final age = profile.age ?? defaultAge;
    final sexConstant = profile.sex == femaleSex
        ? bmrFemaleConstant
        : bmrMaleConstant;
    return bmrPerKg * profile.weightKg +
        bmrPerCm * profile.heightCm -
        bmrPerYear * age +
        sexConstant;
  }

  /// Calorías de mantenimiento: el basal multiplicado por el factor de la
  /// actividad diaria ([ActivityLevel.activityFactor]).
  static double maintenance(UserProfile profile) {
    return bmr(profile) * profile.activityLevel.activityFactor;
  }

  /// Calorías objetivo: el mantenimiento más el ajuste del objetivo
  /// ([TrainingGoal.calorieAdjustment]). Por seguridad, nunca bajan del
  /// metabolismo basal: comer menos que eso no es recomendable.
  static double targetCalories(UserProfile profile) {
    final target = maintenance(profile) + profile.goal.calorieAdjustment;
    return math.max(target, bmr(profile));
  }

  /// Peso de referencia para la proteína: el menor entre el peso real y el
  /// peso que daría un IMC de 25 (25 × altura(m)²). Así, con mucho
  /// sobrepeso, no salen cantidades de proteína exageradas.
  static double referenceWeightKg(UserProfile profile) {
    final heightM = profile.heightCm / 100;
    return math.min(profile.weightKg, referenceBmi * heightM * heightM);
  }

  /// Objetivo diario de calorías y macros:
  /// - proteína: [proteinPerKg] g por kg de peso de referencia;
  /// - grasa: el [fatCaloriesShare] de las calorías;
  /// - hidratos: las calorías que quedan.
  /// Se redondea solo aquí, al final, para no acumular errores.
  static DailyMacros macros(UserProfile profile) {
    final kcal = targetCalories(profile);
    final protein = referenceWeightKg(profile) * proteinPerKg;
    final fat = kcal * fatCaloriesShare / kcalPerGramFat;
    final carbsKcal =
        kcal - protein * kcalPerGramProteinOrCarbs - fat * kcalPerGramFat;
    // Nunca negativo (solo pasaría con datos absurdos).
    final carbs = math.max(0.0, carbsKcal / kcalPerGramProteinOrCarbs);

    return DailyMacros(
      kcal: kcal.roundToDouble(),
      protein: protein.roundToDouble(),
      carbs: carbs.roundToDouble(),
      fat: fat.roundToDouble(),
    );
  }
}
