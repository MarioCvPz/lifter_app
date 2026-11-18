import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/app_store.dart';
import '../../data/client_overview.dart';
import '../../widgets/help.dart';
import '../../widgets/mode_switch.dart';
import 'client_screen.dart';
import 'client_widgets.dart';

/// Pestaña "Clientes" del modo entrenador: "Mis clientes" con el resumen,
/// el aviso de solicitudes, el buscador, los filtros y un cliente por fila
/// (primero los que necesitan atención). Los datos los carga
/// [TrainerShell]; aquí se recargan al tirar hacia abajo.
class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.onOpenRequests});

  /// Lleva a la pestaña Solicitudes.
  final VoidCallback onOpenRequests;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  String _query = '';
  ClientFilter _filter = ClientFilter.all;

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final clients = store.clientOverviews;
    final visible = ClientOverview.visible(
      clients,
      filter: _filter,
      query: _query,
    );
    final pending = store.pendingRequests.length;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: store.loadClientOverviews,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              const ModeSwitch(),
              const SizedBox(height: 16),
              _Header(clients: clients),
              if (pending > 0) ...[
                const SizedBox(height: 12),
                _RequestsBanner(count: pending, onTap: widget.onOpenRequests),
              ],
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Buscar cliente',
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 8),
              _FilterChips(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: 8),
              ..._body(store, visible),
            ],
          ),
        ),
      ),
    );
  }

  /// Rueda, error, lista vacía o las filas de los clientes.
  List<Widget> _body(AppStore store, List<ClientOverview> visible) {
    final error = store.clientsError;
    if (store.clientsLoading && store.clientOverviews.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (error != null) {
      return [
        _Message(error),
        Center(
          child: FilledButton(
            onPressed: store.loadClientOverviews,
            child: const Text('Reintentar'),
          ),
        ),
      ];
    }
    if (store.clientOverviews.isEmpty) {
      return const [
        _Message(
          'Todavía no tienes clientes.\nComparte tu código: cuando te '
          'envíen una solicitud y la aceptes, aparecerán aquí.',
        ),
      ];
    }
    if (visible.isEmpty) {
      return const [_Message('Ningún cliente coincide con la búsqueda.')];
    }
    return [for (final c in visible) _ClientRow(c)];
  }
}

/// "Mis clientes", "12 clientes · 3 necesitan atención", la ayuda y el
/// botón con el código.
class _Header extends StatelessWidget {
  const _Header({required this.clients});

  final List<ClientOverview> clients;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final attention = clients.where((c) => c.needsAttention).length;
    final count = clients.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mis clientes', style: text.headlineSmall),
              Text(
                '$count ${count == 1 ? 'cliente' : 'clientes'} · '
                '$attention ${attention == 1 ? 'necesita' : 'necesitan'} '
                'atención',
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const HelpButton(HelpTopic.trainer),
        const _CodeButton(),
      ],
    );
  }
}

/// Botón con mi código: al tocarlo se copia. Si aún no tengo, lo crea.
class _CodeButton extends StatelessWidget {
  const _CodeButton();

  Future<void> _onTap(BuildContext context, AppStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    final code = store.user?.trainerCode;
    if (code == null) {
      final error = await store.ensureTrainerCode();
      if (error != null) {
        messenger.showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    messenger.showSnackBar(const SnackBar(content: Text('Código copiado.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final code = store.user?.trainerCode;
    return ActionChip(
      avatar: Icon(code == null ? Icons.key : Icons.copy, size: 18),
      label: Text(code ?? 'Crear código'),
      tooltip: code == null ? 'Crear mi código' : 'Copiar mi código',
      onPressed: () => _onTap(context, store),
    );
  }
}

/// Aviso destacado: "2 solicitudes nuevas para aceptar".
class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = count == 1
        ? '1 solicitud nueva para aceptar'
        : '$count solicitudes nuevas para aceptar';
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.tertiaryContainer,
      child: ListTile(
        leading: Icon(Icons.person_add_alt, color: scheme.onTertiaryContainer),
        title: Text(
          text,
          style: TextStyle(
            color: scheme.onTertiaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: scheme.onTertiaryContainer),
        onTap: onTap,
      ),
    );
  }
}

/// Chips "Todos · Necesitan atención · Al día".
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final ClientFilter selected;
  final ValueChanged<ClientFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final filter in ClientFilter.values)
          ChoiceChip(
            label: Text(filter.label),
            selected: filter == selected,
            onSelected: (_) => onSelected(filter),
          ),
      ],
    );
  }
}

/// Un cliente: iniciales, nombre, "Objetivo · Entrenos 2/4 · último: ayer",
/// su aviso más grave (si tiene) y la nota de la semana.
class _ClientRow extends StatelessWidget {
  const _ClientRow(this.client);

  final ClientOverview client;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final alert = client.alert;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openClientScreen(context, client.uid),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClientAvatar(client),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.name, style: text.titleMedium),
                    Text(
                      client.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (alert != null) ...[
                      const SizedBox(height: 4),
                      AlertLine(alert),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ScoreCircle(score: client.score),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    );
  }
}
