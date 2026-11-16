import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/screens/profile/edit_profile_screen.dart';
import 'package:lifter_app/theme/app_theme.dart';

import 'helpers.dart';

void main() {
  test('Hay un tema oscuro y uno claro', () {
    expect(AppTheme.dark().brightness, Brightness.dark);
    expect(AppTheme.light().brightness, Brightness.light);
  });

  test('Tema claro: los acentos se leen sobre las tarjetas blancas', () {
    // Contraste según la fórmula de la WCAG: 3:1 es el mínimo para
    // iconos, barras y textos grandes.
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final light = la > lb ? la : lb;
      final dark = la > lb ? lb : la;
      return (light + 0.05) / (dark + 0.05);
    }

    const s = AppTheme.lightScheme;
    for (final color in [
      s.primary,
      s.secondary,
      s.tertiary,
      s.primaryFixed,
      s.secondaryFixed,
      s.outline,
    ]) {
      expect(
        contrast(color, s.surfaceContainer),
        greaterThanOrEqualTo(3),
        reason: '$color',
      );
    }
  });

  test('Sin nada guardado, el tema es el oscuro', () async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore();
    await store.loadThemeMode();
    expect(store.themeMode, ThemeMode.dark);
  });

  test('El tema elegido se guarda y se lee al volver a abrir', () async {
    SharedPreferences.setMockInitialValues({});
    await AppStore().setThemeMode(ThemeMode.light);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AppStore.themeKey), 'light');

    // Otra "apertura" de la app lee lo guardado.
    final reopened = AppStore();
    await reopened.loadThemeMode();
    expect(reopened.themeMode, ThemeMode.light);
  });

  testWidgets('Editar perfil: cambiar a tema claro', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore()..user = profile();
    await pumpScreen(tester, store, const EditProfileScreen());

    // La sección está al final de la lista: se baja hasta ella (la lista
    // solo construye lo que se ve) y se deja entera en pantalla.
    await tester.scrollUntilVisible(
      find.text('Claro'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Claro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claro'));
    await tester.pumpAndSettle();
    expect(store.themeMode, ThemeMode.light);
  });
}
