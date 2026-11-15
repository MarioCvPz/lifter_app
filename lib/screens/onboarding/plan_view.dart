import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import 'onboarding_widgets.dart';

/// Pantalla final del cuestionario, "Tu plan": resume lo que la app ha
/// calculado con las respuestas ([profile]) antes de guardarlas.
class PlanView extends StatelessWidget {
  const PlanView({
    super.key,
    required this.profile,
    required this.plan,
    required this.saving,
    required this.error,
    required this.onStart,
    required this.onChangeAnswers,
  });

  final UserProfile profile;

  /// Plan generado con las respuestas; es el que se guarda al empezar.
  final TrainingPlan plan;

  /// True mientras se guarda: el botón muestra un indicador.
  final bool saving;

  /// Mensaje si no se pudo guardar.
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onChangeAnswers;

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final targets = store.macroTargets(profile);
    final waterLiters = formatLiters(store.waterGoalMlFor(profile));

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              StepHeader(
                title: 'Tu plan, ${profile.name.trim()}',
                subtitle:
                    'Esto es lo que hemos preparado con tus respuestas. '
                    'Podrás cambiarlo cuando quieras desde el Perfil.',
              ),
              _PlanCard(
                icon: Icons.calendar_month,
                title: 'Entrenamiento',
                lines: [
                  _dayNames(profile.trainingDays),
                  '${ProfileOptions.sessionLabel(profile.sessionMinutes)} '
                      'por sesión',
                ],
              ),
              for (final day in plan.days)
                _PlanCard(
                  icon: Icons.fitness_center,
                  title: day.title,
                  lines: _exerciseLines(day),
                ),
              _PlanCard(
                icon: Icons.restaurant,
                title: 'Nutrición diaria',
                lines: [
                  '${targets.kcal.toStringAsFixed(0)} kcal',
                  '${targets.protein.toStringAsFixed(0)} g de proteína',
                ],
              ),
              _PlanCard(
                icon: Icons.water_drop_outlined,
                title: 'Agua',
                lines: ['$waterLiters L al día'],
              ),
            ],
          ),
        ),
        _PlanButtons(
          saving: saving,
          error: error,
          onStart: onStart,
          onChangeAnswers: onChangeAnswers,
        ),
      ],
    );
  }

  /// "1. Press de banca", "2. …". Si el catálogo de Firestore aún no tiene
  /// los ejercicios nuevos, el día sale vacío y se avisa.
  static List<String> _exerciseLines(PlanDay day) {
    if (day.exercises.isEmpty) {
      return const ['Aún no hay ejercicios en el catálogo para este día.'];
    }
    return [
      for (final (i, e) in day.exercises.indexed)
        '${i + 1}. ${e.exercise.name}',
    ];
  }

  /// "L · X · V" a partir de los números de día (1 = lunes).
  static String _dayNames(List<int> days) => [
    for (final day in days) ProfileOptions.weekdayLabels[day - 1],
  ].join(' · ');
}

/// Tarjeta con un icono, un título y una o varias líneas de texto.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.icon,
    required this.title,
    required this.lines,
  });

  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final line in lines)
                    if (line.isNotEmpty) Text(line, style: text.bodyLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje de error (si lo hay) y los botones "Empezar" y "Cambiar
/// respuestas".
class _PlanButtons extends StatelessWidget {
  const _PlanButtons({
    required this.saving,
    required this.error,
    required this.onStart,
    required this.onChangeAnswers,
  });

  final bool saving;
  final String? error;
  final VoidCallback onStart;
  final VoidCallback onChangeAnswers;

  @override
  Widget build(BuildContext context) {
    final message = error;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ),
          FilledButton(
            // null desactiva el botón mientras se guarda.
            onPressed: saving ? null : onStart,
            child: saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Empezar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: saving ? null : onChangeAnswers,
            child: const Text('Cambiar respuestas'),
          ),
        ],
      ),
    );
  }
}
