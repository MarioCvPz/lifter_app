import 'package:flutter/material.dart';

import '../../data/workout_draft.dart';

/// Abre la hoja del temporizador de descanso: los tiempos (30 s … 3:00) y
/// el interruptor "Descanso automático". Devuelve los segundos elegidos, o
/// null si se cierra sin elegir. El interruptor avisa al momento con
/// [onAutoRestChanged].
Future<int?> showRestTimerSheet(
  BuildContext context, {
  required bool autoRest,
  required ValueChanged<bool> onAutoRestChanged,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (_) => _RestTimerSheet(
      autoRest: autoRest,
      onAutoRestChanged: onAutoRestChanged,
    ),
  );
}

class _RestTimerSheet extends StatefulWidget {
  const _RestTimerSheet({
    required this.autoRest,
    required this.onAutoRestChanged,
  });

  final bool autoRest;
  final ValueChanged<bool> onAutoRestChanged;

  @override
  State<_RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<_RestTimerSheet> {
  // Copia local del interruptor para que la hoja se repinte al cambiarlo.
  late bool _autoRest = widget.autoRest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Temporizador de descanso',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final seconds in RestCountdown.options)
                ActionChip(
                  label: Text(formatRest(seconds)),
                  onPressed: () => Navigator.pop(context, seconds),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Descanso automático'),
            subtitle: const Text(
              'Al marcar una serie, empieza el descanso de ese ejercicio.',
            ),
            value: _autoRest,
            onChanged: (value) {
              setState(() => _autoRest = value);
              widget.onAutoRestChanged(value);
            },
          ),
        ],
      ),
    );
  }
}

/// Barra fija de abajo con la cuenta atrás, "−15 s", "+15 s" y "Saltar".
class RestTimerBar extends StatelessWidget {
  const RestTimerBar({
    super.key,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.onAdd,
    required this.onSubtract,
    required this.onSkip,
  });

  final int remainingSeconds;
  final int totalSeconds;
  final VoidCallback onAdd;
  final VoidCallback onSubtract;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: totalSeconds == 0 ? 0 : remainingSeconds / totalSeconds,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Descanso ${formatRest(remainingSeconds)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onSubtract,
                    child: const Text('−${RestCountdown.step} s'),
                  ),
                  TextButton(
                    onPressed: onAdd,
                    child: const Text('+${RestCountdown.step} s'),
                  ),
                  FilledButton.tonal(
                    onPressed: onSkip,
                    child: const Text('Saltar'),
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
