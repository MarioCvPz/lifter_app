import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 4: actividad diaria, sin contar el gimnasio.
class ActivityStep extends StatelessWidget {
  const ActivityStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cuánto te mueves en tu día a día?',
          subtitle: 'Sin contar el gimnasio: trabajo, estudios, paseos…',
        ),
        ChoiceList<ActivityLevel>(
          options: ActivityLevel.values,
          selected: profile.activityLevel,
          label: (level) => level.label,
          description: (level) => level.description,
          onSelected: (level) {
            profile.activityLevel = level;
            onChanged();
          },
        ),
      ],
    );
  }
}
