import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 6: qué días de la semana puede entrenar y cuánto dura cada
/// sesión.
class AvailabilityStep extends StatelessWidget {
  const AvailabilityStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  /// Mensaje de error, o null si hay entre 2 y 6 días elegidos.
  static String? validate(UserProfile profile) {
    final days = profile.trainingDays.length;
    if (days < ProfileOptions.minTrainingDays ||
        days > ProfileOptions.maxTrainingDays) {
      return 'Elige entre ${ProfileOptions.minTrainingDays} y '
          '${ProfileOptions.maxTrainingDays} días.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final days = profile.trainingDays.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cuándo puedes entrenar?',
          subtitle: 'Elige entre 2 y 6 días.',
        ),
        WeekdayPicker(
          selected: profile.trainingDays,
          onChanged: (days) {
            profile.trainingDays = days;
            // Se mantiene a la par para que "Tu plan" recomiende la rutina
            // con los días nuevos antes de guardar.
            profile.daysPerWeek = days.length;
            onChanged();
          },
        ),
        const SizedBox(height: 8),
        Text('Entrenarás $days ${days == 1 ? 'día' : 'días'} por semana'),
        const SizedBox(height: 24),
        Text('Tiempo por sesión', style: text.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final minutes in ProfileOptions.sessionMinutes)
              ChoiceChip(
                label: Text(ProfileOptions.sessionLabel(minutes)),
                selected: profile.sessionMinutes == minutes,
                onSelected: (_) {
                  profile.sessionMinutes = minutes;
                  onChanged();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// Siete botones (L M X J V S D) que se marcan y desmarcan. Los días se
/// guardan como números: 1 = lunes … 7 = domingo. Se usa también en
/// "Editar perfil".
class WeekdayPicker extends StatelessWidget {
  const WeekdayPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<int> selected;

  /// Recibe la lista nueva de días, ordenada.
  final ValueChanged<List<int>> onChanged;

  void _toggle(int day) {
    final days = {...selected};
    if (!days.remove(day)) days.add(day);
    onChanged(days.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    // Wrap en vez de Row: si no caben los siete, pasan a otra línea.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final day in ProfileOptions.trainingDays)
          FilterChip(
            label: Text(ProfileOptions.weekdayLabels[day - 1]),
            showCheckmark: false,
            // Compactos para que quepan los siete en un móvil estrecho.
            visualDensity: VisualDensity.compact,
            labelPadding: const EdgeInsets.symmetric(horizontal: 2),
            selected: selected.contains(day),
            onSelected: (_) => _toggle(day),
          ),
      ],
    );
  }
}
