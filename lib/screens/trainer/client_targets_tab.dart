import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_store.dart';
import '../../data/formatters.dart';
import '../../data/nutrition_calculator.dart';
import '../../models/models.dart';

/// Pestaña "Objetivos" de la ficha de un cliente: calorías (1.000–5.000)
/// y pasos. Un campo vacío es "automático" (lo que calcula la app), que se
/// muestra debajo como referencia. La proteína, la grasa y los hidratos no
/// se escriben: la app los reparte a partir de las calorías, y un resumen
/// en vivo enseña cómo quedan.
class ClientTargetsTab extends StatefulWidget {
  const ClientTargetsTab({super.key, required this.client});

  final AppUser client;

  @override
  State<ClientTargetsTab> createState() => _ClientTargetsTabState();
}

class _ClientTargetsTabState extends State<ClientTargetsTab> {
  final _kcal = TextEditingController();
  final _steps = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _started = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _kcal.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final store = SessionScope.of(context);
    try {
      final settings = await store.fetchCoachSettingsOf(widget.client.uid);
      if (!mounted) return;
      _fill(settings);
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudieron cargar sus objetivos: $e';
      });
    }
  }

  /// Pone en los campos los valores de [settings] (vacío = automático).
  void _fill(CoachSettings settings) {
    _kcal.text = settings.kcalTarget?.toString() ?? '';
    _steps.text = settings.stepsGoal?.toString() ?? '';
  }

  CoachSettings _fromFields() => CoachSettings(
    kcalTarget: int.tryParse(_kcal.text),
    stepsGoal: int.tryParse(_steps.text),
  );

  Future<void> _save(CoachSettings settings) async {
    final error = settings.validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final saveError = await store.saveClientCoachSettings(
      widget.client.uid,
      settings,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = saveError;
    });
    if (saveError == null) {
      _fill(settings);
      messenger.showSnackBar(
        const SnackBar(content: Text('Objetivos guardados.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profile = widget.client.profile;
    final auto = NutritionCalculator.macros(profile);
    final error = _error;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Deja un campo vacío para usar el cálculo automático. La proteína, '
          'la grasa y los hidratos se calculan solos a partir de las '
          'calorías. Tu cliente verá "Ajustado por tu entrenador".',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _TargetField(
          controller: _kcal,
          label: 'Calorías al día',
          unit: 'kcal',
          automatic: '${formatThousands(auto.kcal)} kcal',
          // Cada cambio repinta el resumen de macros.
          onChanged: (_) => setState(() {}),
        ),
        _MacroPreview(profile: profile, settings: _fromFields()),
        const SizedBox(height: 16),
        _TargetField(
          controller: _steps,
          label: 'Pasos al día',
          unit: 'pasos',
          automatic: '${formatThousands(profile.stepsGoal)} pasos (el suyo)',
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        FilledButton(
          onPressed: _saving ? null : () => _save(_fromFields()),
          child: Text(_saving ? 'Guardando…' : 'Guardar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(const CoachSettings()),
          child: const Text('Volver al automático'),
        ),
      ],
    );
  }
}

/// Resumen en vivo de lo que verá el cliente:
/// "2.400 kcal · P 126 g · H 340 g · G 67 g".
class _MacroPreview extends StatelessWidget {
  const _MacroPreview({required this.profile, required this.settings});

  final UserProfile profile;
  final CoachSettings settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = NutritionCalculator.macrosWithCoach(profile, settings);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.restaurant, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${formatThousands(m.kcal)} kcal · P ${m.protein.round()} g · '
              'H ${m.carbs.round()} g · G ${m.fat.round()} g',
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo numérico con su valor automático debajo, como referencia.
class _TargetField extends StatelessWidget {
  const _TargetField({
    required this.controller,
    required this.label,
    required this.unit,
    required this.automatic,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String unit;
  final String automatic;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          hintText: 'Automático',
          helperText: 'Automático: $automatic',
        ),
      ),
    );
  }
}
