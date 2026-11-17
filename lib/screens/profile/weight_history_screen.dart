import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/log_value_sheet.dart';
import 'weight_chart.dart';

/// Historial de peso: gráfico grande, botón "+ Registrar peso" y la lista de
/// registros (del más reciente al más antiguo). Un registro se borra
/// deslizándolo o con la papelera, siempre con confirmación.
class WeightHistoryScreen extends StatelessWidget {
  const WeightHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final weights = store.weights;

    return Scaffold(
      appBar: AppBar(title: const Text('Peso corporal')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (weights.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: WeightChart(
                  values: [for (final e in store.recentWeights()) e.kg],
                  height: 180,
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showWeightSheet(context, store),
            icon: const Icon(Icons.add),
            label: const Text('Registrar peso'),
          ),
          const SizedBox(height: 16),
          if (weights.isEmpty)
            const Text(
              'No hay registros de peso.',
              textAlign: TextAlign.center,
            ),
          for (final entry in weights) _WeightTile(store: store, entry: entry),
        ],
      ),
    );
  }
}

/// Un registro de la lista. Se puede borrar deslizando hacia la izquierda
/// o con la papelera.
class _WeightTile extends StatelessWidget {
  const _WeightTile({required this.store, required this.entry});

  final AppStore store;
  final WeightEntry entry;

  /// Pregunta antes de borrar. Devuelve true si el usuario confirma.
  Future<bool> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar este peso?'),
        content: Text('${formatKg(entry.kg)} kg · ${_dateLabel(entry.date)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _deleteWithConfirmation(BuildContext context) async {
    if (await _confirmDelete(context)) store.deleteWeight(entry.date);
  }

  /// "10 nov 2026": con el año, porque la lista puede ser larga.
  static String _dateLabel(DateTime date) => '${shortDate(date)} ${date.year}';

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(dayKey(entry.date)),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => store.deleteWeight(entry.date),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppTheme.danger,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${formatKg(entry.kg)} kg'),
        subtitle: Text(_dateLabel(entry.date)),
        trailing: IconButton(
          tooltip: 'Borrar',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _deleteWithConfirmation(context),
        ),
      ),
    );
  }
}
