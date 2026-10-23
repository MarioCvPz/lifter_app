import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/help.dart';
import '../routines/routine_widgets.dart';

/// Panel de entrenadores: crear rutinas y asignarlas a usuarios.
class TrainerScreen extends StatelessWidget {
  const TrainerScreen({super.key});

  Future<void> _assign(BuildContext context) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final List<AppUser> users;
    try {
      users = (await store.fetchUsers())
          .where((u) => u.uid != store.currentUid)
          .toList();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron cargar los usuarios: $e')),
      );
      return;
    }
    if (!context.mounted) return;

    final to = await showModalBottomSheet<AppUser>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _UserPicker(users: users),
    );
    if (to == null || !context.mounted) return;

    final routine = await showRoutineEditor(
      context,
      title: 'Rutina para ${to.profile.name}',
      templateName: 'Entrenador',
    );
    if (routine == null) return;

    store.assignRoutine(to, routine);
    messenger.showSnackBar(
      SnackBar(content: Text('Rutina asignada a ${to.profile.name}.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final assigned = store.assignedByMe;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de entrenador'),
        actions: const [HelpButton(HelpTopic.trainer)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _assign(context),
        icon: const Icon(Icons.assignment_add),
        label: const Text('Asignar rutina'),
      ),
      body: assigned.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Todavía no has asignado rutinas.\n'
                  'Pulsa "Asignar rutina", elige un usuario y crea su tabla.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                for (final a in assigned)
                  RoutineCard(
                    routine: a.routine,
                    caption: 'Para ${a.userName}',
                    showUse: false,
                    onDelete: () => store.deleteAssignedRoutine(a.id),
                  ),
              ],
            ),
    );
  }
}

class _UserPicker extends StatefulWidget {
  const _UserPicker({required this.users});

  final List<AppUser> users;

  @override
  State<_UserPicker> createState() => _UserPickerState();
}

class _UserPickerState extends State<_UserPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final visible = widget.users
        .where(
          (u) =>
              q.isEmpty ||
              u.profile.name.toLowerCase().contains(q) ||
              u.profile.email.toLowerCase().contains(q),
        )
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            Text(
              '¿Para quién es la rutina?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 8),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No hay usuarios que coincidan.'),
              ),
            for (final u in visible)
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(u.profile.name),
                subtitle: Text(u.profile.email),
                onTap: () => Navigator.pop(ctx, u),
              ),
          ],
        );
      },
    );
  }
}
