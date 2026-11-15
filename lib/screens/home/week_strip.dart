import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/app_theme.dart';

/// Semana actual de lunes a domingo: siete botones con el número del día.
/// Los días de entreno del plan llevan un punto, hoy tiene borde coral y el
/// día seleccionado va relleno de coral.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    super.key,
    required this.trainingWeekdays,
    required this.selectedWeekday,
    required this.onSelected,
  });

  /// Días de entreno del plan (1 = lunes).
  final Set<int> trainingWeekdays;
  final int selectedWeekday;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    return Row(
      children: [
        for (var weekday = 1; weekday <= 7; weekday++)
          Expanded(
            child: _DayButton(
              letter: ProfileOptions.weekdayLabels[weekday - 1],
              dayOfMonth: monday.add(Duration(days: weekday - 1)).day,
              isToday: weekday == now.weekday,
              isSelected: weekday == selectedWeekday,
              isTrainingDay: trainingWeekdays.contains(weekday),
              onTap: () => onSelected(weekday),
            ),
          ),
      ],
    );
  }
}

/// Un día de la semana: letra, número y punto si es de entreno.
class _DayButton extends StatelessWidget {
  const _DayButton({
    required this.letter,
    required this.dayOfMonth,
    required this.isToday,
    required this.isSelected,
    required this.isTrainingDay,
    required this.onTap,
  });

  final String letter;
  final int dayOfMonth;
  final bool isToday;
  final bool isSelected;
  final bool isTrainingDay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Sobre el relleno coral, el texto va en blanco.
    final textColor = isSelected ? Colors.white : scheme.onSurface;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      side: isToday
          ? const BorderSide(color: AppTheme.coral, width: 2)
          : BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: isSelected ? AppTheme.coral : scheme.surfaceContainerHigh,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  letter,
                  style: text.labelSmall?.copyWith(
                    color: isSelected ? Colors.white : scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '$dayOfMonth',
                  style: text.labelLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                _Dot(
                  color: isTrainingDay
                      ? (isSelected ? Colors.white : scheme.secondary)
                      : Colors.transparent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}
