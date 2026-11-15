import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/screens/profile/save_training_profile.dart';
import 'package:lifter_app/screens/profile/training_settings.dart';

import 'helpers.dart';

void main() {
  testWidgets('Ajustes de entrenamiento: tres opciones con su resumen', (
    tester,
  ) async {
    final user = profile()
      ..trainingDays = [1, 3, 5]
      ..sessionMinutes = 60
      ..injuries = ['Rodilla'];
    final store = AppStore()..user = user;
    await pumpScreen(
      tester,
      store,
      Scaffold(body: TrainingSettingsSection(profile: user)),
    );

    expect(find.text('Días de entrenamiento'), findsOneWidget);
    expect(find.text('3 días · 60 min'), findsOneWidget);
    expect(find.text('Material'), findsOneWidget);
    expect(find.text('Lesiones'), findsOneWidget);
    expect(find.text('Rodilla'), findsOneWidget);
  });

  testWidgets('Días: con menos de 2 días no se guarda y sale el error', (
    tester,
  ) async {
    final store = AppStore()..user = (profile()..trainingDays = [1, 2]);
    await pumpScreen(
      tester,
      store,
      const TrainingSettingScreen(setting: TrainingSetting.days),
    );

    // Se desmarca el martes: queda solo el lunes.
    await tester.tap(find.text('M'));
    await tester.pump();
    // El subtítulo del paso ya dice este texto; el error lo añade otra vez.
    const message = 'Elige entre 2 y 6 días.';
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('Guardar'));
    await tester.pump();

    expect(find.text(message), findsNWidgets(2));
    // El perfil del store no cambia hasta guardar.
    expect(store.user?.trainingDays, [1, 2]);
  });

  testWidgets('El diálogo enseña los avisos del plan', (tester) async {
    await pumpScreen(
      tester,
      AppStore(),
      const PlanWarningsDialog(
        warnings: [
          'Hemos quitado Sentadilla búlgara porque ya no tienes mancuernas.',
        ],
      ),
    );

    expect(find.text('Hemos ajustado tu plan'), findsOneWidget);
    expect(
      find.text(
        '• Hemos quitado Sentadilla búlgara porque ya no tienes mancuernas.',
      ),
      findsOneWidget,
    );
  });
}
