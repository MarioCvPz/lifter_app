import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 2: objetivo de entrenamiento.
class GoalStep extends StatelessWidget {
  const GoalStep({super.key, required this.profile, required this.onChanged});

  final UserProfile profile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cuál es tu objetivo?',
          subtitle:
              'Lo usamos para recomendarte una rutina y calcular tus '
              'calorías.',
        ),
        ChoiceList<TrainingGoal>(
          options: TrainingGoal.values,
          selected: profile.goal,
          label: (goal) => goal.label,
          onSelected: (goal) {
            profile.goal = goal;
            onChanged();
          },
        ),
      ],
    );
  }
}
