import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_report.dart';
import '../../data/report_export.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import '../routines/routine_widgets.dart';

/// Panel de entrenadores: sus usuarios (los que tienen alguna rutina suya),
/// la ficha de cada uno, las rutinas asignadas y los informes Excel/PDF.
class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});

  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  /// Periodos que se pueden elegir para las estadísticas, en semanas.
  static const _periods = [4, 8, 12];

  int _weeks = 4;
  bool _loading = true;
  String? _error;
  List<AppUser> _allUsers = const [];
  Map<String, List<Workout>> _workouts = const {};

  /// Clientes con los que se cargaron los datos (para recargar si cambian).
  Set<String> _loadedFor = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ids = SessionScope.of(context).myClientIds;
    if (!_sameSet(ids, _loadedFor)) _load();
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  Future<void> _load() async {
    final store = SessionScope.of(context);
    final ids = store.myClientIds;
    _loadedFor = ids;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await store.fetchUsers();
      final entries = await Future.wait([
        for (final id in ids)
          store.fetchWorkoutsOf(id).then((w) => MapEntry(id, w)),
      ]);
      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _workouts = Map.fromEntries(entries);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los datos: $e';
        _loading = false;
      });
    }
  }

  List<ClientReport> _reports(AppStore store) {
    final ids = store.myClientIds;
    final reports = [
      for (final u in _allUsers)
        if (ids.contains(u.uid))
          ClientReport(
            user: u,
            workouts: _workouts[u.uid] ?? const [],
            weeks: _weeks,
            assignedRoutineIds: {
              for (final a in store.assignedByMe)
                if (a.userId == u.uid) a.id,
            },
          ),
    ];
    return reports;
  }

  Future<void> _assign({AppUser? to}) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    var user = to;
    if (user == null) {
      final candidates = _allUsers
          .where((u) => u.uid != store.currentUid)
          .toList();
      if (candidates.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('No hay otros usuarios registrados.')),
        );
        return;
      }
      user = await showModalBottomSheet<AppUser>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (ctx) => _UserPicker(users: candidates),
      );
    }
    if (user == null || !mounted) return;

    final routine = await showRoutineEditor(
      context,
      exercises: store.exercises,
      title: 'Rutina para ${user.profile.name}',
      templateName: 'Entrenador',
    );
    if (routine == null) return;

    store.assignRoutine(user, routine);
    messenger.showSnackBar(
      SnackBar(content: Text('Rutina asignada a ${user.profile.name}.')),
    );
  }

  Future<void> _export(List<ClientReport> reports, {required bool pdf}) async {
    final store = SessionScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (reports.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Asigna una rutina a algún usuario para tener datos.'),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('Generando ${pdf ? 'PDF' : 'Excel'}…')),
    );
    final report = TrainerReport(
      trainerName: store.user?.name ?? 'Entrenador',
      clients: reports,
      weeks: _weeks,
    );
    try {
      final path = await (pdf ? report.savePdf() : report.saveExcel());
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              path.isEmpty
                  ? 'Informe descargado.'
                  : 'Informe guardado en $path',
            ),
          ),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('No se pudo generar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final reports = _loading ? <ClientReport>[] : _reports(store);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de entrenador'),
          actions: [
            const HelpButton(HelpTopic.trainer),
            PopupMenuButton<bool>(
              tooltip: 'Exportar informe',
              icon: const Icon(Icons.download),
              enabled: !_loading,
              onSelected: (pdf) => _export(reports, pdf: pdf),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: false,
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined),
                    title: Text('Excel (.xlsx)'),
                    subtitle: Text('Datos en tablas'),
                  ),
                ),
                PopupMenuItem(
                  value: true,
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('PDF'),
                    subtitle: Text('Resumen con gráficas'),
                  ),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Usuarios'),
              Tab(text: 'Asignadas'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _loading ? null : () => _assign(),
          icon: const Icon(Icons.assignment_add),
          label: const Text('Asignar rutina'),
        ),
        body: TabBarView(children: [_clientsTab(reports), _assignedTab(store)]),
      ),
    );
  }

  Widget _clientsTab(List<ClientReport> reports) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final sessions = reports.fold(0, (s, r) => s + r.sessions);
    final adherence = reports.isEmpty
        ? 0
        : reports.fold(0.0, (s, r) => s + r.adherencePct) / reports.length;
    final inactive = reports.where((r) => r.sessions == 0).length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          SegmentedButton<int>(
            segments: [
              for (final w in _periods)
                ButtonSegment(value: w, label: Text('$w semanas')),
            ],
            selected: {_weeks},
            onSelectionChanged: (s) => setState(() => _weeks = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Kpi(value: '${reports.length}', label: 'usuarios'),
              _Kpi(value: '$sessions', label: 'sesiones'),
              _Kpi(value: '${adherence.round()} %', label: 'cumplimiento'),
              _Kpi(value: '$inactive', label: 'sin entrenar'),
            ],
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Todavía no tienes usuarios.\nUn usuario pasa a ser tuyo '
                'cuando le asignas una rutina.',
                textAlign: TextAlign.center,
              ),
            ),
          for (final r in reports)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(r.name.isEmpty ? '?' : r.name[0].toUpperCase()),
                ),
                title: Text(r.name),
                subtitle: Text(
                  '${r.sessions} sesiones · ${r.adherencePct.round()} % · '
                  '${r.daysSinceLast == null ? 'sin entrenos' : 'último hace ${r.daysSinceLast} d'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openClient(r),
              ),
            ),
        ],
      ),
    );
  }

  void _openClient(ClientReport report) {
    final store = SessionScope.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _ClientSheet(
        report: report,
        assigned: [
          for (final a in store.assignedByMe)
            if (a.userId == report.user.uid) a,
        ],
        onAssign: () {
          Navigator.pop(ctx);
          _assign(to: report.user);
        },
      ),
    );
  }

  Widget _assignedTab(AppStore store) {
    final assigned = store.assignedByMe;
    if (assigned.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Todavía no has asignado rutinas.\n'
            'Pulsa "Asignar rutina", elige un usuario y crea su tabla.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
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
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                child: Text(
                  value,
                  style: text.titleLarge?.copyWith(
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

/// Ficha de un usuario: datos, sesiones por semana, ejercicios y rutinas.
class _ClientSheet extends StatelessWidget {
  const _ClientSheet({
    required this.report,
    required this.assigned,
    required this.onAssign,
  });

  final ClientReport report;
  final List<AssignedRoutine> assigned;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final p = report.user.profile;
    final top = report.topExercises();
    final comments = report.recentComments();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (ctx, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(report.name, style: text.headlineSmall),
          Text(
            '${p.email} · ${p.goal.label} · ${p.experience} · '
            '${p.daysPerWeek} días/semana',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Kpi(value: '${report.sessions}', label: 'sesiones'),
              _Kpi(
                value: '${report.adherencePct.round()} %',
                label: 'cumplimiento',
              ),
              _Kpi(value: '${report.minutes}', label: 'minutos'),
              _Kpi(
                value: '${(report.volumeKg / 1000).toStringAsFixed(1)} t',
                label: 'volumen',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            report.daysSinceLast == null
                ? 'No ha registrado ningún entreno.'
                : 'Último entreno: ${longDate(report.lastWorkout!)} '
                      '(hace ${report.daysSinceLast} días). '
                      '${report.assignedSessions} sesiones con tus rutinas.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: 20),
          SectionHeader('Sesiones por semana'),
          _WeekBars(report: report),
          if (top.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader('Ejercicios más hechos'),
            for (final e in top)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.name),
                subtitle: Text('${e.times} veces · ${e.sets} series'),
                trailing: Text(
                  'máx. ${e.bestKg.toStringAsFixed(e.bestKg % 1 == 0 ? 0 : 1)} kg',
                ),
              ),
          ],
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 20),
            SectionHeader('Comentarios recientes'),
            for (final c in comments)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(c.text),
                subtitle: Text('${c.exercise} · ${longDate(c.date)}'),
              ),
          ],
          const SizedBox(height: 20),
          SectionHeader('Rutinas que le has asignado'),
          if (assigned.isEmpty) const Text('Ninguna.'),
          for (final a in assigned)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.assignment_outlined),
              title: Text(a.routine.name),
              subtitle: Text(
                '${a.routine.exercises.length} ejercicios · '
                'desde ${longDate(a.createdAt)}',
              ),
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.assignment_add),
            label: const Text('Asignarle otra rutina'),
          ),
        ],
      ),
    );
  }
}

/// Barras sencillas de sesiones por semana con la línea de su objetivo.
class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.report});

  final ClientReport report;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final values = report.sessionsByWeek;
    final goal = report.daysPerWeek;
    final max = [...values, goal, 1].reduce((a, b) => a > b ? a : b);
    const height = 110.0;

    return SizedBox(
      height: height + 36,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 36 + height * goal / max,
            child: Container(height: 1, color: scheme.outline),
          ),
          Row(
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
                          color: values[i] >= goal
                              ? AppTheme.coral
                              : AppTheme.coral.withValues(alpha: 0.45),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          child: Text(
                            shortDate(report.weekStarts[i]),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
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
