import 'package:flutter/material.dart';

/// Etiqueta "Ajustado por tu entrenador" que acompaña a un objetivo que ha
/// fijado el entrenador (calorías, proteína o pasos). Si se pasa
/// [onReset] (cuando ya no tiene entrenador), añade el botón
/// "Volver al automático".
class CoachBadge extends StatelessWidget {
  const CoachBadge({super.key, required this.label, this.onReset});

  final String label;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reset = onReset;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        Chip(
          avatar: Icon(
            Icons.sports,
            size: 16,
            color: scheme.onSecondaryContainer,
          ),
          label: Text(label),
          labelStyle: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
          backgroundColor: scheme.secondaryContainer,
          side: BorderSide.none,
          visualDensity: VisualDensity.compact,
        ),
        if (reset != null)
          TextButton(
            onPressed: reset,
            child: const Text('Volver al automático'),
          ),
      ],
    );
  }
}
