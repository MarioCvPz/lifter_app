import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/home/home_screen.dart';
import 'package:lifter_app/screens/nutrition/nutrition_screen.dart';

import 'helpers.dart';

void main() {
  test('CP-04 Calorías y macros del día según los gramos registrados', () {
    final today = DateTime.now();
    final store = AppStore()
      ..user = profile(weightKg: 80, goal: 'Hipertrofia')
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

    // Objetivo: 80 kg × 33 kcal × 1,10 (hipertrofia) y 2 g de proteína/kg.
    final t = store.macroTargets();
    expect(t.kcal, closeTo(2904, 0.01));
    expect(t.protein, 160);
  });

  testWidgets('CP-05 Agua: sumar, deshacer y quitar un vaso', (tester) async {
    final store = AppStore();
    await pumpScreen(tester, store, const HomeScreen());

    await tester.tap(find.byTooltip('Añadir 250 ml'));
    await tester.pump();
    await tester.tap(find.byTooltip('Añadir 250 ml'));
    await tester.pumpAndSettle(); // espera a que entre el aviso
    expect(store.waterMl, 500);

    // "Deshacer" del aviso quita el último vaso.
    expect(find.text('Deshacer'), findsOneWidget);
    await tester.tap(find.text('Deshacer'));
    await tester.pump();
    expect(store.waterMl, 250);

    // El botón − quita otro y ya no baja de 0.
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
    await pumpScreen(tester, store, const NutritionScreen());
    expect(
      find.textContaining('El catálogo de alimentos está vacío'),
      findsOneWidget,
    );

    // Con alimentos en el catálogo (como si hubieran llegado de Firestore).
    final withFoods = AppStore()..foods.addAll([chicken, rice]);
    await pumpScreen(tester, withFoods, const NutritionScreen());
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
}
