import 'package:flutter/material.dart';

import '../../models/models.dart';
import 'food_category_icon.dart';

/// Hoja inferior para elegir cuántos gramos se añaden de [food]. Enseña al
/// momento las calorías y macros de esa cantidad. Devuelve los gramos, o
/// null si se cierra sin añadir.
///
/// El controlador vive en el State de la hoja para liberarlo cuando ya se ha
/// cerrado del todo (no al acabar showModalBottomSheet, que vuelve antes de
/// que termine la animación de cierre).
class AddFoodSheet extends StatefulWidget {
  const AddFoodSheet({super.key, required this.food});

  final Food food;

  /// Abre la hoja y espera a que el usuario elija los gramos.
  static Future<double?> show(BuildContext context, Food food) {
    return showModalBottomSheet<double>(
      context: context,
      // Necesario para que la hoja suba cuando aparece el teclado.
      isScrollControlled: true,
      builder: (_) => AddFoodSheet(food: food),
    );
  }

  @override
  State<AddFoodSheet> createState() => _AddFoodSheetState();
}

class _AddFoodSheetState extends State<AddFoodSheet> {
  /// Cantidades típicas para no tener que escribir.
  static const _quickGrams = [50, 100, 150, 200];

  /// Más de 5 kg de un alimento de una vez es casi seguro un error.
  static const _maxGrams = 5000;

  final _grams = TextEditingController(text: '100');

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double? get _parsedGrams => double.tryParse(_grams.text.replaceAll(',', '.'));

  /// Mensaje de error de la cantidad escrita, o null si es válida.
  String? get _error {
    final g = _parsedGrams;
    if (g == null || g <= 0) return 'Escribe una cantidad mayor que 0';
    if (g > _maxGrams) return 'Como mucho $_maxGrams g';
    return null;
  }

  void _setGrams(int grams) {
    setState(() => _grams.text = '$grams');
  }

  void _submit() {
    if (_error != null) return;
    Navigator.pop(context, _parsedGrams);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Deja sitio al teclado cuando está abierto.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: FoodAvatar(widget.food.category),
            title: Text(widget.food.name, style: text.titleMedium),
            subtitle: Text(widget.food.category.label),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _grams,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Cantidad',
              suffixText: 'g',
              prefixIcon: const Icon(Icons.scale),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final g in _quickGrams)
                ActionChip(label: Text('$g g'), onPressed: () => _setGrams(g)),
            ],
          ),
          const SizedBox(height: 16),
          _Preview(
            food: widget.food,
            grams: _error == null ? _parsedGrams : null,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _error == null ? _submit : null,
              icon: const Icon(Icons.add),
              label: const Text('Añadir'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Calorías y macros de [grams] gramos de [food] (guiones si la cantidad no
/// es válida).
class _Preview extends StatelessWidget {
  const _Preview({required this.food, required this.grams});

  final Food food;
  final double? grams;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Se usa un NutritionEntry de prueba para reutilizar sus getters de
    // calorías y macros (los mismos que se usan al guardar).
    final g = grams;
    final entry = g == null
        ? null
        : NutritionEntry(id: '', food: food, grams: g, date: DateTime.now());
    String show(double? value) =>
        value == null ? '–' : value.toStringAsFixed(0);

    return Row(
      children: [
        _PreviewValue(
          icon: Icons.local_fire_department,
          label: 'kcal',
          value: show(entry?.kcal),
          color: scheme.primaryContainer,
        ),
        _PreviewValue(
          icon: Icons.egg_alt,
          label: 'Proteínas',
          value: '${show(entry?.protein)} g',
          color: scheme.primary,
        ),
        _PreviewValue(
          icon: Icons.bakery_dining,
          label: 'Hidratos',
          value: '${show(entry?.carbs)} g',
          color: scheme.tertiary,
        ),
        _PreviewValue(
          icon: Icons.water_drop,
          label: 'Grasas',
          value: '${show(entry?.fat)} g',
          color: scheme.secondary,
        ),
      ],
    );
  }
}

class _PreviewValue extends StatelessWidget {
  const _PreviewValue({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: text.titleMedium),
          Text(label, style: text.labelSmall),
        ],
      ),
    );
  }
}
