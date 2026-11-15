import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/workout_draft.dart';
import '../../models/models.dart';

/// Una fila de serie: número, peso (kg), repeticiones y el botón ✓.
/// Los campos vacíos muestran como pista lo de la última vez ([hint]).
/// La fila marcada cambia de color.
///
/// Es un StatefulWidget porque tiene que guardar sus dos
/// [TextEditingController] (y cerrarlos en [dispose]).
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.number,
    required this.set,
    required this.hint,
    required this.onChanged,
    required this.onToggle,
  });

  final int number;

  /// La serie del borrador. La fila la modifica directamente al escribir.
  final DraftSet set;
  final WorkoutSet? hint;

  /// Avisa a la pantalla de que ha cambiado un valor (para el resumen).
  final VoidCallback onChanged;
  final VoidCallback onToggle;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(text: _weightText(widget.set.weightKg));
    _reps = TextEditingController(text: widget.set.reps?.toString() ?? '');
  }

  /// Al marcar ✓ con un campo vacío, el borrador lo rellena con la pista:
  /// aquí se copia ese valor al campo para que se vea.
  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final set = widget.set;
    if (_weight.text.isEmpty && set.weightKg != null) {
      _weight.text = _weightText(set.weightKg);
    }
    if (_reps.text.isEmpty && set.reps != null) {
      _reps.text = '${set.reps}';
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  String _weightText(double? kg) => kg == null ? '' : formatKg(kg);

  /// Campo vacío → null (se usará la pista). Un texto que no es un número
  /// (por ejemplo "2,,5") se guarda como -1 para que la validación avise.
  void _onWeightChanged(String text) {
    widget.set.weightKg = text.isEmpty
        ? null
        : double.tryParse(text.replaceAll(',', '.')) ?? -1;
    widget.onChanged();
  }

  void _onRepsChanged(String text) {
    widget.set.reps = text.isEmpty ? null : int.tryParse(text) ?? 0;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = widget.set.done;
    final hint = widget.hint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: done ? scheme.primary.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          SizedBox(
            width: SetColumns.numberWidth,
            child: Text('${widget.number}', textAlign: TextAlign.center),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
              controller: _weight,
              hint: hint == null ? 'kg' : formatKg(hint.weightKg),
              decimals: true,
              onChanged: _onWeightChanged,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _NumberField(
              controller: _reps,
              hint: hint == null ? 'reps' : '${hint.reps}',
              decimals: false,
              onChanged: _onRepsChanged,
            ),
          ),
          SizedBox(
            width: SetColumns.checkWidth,
            child: IconButton(
              tooltip: done ? 'Desmarcar serie' : 'Marcar serie como hecha',
              onPressed: widget.onToggle,
              icon: Icon(
                done ? Icons.check_circle : Icons.check_circle_outline,
                color: done ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Anchos de las columnas fijas, compartidos con la fila de títulos de la
/// tarjeta para que todo quede alineado.
class SetColumns {
  static const numberWidth = 28.0;
  static const checkWidth = 48.0;
}

/// Campo numérico pequeño. Solo deja escribir cifras (y coma o punto si
/// [decimals] es true).
class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.decimals,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final bool decimals;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimals),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          decimals ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
      onChanged: onChanged,
    );
  }
}
