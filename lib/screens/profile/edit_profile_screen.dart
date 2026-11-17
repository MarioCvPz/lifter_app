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
import 'steps_goal_step.dart';
import 'training_settings.dart';

/// Formulario para editar el perfil. Reutiliza las preguntas del
/// cuestionario inicial, cada una dentro de una tarjeta plegable con su
/// icono y un resumen de lo elegido, para que la pantalla no sea una lista
/// enorme.
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

  /// True mientras se guarda: los botones de guardar se desactivan.
  bool _saving = false;

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
      EquipmentStep.validate(_draft) ??
      StepsGoalStep.validate(_draft);

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

  /// Redibuja cuando una sección cambia una respuesta (así se actualizan
  /// los resúmenes de las tarjetas).
  void _onChanged() => setState(() {});

  // --- Resúmenes de cada tarjeta ---

  String get _personalSummary {
    final fullName = '${_draft.name} ${_draft.surname}'.trim();
    final username = _username.text.trim();
    return [
      fullName.isEmpty ? 'Sin nombre' : fullName,
      if (username.isNotEmpty) '@$username',
    ].join(' · ');
  }

  String get _physicalSummary {
    final kg = _draft.weightKg;
    final weight = kg == kg.roundToDouble()
        ? kg.toStringAsFixed(0)
        : kg.toStringAsFixed(1).replaceAll('.', ',');
    final age = _draft.age;
    return [
      _draft.sex,
      if (age != null) '$age años',
      '${_draft.heightCm.toStringAsFixed(0)} cm',
      '$weight kg',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
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
          _Header(profile: _draft),
          const SizedBox(height: 16),
          const _SectionTitle(Icons.person_outline, 'Sobre ti'),
          _SectionCard(
            icon: Icons.badge_outlined,
            title: 'Datos personales',
            summary: _personalSummary,
            children: [
              PersonalStep(profile: _draft, onChanged: _onChanged),
              const SizedBox(height: 12),
              TextField(
                controller: _username,
                onChanged: (_) => _onChanged(),
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  prefixText: '@',
                ),
              ),
            ],
          ),
          _SectionCard(
            icon: Icons.monitor_weight_outlined,
            title: 'Medidas',
            summary: _physicalSummary,
            children: [PhysicalStep(profile: _draft, onChanged: _onChanged)],
          ),
          _SectionCard(
            icon: Icons.directions_walk,
            title: 'Actividad diaria',
            summary: _draft.activityLevel.label,
            children: [ActivityStep(profile: _draft, onChanged: _onChanged)],
          ),
          const SizedBox(height: 16),
          const _SectionTitle(Icons.fitness_center, 'Entrenamiento'),
          _SectionCard(
            icon: Icons.flag_outlined,
            title: 'Objetivo',
            summary: _draft.goal.label,
            children: [GoalStep(profile: _draft, onChanged: _onChanged)],
          ),
          _SectionCard(
            icon: Icons.military_tech_outlined,
            title: 'Experiencia',
            summary: _draft.experience,
            children: [ExperienceStep(profile: _draft, onChanged: _onChanged)],
          ),
          for (final setting in TrainingSetting.values)
            _SectionCard(
              icon: setting.icon,
              title: setting.label,
              summary: setting.summary(_draft),
              children: [_settingStep(setting)],
            ),
          const SizedBox(height: 16),
          const _SectionTitle(Icons.palette_outlined, 'Apariencia'),
          const _ThemeCard(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: const Text('Guardar cambios'),
          ),
        ],
      ),
    );
  }

  /// Pregunta del cuestionario de cada ajuste de entrenamiento.
  Widget _settingStep(TrainingSetting setting) => switch (setting) {
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
    TrainingSetting.stepsGoal => StepsGoalStep(
      profile: _draft,
      onChanged: _onChanged,
    ),
  };
}

/// Cabecera con la inicial, el nombre y el correo.
class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = profile.name.trim();
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Text(
                name.isEmpty ? '?' : name[0].toUpperCase(),
                style: text.headlineSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Sin nombre' : name,
                    style: text.titleLarge,
                  ),
                  Text(
                    profile.email,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toca una sección para cambiarla.',
                    style: text.bodySmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Título pequeño que agrupa varias tarjetas.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.icon, this.title);

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.primary,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta plegable: cerrada muestra el icono, el título y el resumen;
/// abierta, la pregunta del cuestionario para cambiarlo.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.summary,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.18),
          foregroundColor: scheme.primary,
          child: Icon(icon, size: 20),
        ),
        title: Text(title),
        subtitle: Text(
          summary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        // Sin las líneas que ExpansionTile dibuja por defecto al abrirse.
        shape: const Border(),
        collapsedShape: const Border(),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Elegir tema claro u oscuro. Se aplica y se guarda al momento (no hace
/// falta pulsar "Guardar"), porque no es un dato del perfil sino del
/// dispositivo.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tema de la app'),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode),
                  label: Text('Oscuro'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode),
                  label: Text('Claro'),
                ),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (selection) =>
                  store.setThemeMode(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}
