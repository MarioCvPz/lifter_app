import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_store.dart';
import '../../data/trainer_link.dart';
import '../../widgets/confirm_dialog.dart';

/// Tarjeta "Mi entrenador" de Perfil. Tiene tres estados
/// ([AppStore.myTrainerState]): sin entrenador (campo para el código),
/// solicitud pendiente y vinculado.
class MyTrainerCard extends StatelessWidget {
  const MyTrainerCard({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final link = store.myTrainerLink;
    final Widget body = switch (store.myTrainerState) {
      MyTrainerState.none => _CodeForm(store: store),
      MyTrainerState.pending => _LinkInfo(
        text:
            'Solicitud enviada a ${link?.trainerName ?? 'tu entrenador'}. '
            'Cuando la acepte, podrá ver tus entrenos y ajustar tu plan.',
        buttonLabel: 'Cancelar solicitud',
        onPressed: store.leaveTrainer,
      ),
      MyTrainerState.linked => _LinkInfo(
        title: link?.trainerName ?? 'Tu entrenador',
        text:
            'Ve tus entrenos y puede ajustar tu plan, tus calorías y tus '
            'pasos.',
        buttonLabel: 'Desvincular',
        onPressed: () => _confirmUnlink(context),
      ),
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sports,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Mi entrenador',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: '¿Desvincularte de tu entrenador?',
      message:
          'Dejará de ver tus datos. Tu plan y tus objetivos se quedan como '
          'están y luego los puedes cambiar tú.',
      confirmLabel: 'Desvincular',
      danger: true,
    );
    if (ok) store.leaveTrainer();
  }
}

/// Sin entrenador: campo "Código de tu entrenador" y "Enviar solicitud".
class _CodeForm extends StatefulWidget {
  const _CodeForm({required this.store});

  final AppStore store;

  @override
  State<_CodeForm> createState() => _CodeFormState();
}

class _CodeFormState extends State<_CodeForm> {
  final _controller = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final error = await widget.store.sendTrainerRequest(_controller.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Si tienes entrenador, pídele su código y envíale una solicitud.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          maxLength: TrainerCode.length,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
          ],
          decoration: InputDecoration(
            labelText: 'Código de tu entrenador',
            errorText: _error,
            errorMaxLines: 3,
            counterText: '',
          ),
          onSubmitted: (_) => _send(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sending ? null : _send,
          icon: const Icon(Icons.send),
          label: Text(_sending ? 'Enviando…' : 'Enviar solicitud'),
        ),
      ],
    );
  }
}

/// Solicitud pendiente o vinculado: un texto y un botón.
class _LinkInfo extends StatelessWidget {
  const _LinkInfo({
    this.title,
    required this.text,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String? title;
  final String text;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          Text(
            title,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        Text(text, style: textTheme.bodyMedium),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
      ],
    );
  }
}
