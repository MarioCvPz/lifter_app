import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/data/week_summary.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/profile/training_settings.dart';
import 'package:lifter_app/screens/progress/progress_screen.dart';
import 'package:lifter_app/widgets/help.dart';

import 'helpers.dart';

void main() {
  group('CP-16 Objetivo de pasos', () {
    test('Validación: entre 1.000 y 50.000', () {
      expect(UserProfile.validateStepsGoal(999), isNotNull);
      expect(UserProfile.validateStepsGoal(1000), isNull);
      expect(UserProfile.validateStepsGoal(50000), isNull);
      expect(UserProfile.validateStepsGoal(50001), isNotNull);
      expect(UserProfile.validateStepsGoal(0), isNotNull); // campo vacío
    });

    test('Resumen en Ajustes de entrenamiento', () {
      final user = profile()..stepsGoal = 8000;
      expect(TrainingSetting.stepsGoal.summary(user), '8.000 pasos al día');
    });

    test('Progreso usa el objetivo del perfil', () {
      final store = AppStore()..user = profile();
      store.saveSteps(6000);
      final monday = WeekSummary.mondayOf(DateTime.now());

      expect(store.stepsGoalInUse, 10000);
      expect(store.weekSummary(monday).stepsPercent, closeTo(60, 0.001));

      // Al cambiarlo, la nota de pasos se calcula con el nuevo.
      store.user?.stepsGoal = 8000;
      expect(store.stepsGoalInUse, 8000);
      expect(store.weekSummary(monday).stepsPercent, closeTo(75, 0.001));
    });

    testWidgets('Un objetivo fuera de rango no se guarda', (tester) async {
      final store = AppStore()..user = profile();
      await pumpScreen(
        tester,
        store,
        const TrainingSettingScreen(setting: TrainingSetting.stepsGoal),
      );

      expect(find.text('10000'), findsOneWidget); // el valor actual
      await tester.enterText(find.byType(TextField), '500');
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(
        find.text('El objetivo tiene que estar entre 1.000 y 50.000 pasos.'),
        findsOneWidget,
      );
      // Se edita una copia: el perfil no cambia hasta guardar bien.
      expect(store.user?.stepsGoal, 10000);
    });
  });

  group('CP-16 Ayuda de Progreso', () {
    test('Explica la nota con los mismos pesos que el cálculo', () {
      final text = [
        for (final (_, title, body) in HelpTopic.progress.items) '$title $body',
      ].join(' ');
      for (final weight in [
        WeekSummary.workoutWeight,
        WeekSummary.nutritionWeight,
        WeekSummary.stepsWeight,
      ]) {
        expect(text, contains('${(weight * 100).round()} %'));
      }
      expect(text, contains('±10 %'));
      expect(text, contains('Registrar pasos'));
    });

    test('Ya no se manda a la pestaña Rutinas desde otras ayudas', () {
      for (final topic in HelpTopic.values) {
        if (topic == HelpTopic.routines) continue;
        for (final (_, title, body) in topic.items) {
          expect('$title $body', isNot(contains('Rutinas')), reason: title);
        }
      }
    });

    testWidgets('Progreso tiene el botón ⓘ', (tester) async {
      final store = AppStore()..user = profile();
      await pumpScreen(tester, store, const ProgressScreen());

      await tester.tap(find.byTooltip('Cómo se usa'));
      await tester.pumpAndSettle();
      expect(find.text('Cómo funciona Progreso'), findsOneWidget);
      expect(find.text('Nota de la semana'), findsWidgets);
    });
  });
}
