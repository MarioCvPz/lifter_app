import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/screens/profile/edit_profile_screen.dart';

import 'helpers.dart';

void main() {
  // ProfileScreen no se prueba aquí: lee la foto de Google de Firebase al
  // construirse (store.photoUrl), y las pruebas no usan Firebase.
  testWidgets('Editar perfil: tarjetas plegables con su resumen', (
    tester,
  ) async {
    final store = AppStore()..user = profile(weightKg: 72.5);
    await pumpScreen(tester, store, const EditProfileScreen());

    expect(find.text('Datos personales'), findsOneWidget);
    expect(find.text('Ana · @ana'), findsOneWidget);
    expect(find.textContaining('72,5 kg'), findsOneWidget);

    // Cerrada no se ve la pregunta; al tocarla se abre.
    expect(find.text('¿Cuál es tu objetivo?'), findsNothing);
    await tester.tap(find.text('Objetivo'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cuál es tu objetivo?'), findsOneWidget);
  });
}
