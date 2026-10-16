import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final today = DateTime.now();
    final macros = store.macrosFor(today);
    final logs = store.nutritionFor(today);
    final q = _query.text.trim().toLowerCase();
    final foods = store.foods
        .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Hoy', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _macroRow('Calorías', '${macros.kcal.toStringAsFixed(0)} kcal'),
                  _macroRow(
                    'Proteínas',
                    '${macros.protein.toStringAsFixed(0)} g',
                  ),
                  _macroRow(
                    'Hidratos',
                    '${macros.carbs.toStringAsFixed(0)} g',
                  ),
                  _macroRow('Grasas', '${macros.fat.toStringAsFixed(0)} g'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Registros de hoy', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (logs.isEmpty) const Text('Todavía no has registrado alimentos.'),
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

  Widget _macroRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _addFood(AppStore store, Food food) async {
    final grams = TextEditingController(text: '100');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(food.name),
          content: TextField(
            controller: grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad (gramos)'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Añadir'),
            ),
          ],
        );
      },
    );

    if (ok == true) {
      final g = double.tryParse(grams.text.replaceAll(',', '.')) ?? 0;
      if (g > 0) {
        store.addNutrition(
          NutritionEntry(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            food: food,
            grams: g,
            date: DateTime.now(),
          ),
        );
      }
    }
    grams.dispose();
  }
}
