import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/app_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'theme/app_theme.dart';

class SocialGymApp extends StatefulWidget {
  const SocialGymApp({super.key, this.store});

  final AppStore? store;

  @override
  State<SocialGymApp> createState() => _SocialGymAppState();
}

class _SocialGymAppState extends State<SocialGymApp> {
  late final AppStore _store = widget.store ?? (AppStore()..start());

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
            title: 'SocialGym',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark(),
            locale: const Locale('es'),
            supportedLocales: const [Locale('es'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: _store.loading
                ? const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  )
                : _store.isLoggedIn
                ? const MainShell()
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
