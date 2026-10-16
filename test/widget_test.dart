import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/app.dart';

void main() {
  testWidgets('Muestra la pantalla de login', (tester) async {
    await tester.pumpWidget(const SocialGymApp());

    expect(find.text('SocialGym'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
