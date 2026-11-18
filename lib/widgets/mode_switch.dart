import 'package:flutter/material.dart';

import '../data/app_store.dart';

/// Selector "Usuario | Entrenador" (dos botones en forma de píldora). Solo
/// lo ven los entrenadores y admins; para el resto no ocupa nada. Al
/// cambiar, la app pasa a la otra barra de navegación (ver `app.dart`).
class ModeSwitch extends StatelessWidget {
  const ModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    if (!store.isTrainer) return const SizedBox.shrink();
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.person_outline),
          label: Text('Usuario'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.sports_outlined),
          label: Text('Entrenador'),
        ),
      ],
      selected: {store.inTrainerMode},
      onSelectionChanged: (selection) => store.setTrainerMode(selection.first),
    );
  }
}
