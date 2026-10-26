import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/routines/routine_widgets.dart';

void main() {
  // Mismo flujo que el panel de entrenador: se elige usuario en un bottom
  // sheet y, nada más cerrarlo, se abre el editor de rutinas.
  testWidgets('Crear una rutina tras elegir usuario no falla al cerrar', (
    tester,
  ) async {
    Routine? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final picked = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => Column(
                  children: [
                    const TextField(),
                    ListTile(
                      title: const Text('Ana'),
                      onTap: () => Navigator.pop(ctx, 'Ana'),
                    ),
                  ],
                ),
              );
              if (picked == null || !context.mounted) return;
              result = await showRoutineEditor(
                context,
                title: 'Rutina para $picked',
                templateName: 'Entrenador',
              );
            },
            child: const Text('Asignar'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Asignar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Fuerza');
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result?.name, 'Fuerza');
    expect(result?.exercises, hasLength(1));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
