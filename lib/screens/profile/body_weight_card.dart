import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/log_value_sheet.dart';
import 'weight_chart.dart';
import 'weight_history_screen.dart';

/// Tarjeta "Peso corporal" de Perfil: el último peso, su fecha y el
/// gráfico de los últimos 12 registros. Al tocarla se abre el historial.
/// Sin registros, un texto y el botón "Registrar peso".
class BodyWeightCard extends StatelessWidget {
  const BodyWeightCard({super.key, required this.store});

  final AppStore store;

  void _openHistory(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const WeightHistoryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // La lista va del más reciente al más antiguo.
    final latest = store.weights.isEmpty ? null : store.weights.first;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: latest == null ? null : () => _openHistory(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.monitor_weight_outlined,
                    size: 20,
                    color: AppTheme.coral,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Peso corporal', style: text.titleMedium),
                  ),
                  if (latest != null)
                    Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              if (latest == null)
                _NoWeights(onRegister: () => showWeightSheet(context, store))
              else ...[
                Text.rich(
                  TextSpan(
                    text: '${formatKg(latest.kg)} kg',
                    style: text.headlineMedium,
                    children: [
                      TextSpan(
                        text: '  ${shortDate(latest.date)}',
                        style: text.labelMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                WeightChart(
                  values: [for (final e in store.recentWeights()) e.kg],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoWeights extends StatelessWidget {
  const _NoWeights({required this.onRegister});

  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Todavía no has registrado tu peso. Apúntalo de vez en cuando para '
          'ver cómo cambia.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onRegister,
          icon: const Icon(Icons.add),
          label: const Text('Registrar peso'),
        ),
      ],
    );
  }
}
