import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../widgets/brand.dart';
import '../../widgets/pill_nav_bar.dart';
import 'clients_screen.dart';
import 'link_requests_tab.dart';
import 'notes_screen.dart';
import 'trainer_profile_screen.dart';

/// Modo entrenador: su propia barra de navegación (solo iconos) con
/// Clientes, Solicitudes, Notas y Mi perfil de entrenador. Es como
/// [MainShell], pero para gestionar a los clientes.
///
/// Carga los datos de los clientes al abrirse y cada vez que cambian sus
/// clientes (por ejemplo, al aceptar una solicitud).
class TrainerShell extends StatefulWidget {
  const TrainerShell({super.key});

  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  int _index = 0;

  static const _requestsIndex = 1;

  void _select(int index) => setState(() => _index = index);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = SessionScope.of(context);
    if (store.clientOverviewsOutdated && !store.clientsLoading) {
      // Después de este frame: cargar avisa a la pantalla (notifyListeners)
      // y no se puede hacer mientras se está construyendo.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => store.loadClientOverviews(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final pages = [
      ClientsScreen(onOpenRequests: () => _select(_requestsIndex)),
      Scaffold(
        appBar: const BrandAppBar(title: 'Solicitudes'),
        body: LinkRequestsTab(store: store),
      ),
      const NotesScreen(),
      const TrainerProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: PillNavBar(
        showLabels: false,
        selectedIndex: _index,
        onSelected: _select,
        items: [
          const PillNavItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: 'Clientes',
          ),
          PillNavItem(
            icon: Icons.person_add_alt,
            selectedIcon: Icons.person_add_alt_1,
            label: 'Solicitudes',
            badge: store.pendingRequests.length,
          ),
          PillNavItem(
            icon: Icons.chat_bubble_outline,
            selectedIcon: Icons.chat_bubble,
            label: 'Notas',
            badge: store.unreadClientNotes,
          ),
          const PillNavItem(
            icon: Icons.badge_outlined,
            selectedIcon: Icons.badge,
            label: 'Mi perfil de entrenador',
          ),
        ],
      ),
    );
  }
}
