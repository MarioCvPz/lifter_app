import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../widgets/help.dart';

/// Panel solo para admins: usuarios registrados y gestión de roles.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _query = TextEditingController();
  List<AppUser>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final users = await SessionScope.of(context).fetchUsers();
      if (mounted) setState(() => _users = users);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudieron cargar: $e');
    }
  }

  Future<void> _changeRole(AppUser u, UserRole role) async {
    if (role == u.profile.role) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cambiar rol?'),
        content: Text(
          '${u.profile.name} pasará de ${u.profile.role.label} '
          'a ${role.label}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await SessionScope.of(context).setRole(u.uid, role);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Rol actualizado.')));
    if (error == null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final myUid = SessionScope.of(context).currentUid;
    final users = _users;
    final q = _query.text.trim().toLowerCase();
    final visible = users
        ?.where(
          (u) =>
              q.isEmpty ||
              u.profile.name.toLowerCase().contains(q) ||
              u.profile.email.toLowerCase().contains(q),
        )
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          const HelpButton(HelpTopic.admin),
          IconButton(
            tooltip: 'Recargar',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : users == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      for (final role in UserRole.values)
                        Expanded(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    '${users.where((u) => u.profile.role == role).length}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineSmall,
                                  ),
                                  Text(role.label),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _query,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o correo',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final u in visible!)
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            u.profile.name.isEmpty
                                ? '?'
                                : u.profile.name[0].toUpperCase(),
                          ),
                        ),
                        title: Text(u.profile.name),
                        subtitle: Text(u.profile.email),
                        trailing: u.uid == myUid
                            ? Chip(label: Text('${u.profile.role.label} (tú)'))
                            : DropdownButton<UserRole>(
                                value: u.profile.role,
                                underline: const SizedBox.shrink(),
                                items: [
                                  for (final r in UserRole.values)
                                    DropdownMenuItem(
                                      value: r,
                                      child: Text(r.label),
                                    ),
                                ],
                                onChanged: (r) {
                                  if (r != null) _changeRole(u, r);
                                },
                              ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
