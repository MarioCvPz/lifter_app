import 'package:flutter/material.dart';

import '../../models/models.dart';

/// Icono de cada categoría de alimento. Va aquí y no en el modelo porque los
/// iconos son cosa de la interfaz (el modelo no depende de Flutter).
///
/// Es una extensión: añade el getter `icon` a [FoodCategory] sin tocar el
/// enum, como hace [AppStoreStats] con el AppStore.
extension FoodCategoryIcon on FoodCategory {
  IconData get icon => switch (this) {
    FoodCategory.meat => Icons.kebab_dining,
    FoodCategory.fish => Icons.set_meal,
    FoodCategory.eggsDairy => Icons.egg_alt,
    FoodCategory.grains => Icons.bakery_dining,
    FoodCategory.legumes => Icons.soup_kitchen,
    FoodCategory.vegetables => Icons.eco,
    FoodCategory.fruits => Icons.spa,
    FoodCategory.nuts => Icons.grain,
    FoodCategory.fats => Icons.water_drop,
    FoodCategory.drinks => Icons.local_drink,
    FoodCategory.sweets => Icons.cookie,
    FoodCategory.supplements => Icons.bolt,
    FoodCategory.other => Icons.restaurant,
  };
}

/// Círculo con el icono de la categoría del alimento, para las listas.
class FoodAvatar extends StatelessWidget {
  const FoodAvatar(this.category, {super.key});

  final FoodCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.18),
      foregroundColor: scheme.primary,
      child: Icon(category.icon, size: 20),
    );
  }
}
