import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_overview.dart';
import '../../data/client_report.dart';
import '../../models/models.dart';
import '../workouts/exercise_card.dart';

/// Pestaña "Notas" de la ficha: los comentarios que el cliente ha dejado
/// en sus ejercicios, con "Responder". Al abrirla se marcan como leídas
/// (lo hace [ClientScreen]).
class ClientNotesTab extends StatelessWidget {
  const ClientNotesTab({super.key, required this.client});

  final ClientOverview client;

  @override
  Widget build(BuildContext context) {
    final notes = client.notes;
    if (notes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No te ha dejado notas en las últimas semanas.\nLas escribe '
            'desde el menú de cada ejercicio durante el entreno.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final note in notes)
          NoteTile(note: note, onReply: () => showReplyDialog(context, note)),
      ],
    );
  }
}

/// Una nota: ejercicio, fecha (y cliente, si [showClient]), el texto y la
/// respuesta si ya la hay. Con [onReply] sale el botón "Responder"; con
/// [onTap], toda la tarjeta se puede tocar.
class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.note,
    this.showClient = false,
    this.onReply,
    this.onTap,
  });

  final ClientNote note;
  final bool showClient;
  final VoidCallback? onReply;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final reply = note.replyText;
    final details = [
      if (showClient) note.clientName,
      note.exercise.name,
      longDate(note.date),
    ].join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!note.isRead) ...[
                    Badge(
                      backgroundColor: scheme.primary,
                      label: const Text('Nueva'),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      details,
                      style: text.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('"${note.text}"', style: text.bodyLarge),
              if (reply != null)
                TrainerNoteBox(reply, prefix: 'Tu respuesta: '),
              if (onReply != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onReply,
                    icon: const Icon(Icons.reply),
                    label: Text(reply == null ? 'Responder' : 'Cambiar'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo para responder a [note] (o cambiar la respuesta). Guarda con
/// [AppStore.replyToNote] y avisa si falla.
Future<void> showReplyDialog(BuildContext context, ClientNote note) {
  return showDialog<void>(context: context, builder: (_) => _ReplyDialog(note));
}

class _ReplyDialog extends StatefulWidget {
  const _ReplyDialog(this.note);

  final ClientNote note;

  @override
  State<_ReplyDialog> createState() => _ReplyDialogState();
}

class _ReplyDialogState extends State<_ReplyDialog> {
  late final _controller = TextEditingController(text: widget.note.replyText);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final store = SessionScope.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = CoachReply.validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    navigator.pop();
    final saveError = await store.replyToNote(widget.note, _controller.text);
    messenger.showSnackBar(
      SnackBar(content: Text(saveError ?? 'Respuesta enviada.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Responder a ${widget.note.clientName}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.note.exercise.name}: "${widget.note.text}"',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 3,
              maxLength: CoachReply.maxLength,
              decoration: InputDecoration(
                labelText: 'Tu respuesta',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}
