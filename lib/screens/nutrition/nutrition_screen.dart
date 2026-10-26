import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/catalog.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _query = TextEditingController();
  DateTime _day = DateTime.now();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _isToday => DateUtils.isSameDay(_day, DateTime.now());

  void _moveDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
  }

  String _dayLabel() {
    final now = DateTime.now();
    if (_isToday) return 'Hoy';
    if (DateUtils.isSameDay(_day, now.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    }
    return '${_day.day.toString().padLeft(2, '0')}/'
        '${_day.month.toString().padLeft(2, '0')}/${_day.year}';
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final macros = store.macrosFor(_day);
    final targets = store.macroTargets();
    final logs = store.nutritionFor(_day);
    final q = _query.text.trim().toLowerCase();
    final foods = foodCatalog
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: const BrandAppBar(title: 'Nutrición', help: HelpTopic.nutrition),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Día anterior',
                onPressed: () => _moveDay(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _dayLabel(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Día siguiente',
                onPressed: _isToday ? null : () => _moveDay(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _macroRow('Calorías', macros.kcal, targets.kcal, 'kcal'),
                  _macroRow('Proteínas', macros.protein, targets.protein, 'g'),
                  _macroRow('Hidratos', macros.carbs, targets.carbs, 'g'),
                  _macroRow('Grasas', macros.fat, targets.fat, 'g'),
                  const SizedBox(height: 4),
                  Text(
                    'Objetivo orientativo según tu peso y objetivo del perfil.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _isToday ? 'Registros de hoy' : 'Registros del día',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            const Text('No hay alimentos registrados este día.'),
          for (final e in logs)
            Card(
              child: ListTile(
                title: Text(e.food.name),
                subtitle: Text(
                  '${e.grams.toStringAsFixed(0)} g · ${e.kcal.toStringAsFixed(0)} kcal',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => store.removeNutrition(e.id),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            'Catálogo de alimentos',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Buscar alimento',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 8),
          for (final food in foods)
            Card(
              child: ListTile(
                title: Text(food.name),
                subtitle: Text(
                  '${food.kcalPer100.toStringAsFixed(0)} kcal / 100 g',
                ),
                trailing: const Icon(Icons.add),
                onTap: () => _addFood(store, food),
              ),
            ),
        ],
      ),
    );
  }

  Widget _macroRow(String label, double value, double target, String unit) {
    final progress = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final over = value > target * 1.05;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                '${value.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: over ? scheme.error : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
            color: over ? scheme.error : null,
          ),
        ],
      ),
    );
  }

  Future<void> _addFood(AppStore store, Food food) async {
    final g = await showDialog<double>(
      context: context,
      builder: (_) => _GramsDialog(food: food),
    );
    if (g == null || g <= 0) return;

    // Se apunta en el día que se está viendo, con la hora actual.
    final now = DateTime.now();
    store.addNutrition(
      NutritionEntry(
        id: now.millisecondsSinceEpoch.toString(),
        food: food,
        grams: g,
        date: DateTime(
          _day.year,
          _day.month,
          _day.day,
          now.hour,
          now.minute,
          now.second,
        ),
      ),
    );
  }
}

/// Pide los gramos de un alimento. Devuelve null si se cancela.
///
/// El controlador vive en el State del diálogo para liberarlo cuando el
/// diálogo ya se ha cerrado del todo (no al acabar showDialog, que vuelve
/// antes de que termine la animación de cierre).
class _GramsDialog extends StatefulWidget {
  const _GramsDialog({required this.food});

  final Food food;

  @override
  State<_GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<_GramsDialog> {
  final _grams = TextEditingController(text: '100');

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, double.tryParse(_grams.text.replaceAll(',', '.')));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food.name),
      content: TextField(
        controller: _grams,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Cantidad (gramos)'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Añadir')),
      ],
    );
  }
}
