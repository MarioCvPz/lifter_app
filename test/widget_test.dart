import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/app.dart';
import 'package:lifter_app/data/app_store.dart';

void main() {
  testWidgets('Muestra la pantalla de login', (tester) async {
    // Store sin start(): no conecta con Firebase.
    await tester.pumpWidget(LifterApp(store: AppStore()));

    expect(find.text('LiFTeR+'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
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
