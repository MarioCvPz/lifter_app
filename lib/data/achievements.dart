import 'package:flutter/material.dart';

import 'app_store.dart';

/// Insignia que se consigue al llegar a [target] en algún dato del usuario.
/// Se calculan al vuelo a partir de los entrenos, comidas y agua.
class Achievement {
  const Achievement({
    required this.name,
    required this.description,
    required this.icon,
    required this.current,
    required this.target,
    required this.unit,
  });

  final String name;
  final String description;
  final IconData icon;
  final num current;
  final num target;

  /// Unidad para mostrar el progreso (p. ej. "entrenos", "días").
  final String unit;

  bool get unlocked => current >= target;
  double get progress => target == 0 ? 1 : (current / target).clamp(0, 1);
}

List<Achievement> achievementsFor(AppStore store) {
  final total = store.workouts.length;
  final best = store.bestStreak();
  final volume = store.totalVolume();
  final weekGoal = store.user?.daysPerWeek ?? 4;

  return [
    Achievement(
      name: 'Primer paso',
      description: 'Registra tu primer entrenamiento.',
      icon: Icons.flag,
      current: total,
      target: 1,
      unit: 'entrenos',
    ),
    Achievement(
      name: 'Constante',
      description: 'Entrena 3 días seguidos.',
      icon: Icons.local_fire_department,
      current: best,
      target: 3,
      unit: 'días seguidos',
    ),
    Achievement(
      name: 'Imparable',
      description: 'Entrena 7 días seguidos.',
      icon: Icons.whatshot,
      current: best,
      target: 7,
      unit: 'días seguidos',
    ),
    Achievement(
      name: 'Semana completa',
      description: 'Entrena todos tus días disponibles de esta semana.',
      icon: Icons.emoji_events,
      current: store.workoutsThisWeek(),
      target: weekGoal,
      unit: 'entrenos esta semana',
    ),
    Achievement(
      name: 'Habitual',
      description: 'Completa 10 entrenamientos.',
      icon: Icons.military_tech,
      current: total,
      target: 10,
      unit: 'entrenos',
    ),
    Achievement(
      name: 'Veterano',
      description: 'Completa 50 entrenamientos.',
      icon: Icons.workspace_premium,
      current: total,
      target: 50,
      unit: 'entrenos',
    ),
    Achievement(
      name: 'Toneladas',
      description: 'Levanta 10.000 kg de volumen en total.',
      icon: Icons.fitness_center,
      current: volume.round(),
      target: 10000,
      unit: 'kg',
    ),
    Achievement(
      name: 'Titán',
      description: 'Levanta 100.000 kg de volumen en total.',
      icon: Icons.bolt,
      current: volume.round(),
      target: 100000,
      unit: 'kg',
    ),
    Achievement(
      name: 'Buen comer',
      description: 'Registra tus comidas 7 días distintos.',
      icon: Icons.restaurant,
      current: store.nutritionDaysLogged(),
      target: 7,
      unit: 'días',
    ),
    Achievement(
      name: 'Hidratado',
      description: 'Llega hoy a tu objetivo de agua.',
      icon: Icons.water_drop,
      current: store.waterMl,
      target: store.waterGoalMl,
      unit: 'ml hoy',
    ),
  ];
}
