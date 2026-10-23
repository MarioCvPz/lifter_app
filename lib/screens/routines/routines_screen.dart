import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import 'routine_widgets.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  final _query = TextEditingController();

  /// Grupo muscular elegido (null = todos).
  String? _group;

  /// Nivel elegido (null = todos).
  String? _level;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _filtering =>
      _query.text.trim().isNotEmpty || _group != null || _level != null;

  bool _matches(Routine r) {
    final q = _query.text.trim().toLowerCase();
    if (q.isNotEmpty &&
        !r.name.toLowerCase().contains(q) &&
        !r.exercises.any((e) => e.name.toLowerCase().contains(q))) {
      return false;
    }
    if (_group != null && !r.muscleGroups.contains(_group)) return false;
    if (_level != null && r.level != _level) return false;
    return true;
  }

  Future<void> _createRoutine(AppStore store) async {
    final routine = await showRoutineEditor(context);
    if (routine != null) store.addRoutine(routine);
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final groups = {for (final e in store.exercises) e.muscleGroup}.toList();
    final templates = store.routines
        .where((r) => r.isTemplate && _matches(r))
        .toList();
    final mine = store.routines
        .where((r) => !r.isTemplate && _matches(r))
        .toList();
    final fromTrainer = store.assignedToMe
        .where((a) => _matches(a.routine))
        .toList();
    final active = _filtering ? null : store.activeRoutine();
    final nothing = templates.isEmpty && mine.isEmpty && fromTrainer.isEmpty;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Rutinas', help: HelpTopic.routines),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _CreateButton(onTap: () => _createRoutine(store)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar rutinas o ejercicios...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Borrar búsqueda',
                      onPressed: () => setState(_query.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _CategoryChip(
                  label: 'Todos',
                  selected: _group == null,
                  onTap: () => setState(() => _group = null),
                ),
                for (final g in groups)
                  _CategoryChip(
                    label: g,
                    selected: _group == g,
                    onTap: () =>
                        setState(() => _group = _group == g ? null : g),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _LevelTabs(
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
          ),
          if (active != null) ...[
            const SizedBox(height: 24),
            _ActiveRoutine(
              routine: active,
              done: store.sessionsThisWeek(active.id),
              goal: store.user?.daysPerWeek ?? 4,
            ),
          ],
          if (fromTrainer.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader('De tu entrenador'),
            for (final a in fromTrainer)
              RoutineCard(
                routine: a.routine,
                caption: 'Asignada por ${a.trainerName}',
              ),
          ],
          if (templates.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader('Planes recomendados'),
            for (final r in templates) RoutineCard(routine: r),
          ],
          const SizedBox(height: 24),
          const SectionHeader('Mis rutinas'),
          if (mine.isEmpty)
            Text(
              _filtering
                  ? 'Ninguna de tus rutinas coincide con el filtro.'
                  : 'Aún no has creado ninguna rutina.',
            ),
          for (final r in mine)
            RoutineCard(routine: r, onDelete: () => store.deleteRoutine(r.id)),
          if (nothing && _filtering) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => setState(() {
                  _query.clear();
                  _group = null;
                  _level = null;
                }),
                child: const Text('Quitar filtros'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? AppTheme.coral : scheme.surfaceContainer,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? Colors.white : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTabs extends StatelessWidget {
  const _LevelTabs({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = <(String?, String)>[
      (null, 'Todos'),
      for (final l in Routine.levels) (l, l),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        children: [
          for (final (value, label) in options)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? scheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: selected == value
                          ? scheme.secondary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// La rutina que estás siguiendo: sesiones de esta semana y botón de seguir.
class _ActiveRoutine extends StatelessWidget {
  const _ActiveRoutine({
    required this.routine,
    required this.done,
    required this.goal,
  });

  final Routine routine;
  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final progress = goal == 0 ? 0.0 : done / goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Rutina activa',
          leading: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: scheme.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: scheme.secondary.withValues(alpha: 0.7),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          trailing: StatusPill(label: 'En curso', color: scheme.secondary),
        ),
        Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ESTA SEMANA: $done DE $goal SESIONES',
                            style: text.labelSmall?.copyWith(
                              color: scheme.secondaryFixed,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(routine.name, style: text.headlineSmall),
                          Text(
                            '${routine.exercises.length} ejercicios · '
                            '${routine.muscleGroups.join(', ')}',
                            style: text.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ProgressRing(progress: progress),
                  ],
                ),
                const SizedBox(height: 12),
                ThinProgress(value: progress),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: scheme.tertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '~${routine.estimatedMin} min',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondary,
                        foregroundColor: scheme.onSecondary,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () => startWorkoutFrom(context, routine),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Continuar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Botón ancho con degradado coral para crear una rutina.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          gradient: const LinearGradient(
            colors: [AppTheme.coral, AppTheme.coralLight],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.coral.withValues(alpha: 0.45),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onTap,
            child: SizedBox(
              height: 56,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Crear rutina personalizada',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
