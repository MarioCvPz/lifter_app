import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/app.dart';
import 'package:lifter_app/data/app_store.dart';

void main() {
  testWidgets('Sin sesión se muestra la pantalla de login', (tester) async {
    // Store sin start(): no conecta con Firebase.
    await tester.pumpWidget(LifterApp(store: AppStore()));

    expect(find.text('LiFTeR+'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('El login no se envía con correo o contraseña inválidos', (
    tester,
  ) async {
    await tester.pumpWidget(LifterApp(store: AppStore()));

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Correo electrónico'),
      'correo-sin-arroba',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      '123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();

    expect(find.text('Introduce un correo válido'), findsOneWidget);
    expect(find.text('Mínimo 6 caracteres'), findsOneWidget);
  });

  testWidgets('El botón de info abre la ayuda de la pantalla', (tester) async {
    await tester.pumpWidget(LifterApp(store: AppStore()));

    await tester.tap(find.byTooltip('Cómo se usa'));
    await tester.pumpAndSettle();

    expect(find.text('Cómo entrar'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsWidgets);
    expect(find.text('Con Google'), findsOneWidget);
  });
}
