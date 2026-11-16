import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/catalog.dart';
import '../../models/models.dart';
import 'add_food_sheet.dart';
import 'food_category_icon.dart';

/// Catálogo de alimentos: buscador, filtros por categoría y lista. Al tocar
/// un alimento se eligen los gramos y se apunta en [day]. La pantalla sigue
/// abierta para poder añadir varios alimentos seguidos.
class FoodCatalogScreen extends StatefulWidget {
  const FoodCatalogScreen({
    super.key,
    required this.day,
    required this.dayLabel,
  });

  /// Día en el que se apuntan los alimentos.
  final DateTime day;

  /// Texto del día ("Hoy", "Ayer" o la fecha) para el título.
  final String dayLabel;

  @override
  State<FoodCatalogScreen> createState() => _FoodCatalogScreenState();
}

class _FoodCatalogScreenState extends State<FoodCatalogScreen> {
  final _query = TextEditingController();

  /// Categoría elegida en los filtros (null = todas).
  FoodCategory? _category;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _add(AppStore store, Food food) async {
    final messenger = ScaffoldMessenger.of(context);
    final grams = await AddFoodSheet.show(context, food);
    if (grams == null) return;

    // Se apunta en el día elegido, con la hora actual.
    final now = DateTime.now();
    final day = widget.day;
    store.addNutrition(
      NutritionEntry(
        id: now.millisecondsSinceEpoch.toString(),
        food: food,
        grams: grams,
        date: DateTime(
          day.year,
          day.month,
          day.day,
          now.hour,
          now.minute,
          now.second,
        ),
      ),
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text('Añadido: ${food.name} (${grams.toStringAsFixed(0)} g)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final foods = filterFoods(
      store.foods,
      query: _query.text,
      category: _category,
    );

    return Scaffold(
      appBar: AppBar(title: Text('Añadir alimento · ${widget.dayLabel}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar alimento',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _query.clear()),
                      ),
              ),
            ),
          ),
          _CategoryFilters(
            categories: foodCategoriesIn(store.foods),
            selected: _category,
            onSelected: (c) => setState(() => _category = c),
          ),
          Expanded(
            child: _FoodList(
              foods: foods,
              catalogEmpty: store.foods.isEmpty,
              onTap: (food) => _add(store, food),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila deslizable de chips: "Todos" y una por categoría, con su icono.
class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<FoodCategory> categories;
  final FoodCategory? selected;
  final ValueChanged<FoodCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(null, Icons.apps, 'Todos'),
          for (final c in categories) _chip(c, c.icon, c.label),
        ],
      ),
    );
  }

  Widget _chip(FoodCategory? category, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected == category,
        showCheckmark: false,
        onSelected: (_) => onSelected(category),
      ),
    );
  }
}

/// Lista de resultados, o un mensaje si no hay ninguno.
class _FoodList extends StatelessWidget {
  const _FoodList({
    required this.foods,
    required this.catalogEmpty,
    required this.onTap,
  });

  final List<Food> foods;
  final bool catalogEmpty;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) {
    if (catalogEmpty || foods.isEmpty) {
      return _EmptyMessage(
        catalogEmpty
            ? 'El catálogo de alimentos está vacío. Un admin tiene que '
                  'cargarlo desde Administración.'
            : 'Ningún alimento coincide con la búsqueda.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: foods.length,
      itemBuilder: (_, i) => _FoodTile(food: foods[i], onTap: onTap),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.onTap});

  final Food food;
  final ValueChanged<Food> onTap;

  @override
  Widget build(BuildContext context) {
    String n(double v) => v.toStringAsFixed(v % 1 == 0 ? 0 : 1);
    return Card(
      child: ListTile(
        leading: FoodAvatar(food.category),
        title: Text(food.name),
        subtitle: Text(
          '${n(food.kcalPer100)} kcal · P ${n(food.proteinPer100)} · '
          'H ${n(food.carbsPer100)} · G ${n(food.fatPer100)} (100 g)',
        ),
        trailing: Icon(
          Icons.add_circle,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        onTap: () => onTap(food),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
