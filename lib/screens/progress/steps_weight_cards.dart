import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/week_summary.dart';
import '../../theme/app_theme.dart';
import '../../widgets/log_value_sheet.dart';
import 'score_card.dart';

/// Las dos tarjetas en fila: pasos de media y peso medio. IntrinsicHeight
/// hace que las dos midan lo mismo aunque una tenga más texto.
class StepsWeightRow extends StatelessWidget {
  const StepsWeightRow({super.key, required this.summary, required this.store});

  final WeekSummary summary;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final steps = summary.averageSteps;
    final weight = summary.averageWeight;
    final change = summary.weightChange;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _MetricCard(
              icon: Icons.directions_walk,
              color: AppTheme.stepsBlue,
              title: 'Pasos de media',
              value: steps == null ? '—' : formatThousands(steps),
              detail: 'objetivo ${formatThousands(summary.stepsGoal)}',
              buttonLabel: 'Registrar pasos',
              onPressed: () => showStepsSheet(context, store),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _MetricCard(
              icon: Icons.monitor_weight_outlined,
              color: AppTheme.coral,
              title: 'Peso medio',
              value: weight == null ? '—' : '${formatKg(weight)} kg',
              detail: _weightDetail(weight, change),
              // La flecha solo sale si hay con qué comparar.
              detailIcon: weight != null && change != null
                  ? trendIcon(change)
                  : null,
              buttonLabel: 'Registrar peso',
              onPressed: () => showWeightSheet(context, store),
            ),
          ),
        ],
      ),
    );
  }

  /// "0,3 kg vs semana anterior" (la flecha va aparte, en [trendIcon]);
  /// "Sin registros" si no hay pesos esta semana, o un aviso si no los hay
  /// en la anterior para comparar.
  static String _weightDetail(double? weight, double? change) {
    if (weight == null) return 'Sin registros';
    if (change == null) return 'Sin datos de la semana anterior';
    return '${formatKg(change.abs())} kg vs semana anterior';
  }
}

/// Tarjeta pequeña con icono, título, cifra grande, detalle y un botón.
class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.detail,
    this.detailIcon,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String detail;

  /// Icono opcional delante del detalle (la flecha del peso).
  final IconData? detailIcon;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _Detail(
              text: detail,
              icon: detailIcon,
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            // Empuja el botón abajo para que quede alineado en las dos.
            const Spacer(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.add, size: 18),
                // scaleDown: solo encoge el texto si no cabe. Sin él,
                // FittedBox también lo agranda y la tarjeta se desborda.
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(buttonLabel),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Texto pequeño de detalle, con un icono delante si lo hay. El icono
/// mide lo mismo que la letra para que no cambie la altura de la línea.
class _Detail extends StatelessWidget {
  const _Detail({required this.text, required this.icon, required this.style});

  final String text;
  final IconData? icon;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    if (icon == null) return Text(text, style: style);
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Icon(icon, size: style?.fontSize, color: style?.color),
          ),
          const TextSpan(text: ' '),
          TextSpan(text: text),
        ],
      ),
      style: style,
    );
  }
}
