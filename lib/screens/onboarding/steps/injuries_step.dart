import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 8 (opcional): lesiones o zonas que conviene evitar.
class InjuriesStep extends StatelessWidget {
  const InjuriesStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: '¿Alguna lesión o zona a evitar?',
          subtitle: 'Es opcional. Si no tienes ninguna, sigue adelante.',
        ),
        InjuryPicker(
          selected: profile.injuries,
          onChanged: (injuries) {
            profile.injuries = injuries;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Chips de zonas lesionadas con la opción "Ninguna", que aparece marcada
/// cuando la lista está vacía y, al pulsarla, desmarca las demás. Se usa
/// también en "Editar perfil".
class InjuryPicker extends StatelessWidget {
  const InjuryPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final List<String> selected;

  /// Recibe la lista nueva, en el orden de [ProfileOptions.injuries].
  final ValueChanged<List<String>> onChanged;

  void _toggle(String zone) {
    final marked = {...selected};
    if (!marked.remove(zone)) marked.add(zone);
    onChanged([
      for (final option in ProfileOptions.injuries)
        if (marked.contains(option)) option,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text('Ninguna'),
          selected: selected.isEmpty,
          onSelected: (_) => onChanged([]),
        ),
        for (final zone in ProfileOptions.injuries)
          FilterChip(
            label: Text(zone),
            selected: selected.contains(zone),
            onSelected: (_) => _toggle(zone),
          ),
      ],
    );
  }
}
