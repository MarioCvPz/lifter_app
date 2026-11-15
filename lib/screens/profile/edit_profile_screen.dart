import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../onboarding/steps/activity_step.dart';
import '../onboarding/steps/availability_step.dart';
import '../onboarding/steps/equipment_step.dart';
import '../onboarding/steps/experience_step.dart';
import '../onboarding/steps/goal_step.dart';
import '../onboarding/steps/injuries_step.dart';
import '../onboarding/steps/personal_step.dart';
import '../onboarding/steps/physical_step.dart';
import 'save_training_profile.dart';

/// Formulario para editar el perfil. Muestra las mismas preguntas que el
/// cuestionario inicial (reutiliza sus widgets), todas en una lista, más el
/// nombre de usuario.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _username = TextEditingController();

  /// Copia del perfil que se va editando; se guarda al pulsar "Guardar".
  late UserProfile _draft;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    // Solo se llega aquí desde el Perfil, con sesión iniciada.
    _draft = SessionScope.of(context).user!.copy();
    _username.text = _draft.username;
    _loaded = true;
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  /// Primer error de cualquier sección, o null si todo es válido. Son las
  /// mismas validaciones que en el cuestionario.
  String? _validate() =>
      PersonalStep.validate(_draft) ??
      PhysicalStep.validate(_draft) ??
      AvailabilityStep.validate(_draft) ??
      EquipmentStep.validate(_draft);

  /// True mientras se guarda: los botones de guardar se desactivan.
  bool _saving = false;

  /// Guarda con el mismo método que "Ajustes de entrenamiento": si cambian
  /// días, minutos, material, lesiones, objetivo o experiencia, también se
  /// actualiza el plan y se avisan los cambios.
  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _draft
      ..name = _draft.name.trim()
      ..surname = _draft.surname.trim()
      ..username = _username.text.trim();
    setState(() => _saving = true);
    final saved = await saveTrainingProfileAndClose(
      context,
      _draft,
      successMessage: 'Perfil actualizado.',
    );
    // Si se guardó, la pantalla ya se ha cerrado.
    if (!saved && mounted) setState(() => _saving = false);
  }

  /// Redibuja cuando una sección cambia una respuesta.
  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Separación entre secciones.
    const gap = SizedBox(height: 32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PersonalStep(profile: _draft, onChanged: _onChanged),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              prefixText: '@',
            ),
          ),
          gap,
          PhysicalStep(profile: _draft, onChanged: _onChanged),
          gap,
          GoalStep(profile: _draft, onChanged: _onChanged),
          gap,
          ActivityStep(profile: _draft, onChanged: _onChanged),
          gap,
          ExperienceStep(profile: _draft, onChanged: _onChanged),
          gap,
          AvailabilityStep(profile: _draft, onChanged: _onChanged),
          gap,
          EquipmentStep(profile: _draft, onChanged: _onChanged),
          gap,
          InjuriesStep(profile: _draft, onChanged: _onChanged),
          gap,
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }
}
