import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/catalog.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import 'catalog_screens.dart';

/// Panel solo para admins: resumen de la app, usuarios y roles, y catálogo
/// (alimentos, ejercicios y plantillas).
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _query = TextEditingController();
  List<AppUser>? _users;
  Map<String, List<Workout>>? _workouts;
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
    final store = SessionScope.of(context);
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        store.fetchUsers(),
        store.fetchAllWorkouts(),
      ]);
      if (!mounted) return;
      setState(() {
        _users = results[0] as List<AppUser>;
        _workouts = results[1] as Map<String, List<Workout>>;
      });
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Resumen'),
              Tab(text: 'Usuarios'),
              Tab(text: 'Catálogo'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _loadingOr(_summaryTab),
            _loadingOr(_usersTab),
            const _CatalogTab(),
          ],
        ),
      ),
    );
  }

  Widget _loadingOr(Widget Function() child) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_users == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load, child: child());
  }

  // ------------------------------------------------------------ Resumen --

  Widget _summaryTab() {
    final store = SessionScope.of(context);
    final users = _users!;
    final byUser = _workouts ?? const {};
    final all = [for (final list in byUser.values) ...list];

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final thisWeek = all.where((w) => !w.date.isBefore(monday)).length;
    final active = byUser.entries
        .where((e) => e.value.any((w) => w.date.isAfter(weekAgo)))
        .length;
    final avgMin = all.isEmpty
        ? 0
        : all.fold(0, (s, w) => s + w.durationMin) / all.length;

    // Entrenos de toda la app en las últimas 8 semanas.
    const weeks = 8;
    final perWeek = List.filled(weeks, 0);
    for (final w in all) {
      final wMonday = DateTime(
        w.date.year,
        w.date.month,
        w.date.day - (w.date.weekday - 1),
      );
      // Se redondea por si hay cambio de hora entre medias.
      final ago = (monday.difference(wMonday).inHours / (24 * 7)).round();
      if (ago >= 0 && ago < weeks) perWeek[weeks - 1 - ago]++;
    }

    // Ejercicios más usados por todos.
    final counts = <String, int>{};
    for (final w in all) {
      for (final e in w.exercises) {
        counts[e.exercise.name] = (counts[e.exercise.name] ?? 0) + 1;
      }
    }
    final top = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            for (final role in UserRole.values)
              _Stat(
                value: '${users.where((u) => u.profile.role == role).length}',
                label: role.label,
              ),
          ],
        ),
        Row(
          children: [
            _Stat(value: '$active', label: 'activos (7 días)'),
            _Stat(value: '$thisWeek', label: 'entrenos esta semana'),
            _Stat(value: '${avgMin.round()} min', label: 'duración media'),
          ],
        ),
        Row(
          children: [
            _Stat(value: '${store.foods.length}', label: 'alimentos'),
            _Stat(value: '${store.exercises.length}', label: 'ejercicios'),
            _Stat(value: '${store.templates.length}', label: 'plantillas'),
          ],
        ),
        const SizedBox(height: 20),
        const SectionHeader('Entrenos en la app (8 semanas)'),
        _Bars(values: perWeek),
        const SizedBox(height: 20),
        const SectionHeader('Ejercicios más usados'),
        if (top.isEmpty) const Text('Todavía no hay entrenos registrados.'),
        for (final e in top.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.key),
            trailing: Text('${e.value} veces'),
          ),
        const SizedBox(height: 20),
        const SectionHeader('Usuarios sin entrenar en 2 semanas'),
        ..._inactiveUsers(users, byUser),
      ],
    );
  }

  List<Widget> _inactiveUsers(
    List<AppUser> users,
    Map<String, List<Workout>> byUser,
  ) {
    final limit = DateTime.now().subtract(const Duration(days: 14));
    final inactive = users
        .where(
          (u) => !(byUser[u.uid] ?? const []).any((w) => w.date.isAfter(limit)),
        )
        .toList();
    if (inactive.isEmpty) return [const Text('Todos han entrenado.')];
    return [
      for (final u in inactive)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_off_outlined),
          title: Text(u.profile.name),
          subtitle: Text(u.profile.email),
        ),
    ];
  }

  // ----------------------------------------------------------- Usuarios --

  Widget _usersTab() {
    final myUid = SessionScope.of(context).currentUid;
    final q = _query.text.trim().toLowerCase();
    final visible = _users!
        .where(
          (u) =>
              q.isEmpty ||
              u.profile.name.toLowerCase().contains(q) ||
              u.profile.email.toLowerCase().contains(q),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _query,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Buscar por nombre o correo',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        for (final u in visible)
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
              subtitle: Text(
                '${u.profile.email}\n'
                '${(_workouts?[u.uid] ?? const []).length} entrenos',
              ),
              isThreeLine: true,
              trailing: u.uid == myUid
                  ? Chip(label: Text('${u.profile.role.label} (tú)'))
                  : DropdownButton<UserRole>(
                      value: u.profile.role,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final r in UserRole.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (r) {
                        if (r != null) _changeRole(u, r);
                      },
                    ),
            ),
          ),
      ],
    );
  }
}

// -------------------------------------------------------------- Catálogo --

class _CatalogTab extends StatelessWidget {
  const _CatalogTab();

  Future<void> _seed(BuildContext context) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cargar catálogo inicial?'),
        content: const Text(
          'Se suben a Firebase los alimentos, ejercicios y plantillas de '
          'ejemplo. Si ya existen con el mismo id se sobrescriben; lo demás '
          'no se toca.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await store.seedCatalog();
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Catálogo cargado en Firebase.')),
    );
  }

  /// "1 plantilla" / "3 plantillas".
  static String _templatesText(int n) =>
      n == 1 ? '1 plantilla' : '$n plantillas';

  /// Sube los ejercicios del archivo y crea las plantillas que faltan,
  /// tras confirmar cuántos son.
  Future<void> _updateExercises(BuildContext context) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    // Se lee el archivo antes para poder decir cuánto se va a subir.
    final seed = await CatalogSeed.load();
    final count = seed.exercises.length;
    final newTemplates = store.missingSeedTemplates(seed).length;
    if (!context.mounted) return;
    final templatesPart = newTemplates == 0
        ? '. No falta ninguna plantilla'
        : ' y se crearán ${_templatesText(newTemplates)} que faltan';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Actualizar ejercicios?'),
        content: Text(
          'Se subirán $count ejercicios$templatesPart. Los ejercicios que '
          'ya existen se sobrescriben y se actualizan en las plantillas. '
          'Las plantillas que ya existen y los alimentos no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await store.updateExercisesFromSeed(seed);
    final done = newTemplates == 0
        ? '$count ejercicios actualizados.'
        : '$count ejercicios actualizados y '
              '${_templatesText(newTemplates)} '
              '${newTemplates == 1 ? 'creada' : 'creadas'}.';
    messenger.showSnackBar(SnackBar(content: Text(error ?? done)));
  }

  /// Sube los alimentos del archivo, tras confirmar cuántos son.
  Future<void> _updateFoods(BuildContext context) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final seed = await CatalogSeed.load();
    final count = seed.foods.length;
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Actualizar alimentos?'),
        content: Text(
          'Se subirán $count alimentos. Los que ya existen con el mismo id '
          'se sobrescriben; los que has creado a mano, los ejercicios y las '
          'plantillas no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final error = await store.updateFoodsFromSeed(seed);
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? '$count alimentos actualizados.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    void open(Widget page) => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => page));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (store.catalogEmpty)
          Card(
            color: AppTheme.coral.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'El catálogo está vacío',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Los usuarios no verán alimentos, ejercicios ni '
                    'plantillas hasta que cargues el catálogo inicial o '
                    'añadas elementos a mano.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _seed(context),
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Cargar catálogo inicial'),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant),
            title: const Text('Alimentos'),
            subtitle: Text('${store.foods.length} en el catálogo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const FoodsAdminScreen()),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.fitness_center),
            title: const Text('Ejercicios'),
            subtitle: Text('${store.exercises.length} en el catálogo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const ExercisesAdminScreen()),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Plantillas de rutina'),
            subtitle: Text('${store.templates.length} en el catálogo'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(const TemplatesAdminScreen()),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _updateExercises(context),
          icon: const Icon(Icons.sync),
          label: const Text('Actualizar ejercicios desde el archivo'),
        ),
        TextButton.icon(
          onPressed: () => _updateFoods(context),
          icon: const Icon(Icons.sync),
          label: const Text('Actualizar alimentos desde el archivo'),
        ),
        if (!store.catalogEmpty) ...[
          TextButton.icon(
            onPressed: () => _seed(context),
            icon: const Icon(Icons.restore),
            label: const Text('Volver a cargar el catálogo inicial'),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  value,
                  style: text.headlineSmall?.copyWith(
                    color: AppTheme.coral,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(label, textAlign: TextAlign.center, style: text.labelSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({required this.values});

  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final max = values.fold(1, (a, b) => a > b ? a : b);
    const height = 90.0;
    return SizedBox(
      height: height + 20,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${values[i]}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  Container(
                    height: height * values[i] / max,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == values.length - 1
                          ? AppTheme.coral
                          : AppTheme.coral.withValues(alpha: 0.45),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
