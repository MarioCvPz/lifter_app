import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_report.dart';
import '../../models/models.dart';

/// Pestaña "Solicitudes": los usuarios que han enviado una solicitud con
/// mi código y aún no he aceptado ni rechazado.
class LinkRequestsTab extends StatelessWidget {
  const LinkRequestsTab({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final requests = store.pendingRequests;
    if (requests.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No tienes solicitudes pendientes.\nComparte tu código para que '
            'tus clientes te envíen una.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [for (final link in requests) _RequestTile(store, link)],
    );
  }
}

/// Una solicitud con "Aceptar" y "Rechazar".
class _RequestTile extends StatelessWidget {
  const _RequestTile(this.store, this.link);

  final AppStore store;
  final TrainerLink link;

  void _answer(BuildContext context, {required bool accept}) {
    final name = link.clientName.isEmpty ? 'El usuario' : link.clientName;
    if (accept) {
      store.acceptRequest(link.clientId);
    } else {
      store.removeClientLink(link.clientId);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept
              ? '$name ya es tu cliente.'
              : 'Has rechazado la solicitud de $name.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = link.clientName.isEmpty ? '(sin nombre)' : link.clientName;
    // Los botones van en una segunda línea para que quepan en móviles
    // estrechos.
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ListTile(
              leading: CircleAvatar(child: Text(name[0].toUpperCase())),
              title: Text(name),
              subtitle: Text('Enviada el ${longDate(link.createdAt)}'),
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => _answer(context, accept: false),
                  child: const Text('Rechazar'),
                ),
                FilledButton(
                  onPressed: () => _answer(context, accept: true),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
