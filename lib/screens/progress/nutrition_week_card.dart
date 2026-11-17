import 'package:flutter/material.dart';

import '../../data/week_summary.dart';
import 'day_circles.dart';

/// Tarjeta "Nutrición" ("5 de 7 días") con un círculo por día:
/// cumplido = relleno verde; registrado = anillo verde; vacío = anillo
/// gris. Debajo, la leyenda.
class NutritionWeekCard extends StatelessWidget {
  const NutritionWeekCard({super.key, required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onTarget = DayCircle(fill: scheme.secondary);
    final logged = DayCircle(border: scheme.secondary);
    final empty = DayCircle(border: scheme.outlineVariant);

    return WeekDaysCard(
      title: 'Nutrición',
      count: '${summary.nutritionDaysLogged} de ${WeekSummary.daysInWeek} días',
      circles: [
        for (final status in summary.nutritionStatuses)
          switch (status) {
            NutritionDayStatus.onTarget => onTarget,
            NutritionDayStatus.logged => logged,
            NutritionDayStatus.empty => empty,
          },
      ],
      footer: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          LegendItem(circle: onTarget, label: 'Objetivo cumplido'),
          LegendItem(circle: logged, label: 'Registrado'),
        ],
      ),
    );
  }
}
