import 'package:flutter/material.dart';

import '../../models/models.dart';

/// Resumen de un día: anillo con las calorías y una barra por macro, frente
/// al objetivo. Si un valor pasa del objetivo (con un 5 % de margen), se
/// pinta en rojo.
class MacroSummaryCard extends StatelessWidget {
  const MacroSummaryCard({
    super.key,
    required this.macros,
    required this.targets,
  });

  final DailyMacros macros;
  final DailyMacros targets;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _CaloriesRing(value: macros.kcal, target: targets.kcal),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    children: [
                      _MacroBar(
                        icon: Icons.egg_alt,
                        label: 'Proteínas',
                        value: macros.protein,
                        target: targets.protein,
                        color: scheme.primary,
                      ),
                      _MacroBar(
                        icon: Icons.bakery_dining,
                        label: 'Hidratos',
                        value: macros.carbs,
                        target: targets.carbs,
                        color: scheme.tertiary,
                      ),
                      _MacroBar(
                        icon: Icons.water_drop,
                        label: 'Grasas',
                        value: macros.fat,
                        target: targets.fat,
                        color: scheme.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: scheme.outline),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Objetivo orientativo según tus datos, tu actividad '
                    'y tu objetivo del perfil.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Proporción de [value] sobre [target], entre 0 y 1, para las barras.
double _progress(double value, double target) =>
    target <= 0 ? 0 : (value / target).clamp(0.0, 1.0);

/// True si [value] se pasa del [target] en más de un 5 %.
bool _isOver(double value, double target) => value > target * 1.05;

class _CaloriesRing extends StatelessWidget {
  const _CaloriesRing({required this.value, required this.target});

  final double value;
  final double target;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final over = _isOver(value, target);
    return SizedBox(
      width: 112,
      height: 112,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: _progress(value, target),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: scheme.surfaceContainerHighest,
              color: over ? scheme.error : scheme.primaryContainer,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_fire_department,
                size: 18,
                color: over ? scheme.error : scheme.primaryContainer,
              ),
              Text(
                value.toStringAsFixed(0),
                style: text.titleLarge?.copyWith(
                  color: over ? scheme.error : null,
                ),
              ),
              Text(
                'de ${target.toStringAsFixed(0)} kcal',
                style: text.labelSmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.icon,
    required this.label,
    required this.value,
    required this.target,
    required this.color,
  });

  final IconData icon;
  final String label;
  final double value;
  final double target;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final over = _isOver(value, target);
    final barColor = over ? scheme.error : color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: barColor),
              const SizedBox(width: 6),
              Expanded(child: Text(label)),
              Text(
                '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} g',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: over ? scheme.error : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _progress(value, target),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: barColor,
          ),
        ],
      ),
    );
  }
}
