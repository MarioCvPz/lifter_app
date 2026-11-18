import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_store.dart';
import '../../widgets/confirm_dialog.dart';

/// Tarjeta "Mi código" del panel de entrenador: el código en grande, para
/// dárselo a los clientes, con "Copiar" y "Generar otro". La primera vez
/// que se abre, crea el código.
class TrainerCodeCard extends StatefulWidget {
  const TrainerCodeCard({super.key, required this.store});

  final AppStore store;

  @override
  State<TrainerCodeCard> createState() => _TrainerCodeCardState();
}

class _TrainerCodeCardState extends State<TrainerCodeCard> {
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.store.user?.trainerCode == null) {
      _run(widget.store.ensureTrainerCode);
    }
  }

  /// Ejecuta [action] (crear o regenerar) mostrando que trabaja y el error.
  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    final error = await action();
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = error;
    });
  }

  Future<void> _copy(String code) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(const SnackBar(content: Text('Código copiado.')));
  }

  Future<void> _regenerate() async {
    final ok = await confirmAction(
      context,
      title: '¿Generar otro código?',
      message:
          'El código actual dejará de valer para nuevas solicitudes. Tus '
          'clientes ya vinculados siguen contigo.',
      confirmLabel: 'Generar otro',
    );
    if (ok) await _run(widget.store.regenerateTrainerCode);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final code = widget.store.user?.trainerCode;
    final error = _error;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mi código', style: text.titleMedium),
            Text(
              'Dáselo a tu cliente para que te envíe una solicitud desde '
              'Perfil → Mi entrenador.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (code == null)
              _working
                  ? const LinearProgressIndicator()
                  : const Text('Todavía no tienes código.')
            else
              SelectableText(
                code,
                style: text.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: scheme.primary,
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (code != null)
                  FilledButton.tonalIcon(
                    onPressed: () => _copy(code),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar'),
                  ),
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : code == null
                      ? () => _run(widget.store.ensureTrainerCode)
                      : _regenerate,
                  icon: const Icon(Icons.refresh),
                  label: Text(code == null ? 'Crear código' : 'Generar otro'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
