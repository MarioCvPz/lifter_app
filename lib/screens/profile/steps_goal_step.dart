import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../onboarding/onboarding_widgets.dart';

/// Ajuste "Objetivo de pasos": un campo numérico que cambia
/// `stepsGoal` en la copia del perfil. Se guarda con el botón "Guardar" de
/// [TrainingSettingScreen], como el resto de ajustes.
class StepsGoalStep extends StatefulWidget {
  const StepsGoalStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  /// Mensaje de error, o null si el objetivo está entre 1.000 y 50.000.
  static String? validate(UserProfile profile) =>
      UserProfile.validateStepsGoal(profile.stepsGoal);

  @override
  State<StepsGoalStep> createState() => _StepsGoalStepState();
}

class _StepsGoalStepState extends State<StepsGoalStep> {
  late final _controller = TextEditingController(
    text: '${widget.profile.stepsGoal}',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Convierte el texto a número (sin puntos de miles). Si no es un
  /// número, se guarda 0 y la validación mostrará el error.
  void _onTextChanged(String text) {
    widget.profile.stepsGoal = int.tryParse(text.replaceAll('.', '')) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Objetivo de pasos',
          subtitle:
              'Los pasos que quieres dar cada día. Se usan en la nota de '
              'la semana de Progreso. Lo normal son 10.000.',
        ),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: const InputDecoration(suffixText: 'pasos al día'),
          onChanged: _onTextChanged,
        ),
      ],
    );
  }
}
