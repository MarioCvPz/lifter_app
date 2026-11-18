import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_overview.dart';
import '../../widgets/confirm_dialog.dart';
import 'client_notes.dart';
import 'client_plan_tab.dart';
import 'client_summary_tab.dart';
import 'client_targets_tab.dart';
import 'client_widgets.dart';
import 'trainer_actions.dart';

/// Pestañas de la ficha de un cliente, en orden.
enum ClientTab {
  summary('Resumen'),
  plan('Plan'),
  targets('Objetivos'),
  notes('Notas');

  const ClientTab(this.label);

  final String label;
}

/// Abre la ficha del cliente [clientId] en la pestaña [tab].
void openClientScreen(
  BuildContext context,
  String clientId, {
  ClientTab tab = ClientTab.summary,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ClientScreen(clientId: clientId, initialTab: tab),
    ),
  );
}

/// Ficha de un cliente: cabecera (iniciales, nombre, objetivo, nivel,
/// lugar y días; "Desvincular" en el menú) y cuatro pestañas: Resumen,
/// Plan, Objetivos y Notas. Lee los datos ya cargados del cliente
/// ([AppStore.overviewOf]); al abrir Notas, las marca como leídas.
class ClientScreen extends StatefulWidget {
  const ClientScreen({
    super.key,
    required this.clientId,
    this.initialTab = ClientTab.summary,
  });

  final String clientId;
  final ClientTab initialTab;

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

// SingleTickerProviderStateMixin da el "reloj" que el TabController
// necesita para animar el cambio de pestaña.
class _ClientScreenState extends State<ClientScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: ClientTab.values.length,
    vsync: this,
    initialIndex: widget.initialTab.index,
  );

  @override
  void initState() {
    super.initState();
    _tabs.addListener(_onTabChanged);
    if (widget.initialTab == ClientTab.notes) {
      // Después del primer frame: aquí aún no se puede usar el context
      // para leer el store.
      WidgetsBinding.instance.addPostFrameCallback((_) => _markNotesRead());
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // El listener también salta durante la animación; solo cuenta al final.
    if (!_tabs.indexIsChanging && _tabs.index == ClientTab.notes.index) {
      _markNotesRead();
    }
  }

  void _markNotesRead() {
    if (!mounted) return;
    SessionScope.of(context).markNotesRead(widget.clientId);
  }

  Future<void> _unlink(ClientOverview client) async {
    final store = SessionScope.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmAction(
      context,
      title: '¿Desvincular a ${client.name}?',
      message:
          'Dejarás de ver sus datos y de poder cambiar su plan. Lo que le '
          'hayas puesto se le queda, pero tus notas dejarán de verse.',
      confirmLabel: 'Desvincular',
      danger: true,
    );
    if (!ok) return;
    store.removeClientLink(client.uid);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final client = store.overviewOf(widget.clientId);
    if (client == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Este cliente ya no está en tu lista.')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: _ClientHeader(client),
        actions: [
          PopupMenuButton<void>(
            tooltip: 'Más opciones',
            itemBuilder: (_) => [
              PopupMenuItem(
                onTap: () => _unlink(client),
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.link_off),
                  title: Text('Desvincular'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            for (final tab in ClientTab.values)
              Tab(
                child: Badge(
                  isLabelVisible:
                      tab == ClientTab.notes && client.unreadNotes > 0,
                  label: Text('${client.unreadNotes}'),
                  child: Text(tab.label),
                ),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          ClientSummaryTab(
            client: client,
            assigned: [
              for (final a in store.assignedByMe)
                if (a.userId == client.uid) a,
            ],
            onAssign: () => assignRoutineTo(context, client.user),
          ),
          ClientPlanTab(client: client.user),
          ClientTargetsTab(client: client.user),
          ClientNotesTab(client: client),
        ],
      ),
    );
  }
}

/// Iniciales, nombre y "Ganar masa · Intermedio · Gimnasio · 4 días".
class _ClientHeader extends StatelessWidget {
  const _ClientHeader(this.client);

  final ClientOverview client;

  @override
  Widget build(BuildContext context) {
    final p = client.profile;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        ClientAvatar(client),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(client.name, overflow: TextOverflow.ellipsis),
              Text(
                '${p.goal.label} · ${p.experience} · '
                '${p.trainingPlace.label} · ${p.daysPerWeek} días',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
