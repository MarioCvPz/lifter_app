import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/coach_badge.dart';

/// Franja de hoy: calorías y agua en dos columnas iguales (título con
/// icono, cifra y barra), para que las dos barras queden alineadas.
class TodayStrip extends StatelessWidget {
  const TodayStrip({super.key, required this.store, this.onOpenNutrition});

  final AppStore store;

  /// Se llama al tocar las calorías (abre la pestaña Nutrición).
  final VoidCallback? onOpenNutrition;

  static const _glassMl = 250;

  /// Suma un vaso. El cambio se ve en la cifra y en la barra (para
  /// deshacerlo está el botón −). Solo sale un aviso abajo si este vaso
  /// cruza un límite ("¡Objetivo de agua cumplido!").
  void _addGlass(BuildContext context) {
    final before = store.waterMl;
    store.addWater(_glassMl);
    final message = store.waterMessage(before, store.waterMl);
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final kcal = store.macrosFor(DateTime.now()).kcal;
    final kcalGoal = store.macroTargets().kcal;
    final waterGoal = store.waterGoalMl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _card(context, kcal: kcal, kcalGoal: kcalGoal, waterGoal: waterGoal),
        // Las calorías las ha fijado el entrenador.
        if (store.nutritionByCoach)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: CoachBadge(label: store.coachLabel),
          ),
      ],
    );
  }

  /// La tarjeta con las calorías y el agua de hoy.
  Widget _card(
    BuildContext context, {
    required double kcal,
    required double kcalGoal,
    required int waterGoal,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _TodayStat(
                icon: Icons.local_fire_department,
                iconColor: scheme.tertiary,
                title: 'Calorías',
                value: kcal.toStringAsFixed(0),
                unit: '/ ${kcalGoal.toStringAsFixed(0)} kcal',
                progress: _ratio(kcal, kcalGoal),
                onTap: onOpenNutrition,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TodayStat(
                icon: Icons.water_drop,
                iconColor: scheme.primaryFixed,
                title: 'Agua',
                value: formatLiters(store.waterMl),
                unit: '/ ${formatLiters(waterGoal)} L',
                progress: _ratio(
                  store.waterMl.toDouble(),
                  waterGoal.toDouble(),
                ),
                trailing: _WaterButtons(
                  // En 0 se desactiva: nunca puede salir un número negativo.
                  onRemove: store.waterMl == 0
                      ? null
                      : () => store.addWater(-_glassMl),
                  onAdd: () => _addGlass(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parte de la barra que se llena (entre 0 y 1).
  static double _ratio(double value, double goal) =>
      goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0);
}

/// Una columna de la franja. Las dos usan este mismo widget, así que tienen
/// la misma estructura y altura.
class _TodayStat extends StatelessWidget {
  const _TodayStat({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.unit,
    required this.progress,
    this.trailing,
    this.onTap,
  });

  /// Alto fijo del título: con o sin botones, las cifras y las barras
  /// empiezan a la misma altura en las dos columnas.
  static const _headerHeight = 36.0;

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String unit;
  final double progress;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final extra = trailing;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _headerHeight,
            child: Row(
              children: [
                Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                ),
                // `?extra`: se añade a la lista solo si no es null (es lo
                // mismo que `if (extra != null) extra`).
                ?extra,
              ],
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: value,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ThinProgress(value: progress, color: iconColor),
        ],
      ),
    );
  }
}

/// Botones − y + del agua (un vaso de 250 ml).
class _WaterButtons extends StatelessWidget {
  const _WaterButtons({required this.onRemove, required this.onAdd});

  final VoidCallback? onRemove;
  final VoidCallback onAdd;

  // Más pequeños de lo normal para que quepan junto al título.
  static const _density = VisualDensity(horizontal: -4, vertical: -4);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: 'Quitar 250 ml',
          visualDensity: _density,
          iconSize: 16,
          onPressed: onRemove,
          icon: const Icon(Icons.remove),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Añadir 250 ml',
          visualDensity: _density,
          iconSize: 16,
          onPressed: onAdd,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
