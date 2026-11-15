import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 1: nombre y apellidos. El correo no se pide: ya lo tenemos de
/// la cuenta.
class PersonalStep extends StatefulWidget {
  const PersonalStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  /// Perfil en edición: el paso escribe aquí las respuestas.
  final UserProfile profile;
  final VoidCallback onChanged;

  /// Mensaje de error, o null si se puede pasar al siguiente paso.
  static String? validate(UserProfile profile) {
    if (profile.name.trim().isEmpty) return 'Escribe tu nombre.';
    return null;
  }

  @override
  State<PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<PersonalStep> {
  // Empiezan con lo que ya haya en el perfil (por ejemplo, el nombre de
  // Google).
  late final _name = TextEditingController(text: widget.profile.name);
  late final _surname = TextEditingController(text: widget.profile.surname);

  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Cómo te llamas?',
          subtitle: 'Así te saludaremos en la app.',
        ),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre'),
          onChanged: (value) {
            widget.profile.name = value;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _surname,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Apellidos (opcional)'),
          onChanged: (value) {
            widget.profile.surname = value;
            widget.onChanged();
          },
        ),
      ],
    );
  }
}
