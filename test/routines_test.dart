import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/routines/routine_widgets.dart';

import 'helpers.dart';

void main() {
  testWidgets('CP-06 Una rutina necesita nombre y al menos un ejercicio', (
    tester,
  ) async {
    Routine? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showRoutineEditor(
                context,
                exercises: const [bench, squat],
              );
            },
            child: const Text('Crear'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Crear'));
    await tester.pumpAndSettle();

    FilledButton save() =>
        tester.widget(find.widgetWithText(FilledButton, 'Guardar'));

    // Sin nombre ni ejercicios: no se puede guardar.
    expect(save().onPressed, isNull);

    // Con nombre pero sin ejercicios: tampoco.
    await tester.enterText(find.byType(TextField).first, 'Mi rutina');
    await tester.pump();
    expect(save().onPressed, isNull);

    // Con nombre y un ejercicio: sí.
    await tester.tap(find.text('Sentadilla'));
    await tester.pump();
    expect(save().onPressed, isNotNull);
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(result?.name, 'Mi rutina');
    expect(result?.exercises, [squat]);
    expect(result?.isTemplate, isFalse);
  });

  test('Nivel y duración estimada de una rutina', () {
    const routine = Routine(
      id: 'r',
      name: 'Fuerza',
      description: '',
      templateName: 'Personal',
      exercises: [bench, squat, deadlift],
    );
    // El nivel es el del ejercicio más exigente (peso muerto: Avanzado).
    expect(routine.level, 'Avanzado');
    // 3 ejercicios × 5 min.
    expect(routine.estimatedMin, 15);
    expect(routine.muscleGroups, ['Pecho', 'Piernas', 'Espalda']);
  });
}
