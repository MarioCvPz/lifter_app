import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/app_theme.dart';

class LifterApp extends StatefulWidget {
  const LifterApp({super.key, this.store});

  final AppStore? store;

  @override
  State<LifterApp> createState() => _LifterAppState();
}

class _LifterAppState extends State<LifterApp> {
  late final AppStore _store =
      widget.store ??
      (AppStore()
        ..start()
        ..loadThemeMode());

  @override
  void dispose() {
    if (widget.store == null) {
      _store.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      store: _store,
      child: ListenableBuilder(
        listenable: _store,
        builder: (context, _) {
          return MaterialApp(
            title: 'LiFTeR+',
            debugShowCheckedModeBanner: false,
            // El tema lo elige el usuario en Editar perfil.
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _store.themeMode,
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: _homeScreen(),
          );
        },
      ),
    );
  }

  /// Pantalla inicial según el estado de la sesión y del perfil.
  Widget _homeScreen() {
    if (_store.loading) return const _LoadingScreen();
    final user = _store.user;
    if (user == null) return const LoginScreen();
    // Con sesión, pero aún con el perfil provisional: si decidiéramos ya,
    // el cuestionario aparecería un instante a quien ya lo completó.
    if (!_store.profileLoaded) return const _LoadingScreen();
    if (!user.onboardingCompleted) return const OnboardingScreen();
    return const MainShell();
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
