import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 7: dónde entrena y con qué material. Al elegir el lugar se
/// marca su material típico, y debajo el usuario lo puede ajustar.
class EquipmentStep extends StatelessWidget {
  const EquipmentStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  /// Mensaje de error, o null si hay al menos un material.
  static String? validate(UserProfile profile) {
    if (profile.equipment.isEmpty) return 'Marca al menos un material.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Dónde entrenas?',
          subtitle:
              'Marcamos el material típico de cada lugar. Ajústalo '
              'debajo si hace falta.',
        ),
        ChoiceList<TrainingPlace>(
          options: TrainingPlace.values,
          selected: profile.trainingPlace,
          label: (place) => place.label,
          onSelected: (place) {
            profile.trainingPlace = place;
            // Copia de la lista: la del enum es constante y no se puede
            // modificar.
            profile.equipment = [...place.defaultEquipment];
            onChanged();
          },
        ),
        const SizedBox(height: 16),
        Text('Material disponible', style: text.titleMedium),
        const SizedBox(height: 8),
        EquipmentPicker(
          selected: profile.equipment,
          onChanged: (equipment) {
            profile.equipment = equipment;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Chips para marcar el material disponible. Se usa también en "Editar
/// perfil".
class EquipmentPicker extends StatelessWidget {
  const EquipmentPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;

  /// Recibe la lista nueva, en el orden de [ProfileOptions.equipment].
  final ValueChanged<List<String>> onChanged;

  void _toggle(String item) {
    final marked = {...selected};
    if (!marked.remove(item)) marked.add(item);
    onChanged([
      for (final option in ProfileOptions.equipment)
        if (marked.contains(option)) option,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in ProfileOptions.equipment)
          FilterChip(
            label: Text(item),
            selected: selected.contains(item),
            onSelected: (_) => _toggle(item),
          ),
      ],
    );
  }
}
