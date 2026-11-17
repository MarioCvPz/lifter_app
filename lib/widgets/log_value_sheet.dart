import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_store.dart';
import '../data/formatters.dart';
import '../data/stats.dart';
import '../models/models.dart';

/// Abre la hoja para apuntar el peso de un día (hoy por defecto). Si ese
/// día ya tiene peso, sale escrito.
Future<void> showWeightSheet(BuildContext context, AppStore store) {
  return _showLogValueSheet(
    context,
    title: 'Registrar peso',
    unit: 'kg',
    decimal: true,
    textFor: (day) {
      final entry = store.weightOn(day);
      return entry == null ? '' : formatKg(entry.kg);
    },
    // Se acepta coma o punto decimal: "78,4" o "78.4".
    onSave: (text, day) {
      final kg = double.tryParse(text.replaceAll(',', '.'));
      if (kg == null) return 'Escribe tu peso en kg (por ejemplo, 78,4).';
      return store.saveWeight(kg, day: day);
    },
  );
}

/// Abre la hoja para apuntar los pasos de un día (hoy por defecto).
Future<void> showStepsSheet(BuildContext context, AppStore store) {
  return _showLogValueSheet(
    context,
    title: 'Registrar pasos',
    unit: 'pasos',
    decimal: false,
    textFor: (day) {
      final entry = store.stepsOn(day);
      return entry == null ? '' : '${entry.steps}';
    },
    // Se quitan los puntos de miles por si escribe "8.500".
    onSave: (text, day) {
      final count = int.tryParse(text.replaceAll('.', ''));
      if (count == null) return 'Escribe los pasos (un número entero).';
      return store.saveSteps(count, day: day);
    },
  );
}

Future<void> _showLogValueSheet(
  BuildContext context, {
  required String title,
  required String unit,
  required bool decimal,
  required String Function(DateTime day) textFor,
  required String? Function(String text, DateTime day) onSave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    // Para que la hoja suba con el teclado.
    isScrollControlled: true,
    builder: (_) => _LogValueSheet(
      title: title,
      unit: unit,
      decimal: decimal,
      textFor: textFor,
      onSave: onSave,
    ),
  );
}

/// Hoja con el día (hoy por defecto, se puede cambiar), un campo numérico
/// y el botón "Guardar".
class _LogValueSheet extends StatefulWidget {
  const _LogValueSheet({
    required this.title,
    required this.unit,
    required this.decimal,
    required this.textFor,
    required this.onSave,
  });

  final String title;
  final String unit;
  final bool decimal;

  /// Valor ya guardado de ese día (para rellenar el campo), o ''.
  final String Function(DateTime day) textFor;

  /// Guarda y devuelve el mensaje de error (se muestra debajo del campo) o
  /// null si se guardó.
  final String? Function(String text, DateTime day) onSave;

  @override
  State<_LogValueSheet> createState() => _LogValueSheetState();
}

class _LogValueSheetState extends State<_LogValueSheet> {
  DateTime _day = DateTime.now();
  late final _controller = TextEditingController(text: widget.textFor(_day));
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Abre el calendario. Se puede elegir desde hace un año hasta hoy.
  Future<void> _pickDay() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(now.year, now.month, now.day - maxLogDaysBack),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _day = picked;
      _controller.text = widget.textFor(picked);
      _error = null;
    });
  }

  void _save() {
    final error = widget.onSave(_controller.text.trim(), _day);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // viewInsets.bottom es el alto del teclado.
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ActionChip(
                tooltip: 'Cambiar el día',
                avatar: const Icon(Icons.calendar_today, size: 16),
                label: Text(relativeDayLabel(_day, DateTime.now())),
                onPressed: _pickDay,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.numberWithOptions(
              decimal: widget.decimal,
            ),
            // Solo cifras y, si es decimal, coma o punto.
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(widget.decimal ? r'[0-9.,]' : r'[0-9.]'),
              ),
            ],
            decoration: InputDecoration(
              suffixText: widget.unit,
              errorText: _error,
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
  }
}
