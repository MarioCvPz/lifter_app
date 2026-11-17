import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/catalog.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/home/home_screen.dart';
import 'package:lifter_app/screens/nutrition/food_catalog_screen.dart';
import 'package:lifter_app/screens/nutrition/nutrition_screen.dart';

import 'helpers.dart';

void main() {
  test('CP-04 Calorías y macros del día según los gramos registrados', () {
    final today = DateTime.now();
    final store = AppStore()
      ..user = profile(weightKg: 80, goal: TrainingGoal.muscleGain)
      ..nutritionLogs.addAll([
        NutritionEntry(id: '1', food: chicken, grams: 200, date: today),
        NutritionEntry(id: '2', food: rice, grams: 150, date: today),
        // De ayer: no cuenta para hoy.
        NutritionEntry(
          id: '3',
          food: rice,
          grams: 500,
          date: today.subtract(const Duration(days: 1)),
        ),
      ]);

    final m = store.macrosFor(today);
    expect(m.kcal, closeTo(220 + 195, 0.01));
    expect(m.protein, closeTo(46 + 4.05, 0.01));
    expect(m.carbs, closeTo(42, 0.01));

    // Objetivo con NutritionCalculator. El perfil usa los valores por
    // defecto: hombre, 178 cm, sin fecha de nacimiento (30 años) y
    // sedentario (× 1,3).
    // Basal: 10 × 80 + 6,25 × 178 − 5 × 30 + 5 = 1.767,5 kcal.
    // Mantenimiento: 1.767,5 × 1,3 = 2.297,75; + 250 (ganar masa) = 2.548.
    // Proteína: 1,8 × min(80; 25 × 1,78²) = 1,8 × 79,21 = 143 g.
    final t = store.macroTargets();
    expect(t.kcal, closeTo(2548, 0.01));
    expect(t.protein, 143);
  });

  testWidgets('CP-05 Agua: sumar y quitar un vaso', (tester) async {
    final store = AppStore();
    await pumpScreen(tester, store, const HomeScreen());

    await tester.tap(find.byTooltip('Añadir 250 ml'));
    await tester.pump();
    await tester.tap(find.byTooltip('Añadir 250 ml'));
    await tester.pumpAndSettle(); // daría tiempo a que entrase un aviso
    expect(store.waterMl, 500);

    // Sin aviso abajo: el cambio se ve en la cifra.
    expect(find.byType(SnackBar), findsNothing);
    // Sin perfil, el objetivo es 2,6 L (75 kg por defecto).
    expect(find.text('0,5 / 2,6 L', findRichText: true), findsOneWidget);

    // El botón − quita un vaso…
    await tester.tap(find.byTooltip('Quitar 250 ml'));
    await tester.pump();
    expect(store.waterMl, 250);

    // …y otro, y ya no baja de 0.
    await tester.tap(find.byTooltip('Quitar 250 ml'));
    await tester.pump();
    expect(store.waterMl, 0);
    store.addWater(-250);
    expect(store.waterMl, 0);
    final minus = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.remove),
    );
    expect(minus.onPressed, isNull);
  });

  testWidgets('Catálogo de alimentos: vacío y búsqueda', (tester) async {
    final store = AppStore();
    await pumpScreen(tester, store, _catalogScreen());
    expect(
      find.textContaining('El catálogo de alimentos está vacío'),
      findsOneWidget,
    );

    // Con alimentos en el catálogo (como si hubieran llegado de Firestore).
    final withFoods = AppStore()..foods.addAll([chicken, rice]);
    await pumpScreen(tester, withFoods, _catalogScreen());
    expect(find.text('Pechuga de pollo'), findsOneWidget);
    expect(find.text('Arroz blanco cocido'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'arroz');
    await tester.pump();
    expect(find.text('Pechuga de pollo'), findsNothing);
    expect(find.text('Arroz blanco cocido'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'xyz');
    await tester.pump();
    expect(
      find.text('Ningún alimento coincide con la búsqueda.'),
      findsOneWidget,
    );
  });

  test('Filtro de alimentos: por nombre sin tildes y por categoría', () {
    const banana = Food(
      id: 'f4',
      name: 'Plátano',
      kcalPer100: 89,
      proteinPer100: 1.1,
      carbsPer100: 23,
      fatPer100: 0.3,
      category: FoodCategory.fruits,
    );
    const meat = Food(
      id: 'f1',
      name: 'Pechuga de pollo',
      kcalPer100: 110,
      proteinPer100: 23,
      carbsPer100: 0,
      fatPer100: 1.5,
      category: FoodCategory.meat,
    );
    final foods = [meat, banana];

    // Sin filtros: todos, ordenados por nombre.
    expect(filterFoods(foods), [meat, banana]);
    // "platano" encuentra "Plátano" aunque no lleve tilde.
    expect(filterFoods(foods, query: 'PLATANO'), [banana]);
    expect(filterFoods(foods, category: FoodCategory.meat), [meat]);
    expect(
      filterFoods(foods, query: 'pollo', category: FoodCategory.fruits),
      isEmpty,
    );
    // Solo salen filtros de categorías que tienen algún alimento.
    expect(foodCategoriesIn(foods), [FoodCategory.meat, FoodCategory.fruits]);
  });

  // Solo se comprueba la hoja de gramos: guardar escribe en Firestore, y
  // las pruebas no usan Firebase.
  testWidgets('Al elegir los gramos se ven las calorías y macros', (
    tester,
  ) async {
    final store = AppStore()..foods.addAll([chicken, rice]);
    await pumpScreen(tester, store, _catalogScreen());

    await tester.tap(find.text('Pechuga de pollo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('150 g'));
    await tester.pump();
    // 150 g de pollo: 165 kcal y 35 g de proteína (34,5 redondeado).
    expect(find.text('165'), findsOneWidget);
    expect(find.text('35 g'), findsOneWidget);
    expect(_addButton(tester).onPressed, isNotNull);
  });

  testWidgets('Los gramos tienen que ser mayores que 0', (tester) async {
    final store = AppStore()..foods.add(chicken);
    await pumpScreen(tester, store, _catalogScreen());

    await tester.tap(find.text('Pechuga de pollo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '0');
    await tester.pump();
    expect(find.text('Escribe una cantidad mayor que 0'), findsOneWidget);

    // Con una cantidad no válida el botón está desactivado.
    expect(_addButton(tester).onPressed, isNull);
  });

  testWidgets('Nutrición sin registros muestra el aviso y el botón', (
    tester,
  ) async {
    await pumpScreen(tester, AppStore(), const NutritionScreen());
    expect(find.text('No hay alimentos registrados este día.'), findsOneWidget);
    expect(find.text('Añadir alimento'), findsOneWidget);
  });
}

FoodCatalogScreen _catalogScreen() =>
    FoodCatalogScreen(day: DateTime.now(), dayLabel: 'Hoy');

/// Botón "Añadir" de la hoja de gramos.
FilledButton _addButton(WidgetTester tester) => tester.widget<FilledButton>(
  find.ancestor(of: find.text('Añadir'), matching: find.byType(FilledButton)),
);
