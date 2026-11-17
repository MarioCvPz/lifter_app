import 'package:flutter/material.dart';

/// Selector "‹ Esta semana ›". Las flechas se desactivan (onPrevious u
/// onNext a null) cuando no se puede ir más allá.
class WeekSelector extends StatelessWidget {
  const WeekSelector({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  // Más juntos de lo normal para que quepan junto al título.
  static const _density = VisualDensity(horizontal: -4, vertical: -4);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Semana anterior',
          visualDensity: _density,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        IconButton(
          tooltip: 'Semana siguiente',
          visualDensity: _density,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
