import 'package:flutter/material.dart';

import '../../../models/models.dart';
import '../onboarding_widgets.dart';

/// Pregunta 3: sexo, fecha de nacimiento, altura y peso. Son los datos de
/// la fórmula de calorías.
class PhysicalStep extends StatefulWidget {
  const PhysicalStep({
    super.key,
    required this.profile,
    required this.onChanged,
  });

  final UserProfile profile;
  final VoidCallback onChanged;

  static const minAge = 14;
  static const maxAge = 90;
  static const minHeightCm = 120;
  static const maxHeightCm = 230;
  static const minWeightKg = 30;
  static const maxWeightKg = 250;

  /// Mensaje de error, o null si los datos están en rangos razonables.
  static String? validate(UserProfile profile) {
    final age = profile.age;
    final height = profile.heightCm;
    final weight = profile.weightKg;
    if (age == null) return 'Elige tu fecha de nacimiento.';
    if (age < minAge || age > maxAge) {
      return 'La edad debe estar entre $minAge y $maxAge años.';
    }
    if (height < minHeightCm || height > maxHeightCm) {
      return 'Escribe una altura entre $minHeightCm y $maxHeightCm cm.';
    }
    if (weight < minWeightKg || weight > maxWeightKg) {
      return 'Escribe un peso entre $minWeightKg y $maxWeightKg kg.';
    }
    return null;
  }

  @override
  State<PhysicalStep> createState() => _PhysicalStepState();
}

class _PhysicalStepState extends State<PhysicalStep> {
  late final _height = TextEditingController(
    text: _initialText(widget.profile.heightCm, decimals: 0),
  );
  late final _weight = TextEditingController(
    text: _initialText(widget.profile.weightKg, decimals: 1),
  );

  /// Texto inicial de un campo: vacío si vale 0 (cuenta nueva, sin
  /// rellenar); si no, el valor que ya tenía el usuario.
  static String _initialText(double value, {required int decimals}) =>
      value > 0 ? value.toStringAsFixed(decimals) : '';

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Convierte el texto a número (acepta coma decimal). Si no es un
  /// número, devuelve 0 y la validación mostrará el error.
  double _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StepHeader(
          title: 'Tus datos físicos',
          subtitle: 'Los necesitamos para calcular tus calorías diarias.',
        ),
        SegmentedButton<String>(
          segments: [
            for (final sex in ProfileOptions.sexes)
              ButtonSegment(value: sex, label: Text(sex)),
          ],
          selected: {profile.sex},
          onSelectionChanged: (selection) {
            profile.sex = selection.first;
            widget.onChanged();
          },
        ),
        const SizedBox(height: 16),
        _BirthDateField(profile: profile, onChanged: widget.onChanged),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _NumberField(
                controller: _height,
                label: 'Altura',
                suffix: 'cm',
                onChanged: (value) {
                  profile.heightCm = _parse(value);
                  widget.onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NumberField(
                controller: _weight,
                label: 'Peso',
                suffix: 'kg',
                onChanged: (value) {
                  profile.weightKg = _parse(value);
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Botón que abre el calendario y muestra la fecha y la edad calculada.
class _BirthDateField extends StatelessWidget {
  const _BirthDateField({required this.profile, required this.onChanged});

  final UserProfile profile;
  final VoidCallback onChanged;

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      helpText: 'Fecha de nacimiento',
      initialDatePickerMode: DatePickerMode.year,
      initialDate: profile.birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked == null) return; // ha cancelado
    profile.birthDate = picked;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final date = profile.birthDate;
    final age = profile.age;
    final text = date == null
        ? 'Elegir fecha de nacimiento'
        : MaterialLocalizations.of(context).formatCompactDate(date);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.cake_outlined),
      title: Text(text),
      subtitle: age == null ? null : Text('Tienes $age años'),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () => _pick(context),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.label,
    required this.suffix,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final String suffix;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
      onChanged: onChanged,
    );
  }
}
