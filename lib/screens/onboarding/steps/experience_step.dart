import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 5: experiencia entrenando. Usa los niveles de las rutinas
/// ([Routine.levels]) para poder recomendar una de su nivel.
class ExperienceStep extends StatelessWidget {
  const ExperienceStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    // Perfiles antiguos con un texto que ya no existe: se marca el
    // intermedio, que es el valor por defecto del modelo.
    final selected = Routine.levels.contains(profile.experience)
        ? profile.experience
        : Routine.levels[1];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cuánta experiencia tienes?',
          subtitle: 'Contando el tiempo que llevas entrenando con pesas.',
        ),
        ChoiceList<String>(
          options: Routine.levels,
          selected: selected,
          label: (level) => level,
          description: (level) =>
              ProfileOptions.experienceDescriptions[Routine.levels.indexOf(
                level,
              )],
          onSelected: (level) {
            profile.experience = level;
            onChanged();
          },
        ),
      ],
    );
  }
}
