import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/profile/weight_history_screen.dart';
import 'package:lifter_app/screens/progress/progress_screen.dart';
import 'package:lifter_app/theme/app_theme.dart';

import 'helpers.dart';

void main() {
  group('Peso y pasos', () {
    test('Validación del peso: entre 30 y 250 kg', () {
      expect(WeightEntry.validate(null), isNotNull);
      expect(WeightEntry.validate(29.9), isNotNull);
      expect(WeightEntry.validate(30), isNull);
      expect(WeightEntry.validate(250), isNull);
      expect(WeightEntry.validate(250.1), isNotNull);
    });

    test('Validación de los pasos: entre 0 y 100.000', () {
      expect(StepsEntry.validate(null), isNotNull);
      expect(StepsEntry.validate(-1), isNotNull);
      expect(StepsEntry.validate(0), isNull);
      expect(StepsEntry.validate(100000), isNull);
      expect(StepsEntry.validate(100001), isNotNull);
    });

    test('Un perfil antiguo sin stepsGoal se lee con 10.000', () {
      final old = UserProfile.fromMap({'name': 'Ana', 'email': 'a@a.com'});
      expect(old.stepsGoal, 10000);

      final withGoal = UserProfile.fromMap({'stepsGoal': 8000});
      expect(withGoal.stepsGoal, 8000);
      expect(withGoal.toMap()['stepsGoal'], 8000);
    });

    test('fromMap y toMap de los registros', () {
      final day = DateTime(2026, 11, 17);
      final weight = WeightEntry.fromMap(
        WeightEntry(date: day, kg: 78.4).toMap(),
      );
      expect([weight.date, weight.kg], [day, 78.4]);

      final steps = StepsEntry.fromMap({
        'date': Timestamp.fromDate(day),
        'steps': 8500,
      });
      expect([steps.date, steps.steps], [day, 8500]);
    });

    test('Guardar el peso de hoy: un registro por día y actualiza el '
        'perfil', () {
      final store = AppStore()..user = profile(weightKg: 80);

      expect(store.saveWeight(20), isNotNull); // fuera de rango
      expect(store.weights, isEmpty);
      expect(store.user?.weightKg, 80);

      expect(store.saveWeight(79.5), isNull);
      expect(store.saveWeight(79.3), isNull); // mismo día: sobrescribe
      expect(store.weights, hasLength(1));
      expect(store.weights.first.kg, 79.3);
      expect(store.user?.weightKg, 79.3); // las calorías usan este peso
    });

    test('Guardar los pasos de hoy', () {
      final store = AppStore()..user = profile();

      expect(store.saveSteps(-5), isNotNull);
      expect(store.saveSteps(8000), isNull);
      expect(store.saveSteps(9000), isNull);
      expect(store.steps, hasLength(1));
      expect(store.steps.first.steps, 9000);
    });

    test('Se puede registrar hoy o un día anterior, pero no el futuro ni '
        'hace más de un año', () {
      final now = DateTime(2026, 11, 17);
      expect(validateLogDay(now, now), isNull);
      expect(validateLogDay(DateTime(2026, 11, 16), now), isNull);
      expect(validateLogDay(DateTime(2025, 11, 17), now), isNull); // 365 días
      expect(validateLogDay(DateTime(2025, 11, 16), now), isNotNull);
      expect(validateLogDay(DateTime(2026, 11, 18), now), isNotNull);
    });

    test('Peso de otro día: va en su sitio y solo cambia el perfil si es '
        'el más reciente', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      DateTime daysAgo(int n) =>
          DateTime(today.year, today.month, today.day - n);
      final store = AppStore()..user = profile(weightKg: 80);

      // Ayer, sin nada más: es el más reciente y pasa al perfil.
      expect(store.saveWeight(79, day: daysAgo(1)), isNull);
      expect(store.user?.weightKg, 79);

      // Hoy y luego hace 5 días: el perfil se queda con el de hoy.
      store.saveWeight(78.5);
      expect(store.saveWeight(81, day: daysAgo(5)), isNull);
      expect(store.user?.weightKg, 78.5);
      // La lista sigue ordenada de más reciente a más antiguo.
      expect(
        [for (final e in store.weights) e.date],
        [today, daysAgo(1), daysAgo(5)],
      );

      // Un día futuro no se guarda.
      expect(store.saveWeight(77, day: daysAgo(-1)), isNotNull);
      expect(store.weights, hasLength(3));
    });

    test('Pasos de otro día', () {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      final store = AppStore()..user = profile();

      store.saveSteps(6000);
      expect(store.saveSteps(9000, day: yesterday), isNull);
      expect(store.stepsOn(yesterday)?.steps, 9000);
      expect(store.steps.first.steps, 6000); // el de hoy sigue primero
    });

    test('Al borrar el último peso, el perfil vuelve al anterior', () {
      final store = AppStore()..user = profile(weightKg: 79);
      store.weights.addAll([
        WeightEntry(date: DateTime(2026, 11, 10), kg: 79),
        WeightEntry(date: DateTime(2026, 11, 3), kg: 80),
      ]);

      store.deleteWeight(DateTime(2026, 11, 10));
      expect(store.weights, hasLength(1));
      expect(store.user?.weightKg, 80);
    });
  });

  group('Pantallas', () {
    /// Monta [child] con el tema indicado (claro u oscuro).
    Future<void> pumpWithTheme(
      WidgetTester tester,
      AppStore store,
      Widget child,
      ThemeData theme, {
      double width = 390,
    }) async {
      tester.view.physicalSize = Size(width * 3, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        SessionScope(
          store: store,
          child: MaterialApp(theme: theme, home: child),
        ),
      );
    }

    for (final (name, theme) in [
      ('oscuro', AppTheme.dark()),
      ('claro', AppTheme.light()),
    ]) {
      testWidgets('Progreso se ve sin errores en el tema $name', (
        tester,
      ) async {
        final store = AppStore()..user = profile();
        store.saveSteps(7240);
        store.saveWeight(78.4);
        await pumpWithTheme(tester, store, const ProgressScreen(), theme);

        expect(find.text('Mi semana'), findsOneWidget);
        expect(find.text('Esta semana'), findsOneWidget);
        expect(find.text('NOTA DE LA SEMANA'), findsOneWidget);
        expect(find.text('7.240'), findsOneWidget);
        expect(find.text('78,4 kg'), findsOneWidget);
        expect(find.text('objetivo 10.000'), findsOneWidget);

        // En la semana actual no se puede ir hacia delante.
        final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
        expect(tester.widget<IconButton>(next).onPressed, isNull);
        await tester.tap(find.byTooltip('Semana anterior'));
        await tester.pump();
        expect(find.text('Semana pasada'), findsOneWidget);
        expect(find.text('Sin registros'), findsOneWidget);
      });

      testWidgets('Pasos y peso caben en 360 px en el tema $name', (
        tester,
      ) async {
        final now = DateTime.now();
        final store = AppStore()..user = profile();
        store.saveSteps(7240);
        store.saveWeight(78.4);
        // Un peso de la semana pasada para que salga "0,5 kg vs semana
        // anterior" con su flecha, el texto más largo de la tarjeta.
        store.saveWeight(78.9, day: DateTime(now.year, now.month, now.day - 7));
        await pumpWithTheme(
          tester,
          store,
          const ProgressScreen(),
          theme,
          width: 360,
        );
        // La lista solo construye lo que se ve: se baja hasta el botón.
        await tester.scrollUntilVisible(find.text('Registrar peso'), 200);
        await tester.pumpAndSettle();

        // Un desbordamiento ("BOTTOM OVERFLOWED…") sale como excepción.
        expect(tester.takeException(), isNull);
        expect(find.textContaining('kg vs semana anterior'), findsOneWidget);

        // La flecha es un icono y no el carácter ▼: la fuente de la app no
        // lo tiene y la fuente de reserva descuadraba la altura (2 px).
        expect(find.byIcon(Icons.arrow_drop_down), findsWidgets);
        expect(find.textContaining('▼'), findsNothing);
        expect(find.textContaining('▲'), findsNothing);

        // Las dos tarjetas miden lo mismo.
        final cards = find.descendant(
          of: find.byType(Row),
          matching: find.byType(Card),
        );
        final heights = {
          for (final card in cards.evaluate())
            if (card.size != null) card.size!.height.round(),
        };
        expect(heights, hasLength(1));
      });
    }

    testWidgets('La hoja de pasos valida y guarda', (tester) async {
      final store = AppStore()..user = profile();
      await pumpScreen(tester, store, const ProgressScreen());

      // El botón está al final de la lista: primero se baja hasta él.
      await tester.ensureVisible(find.text('Registrar pasos').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Registrar pasos').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '200000');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      expect(find.textContaining('entre 0 y 100.000'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '8500');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(store.steps.first.steps, 8500);
      expect(find.text('8.500'), findsOneWidget);
    });

    testWidgets('Historial de peso: borrar pide confirmación', (tester) async {
      final store = AppStore()..user = profile();
      store.weights.addAll([
        WeightEntry(date: DateTime(2026, 11, 10), kg: 79.3),
        WeightEntry(date: DateTime(2026, 11, 3), kg: 80),
      ]);
      await pumpScreen(tester, store, const WeightHistoryScreen());

      expect(find.text('79,3 kg'), findsOneWidget);
      await tester.tap(find.byTooltip('Borrar').first);
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar este peso?'), findsOneWidget);

      // Cancelar no borra nada.
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(store.weights, hasLength(2));

      await tester.tap(find.byTooltip('Borrar').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Borrar'));
      await tester.pumpAndSettle();
      expect(store.weights, hasLength(1));
      expect(find.text('79,3 kg'), findsNothing);
    });
  });
}
