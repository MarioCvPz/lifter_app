import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/brand.dart';
import '../onboarding/steps/availability_step.dart';
import '../onboarding/steps/equipment_step.dart';
import '../onboarding/steps/injuries_step.dart';
import 'save_training_profile.dart';

/// Opciones de "Ajustes de entrenamiento". Cada una abre la misma pantalla
/// del cuestionario (su widget de paso) con un botón "Guardar".
enum TrainingSetting {
  days('Días de entrenamiento', Icons.calendar_month),
  equipment('Material', Icons.fitness_center),
  injuries('Lesiones', Icons.healing);

  const TrainingSetting(this.label, this.icon);

  final String label;
  final IconData icon;

  /// Resumen de lo que tiene elegido, para la lista del Perfil.
  String summary(UserProfile profile) => switch (this) {
    TrainingSetting.days =>
      '${profile.trainingDays.length} días · '
          '${ProfileOptions.sessionLabel(profile.sessionMinutes)}',
    TrainingSetting.equipment => '${profile.equipment.length} elegidos',
    TrainingSetting.injuries =>
      profile.injuries.isEmpty ? 'Ninguna' : profile.injuries.join(', '),
  };

  /// Las mismas validaciones que en el cuestionario.
  String? validate(UserProfile profile) => switch (this) {
    TrainingSetting.days => AvailabilityStep.validate(profile),
    TrainingSetting.equipment => EquipmentStep.validate(profile),
    TrainingSetting.injuries => null, // "Ninguna" también vale
  };
}

/// Sección "Ajustes de entrenamiento" del Perfil.
class TrainingSettingsSection extends StatelessWidget {
  const TrainingSettingsSection({super.key, required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Ajustes de entrenamiento',
          leading: Icon(
            Icons.tune,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              for (final setting in TrainingSetting.values)
                ListTile(
                  leading: Icon(setting.icon),
                  title: Text(setting.label),
                  subtitle: Text(
                    setting.summary(profile),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TrainingSettingScreen(setting: setting),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pantalla de un ajuste: el paso del cuestionario correspondiente y el
/// botón "Guardar". Al guardar se actualiza el plan y se avisan los cambios.
class TrainingSettingScreen extends StatefulWidget {
  const TrainingSettingScreen({super.key, required this.setting});

  final TrainingSetting setting;

  @override
  State<TrainingSettingScreen> createState() => _TrainingSettingScreenState();
}

class _TrainingSettingScreenState extends State<TrainingSettingScreen> {
  /// Copia del perfil: el del store no cambia hasta guardar.
  late UserProfile _draft;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    // Solo se llega aquí desde el Perfil, con sesión iniciada.
    _draft = SessionScope.of(context).user!.copy();
    _loaded = true;
  }

  /// Redibuja cuando el paso cambia una respuesta y quita el error.
  void _onChanged() => setState(() => _error = null);

  Future<void> _save() async {
    final error = widget.setting.validate(_draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    final saved = await saveTrainingProfileAndClose(
      context,
      _draft,
      successMessage: 'Ajustes guardados.',
    );
    // Si se guardó, la pantalla ya se ha cerrado.
    if (!saved && mounted) setState(() => _saving = false);
  }

  Widget _step() => switch (widget.setting) {
    TrainingSetting.days => AvailabilityStep(
      profile: _draft,
      onChanged: _onChanged,
    ),
    TrainingSetting.equipment => EquipmentStep(
      profile: _draft,
      onChanged: _onChanged,
    ),
    TrainingSetting.injuries => InjuriesStep(
      profile: _draft,
      onChanged: _onChanged,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final message = _error;
    return Scaffold(
      appBar: AppBar(title: Text(widget.setting.label)),
      body: ListView(padding: const EdgeInsets.all(20), children: [_step()]),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              // null desactiva el botón mientras se guarda.
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
