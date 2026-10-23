import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import '../workouts/register_workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _weekdayNames = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final user = store.user;
    final now = DateTime.now();
    final macros = store.macrosFor(now);
    final targets = store.macroTargets();
    final weekDone = store.workoutsThisWeek();
    final weekGoal = user?.daysPerWeek ?? 4;
    final streak = store.streakDays();
    final trainedToday = store.trainedOn(now);

    // Prioridad: rutina del entrenador > la que estás siguiendo > recomendada.
    final today = store.assignedToMe.isNotEmpty
        ? store.assignedToMe.first.routine
        : store.activeRoutine() ?? store.recommendedRoutine();

    return Scaffold(
      appBar: const BrandAppBar(title: 'Inicio', help: HelpTopic.home),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            'Hola, ${user?.name ?? 'atleta'}',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              StatusPill(
                label: '$streak ${streak == 1 ? 'día' : 'días'}',
                color: AppTheme.coral,
                icon: Icons.local_fire_department,
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: trainedToday
                    ? 'Hoy: entreno hecho'
                    : '${_weekdayNames[now.weekday - 1]}: hora de entrenar',
                color: scheme.secondary,
                dot: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeekStrip(store: store, labels: _weekdays),
          const SizedBox(height: 24),
          const SectionHeader('Estadísticas'),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Calorías hoy',
                  value: macros.kcal.toStringAsFixed(0),
                  unit: '/ ${targets.kcal.toStringAsFixed(0)} kcal',
                  icon: Icons.local_fire_department,
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Proteína hoy',
                  value: macros.protein.toStringAsFixed(0),
                  unit: '/ ${targets.protein.toStringAsFixed(0)} g',
                  icon: Icons.egg_alt,
                  color: scheme.primaryFixed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Entrenos semana',
                  value: '$weekDone',
                  unit: '/ $weekGoal',
                  icon: Icons.fitness_center,
                  color: scheme.secondary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: 'Volumen semana',
                  value: _compact(store.volumeThisWeek()),
                  unit: 'kg',
                  icon: Icons.bar_chart,
                  color: AppTheme.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SectionHeader(
            'Entrenamiento de hoy',
            trailing: StatusPill(
              label: 'Sesión ${weekDone + (trainedToday ? 0 : 1)}',
              color: scheme.secondary,
            ),
          ),
          _TodayHero(routine: today),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _WeeklyChallenge(done: weekDone, goal: weekGoal),
              ),
              const SizedBox(width: 8),
              Expanded(child: _WaterCard(store: store)),
            ],
          ),
        ],
      ),
    );
  }

  /// 12500 → "12,5k".
  static String _compact(double v) {
    if (v < 1000) return v.toStringAsFixed(0);
    final k = v / 1000;
    return '${k.toStringAsFixed(k >= 100 ? 0 : 1).replaceAll('.', ',')}k';
  }
}

/// Semana actual (lunes a domingo): hoy resaltado y punto verde en los días
/// con entreno.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.store, required this.labels});

  final AppStore store;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Builder(
              builder: (context) {
                final day = monday.add(Duration(days: i));
                final isToday = DateUtils.isSameDay(day, now);
                final trained = store.trainedOn(day);
                return Container(
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppTheme.coral
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radius),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        labels[i],
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isToday
                              ? Colors.white
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: isToday ? Colors.white : scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: trained
                              ? (isToday ? Colors.white : scheme.secondary)
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: color),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta grande con la rutina de hoy y el botón de empezar.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.routine});

  final Routine routine;

  void _start(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegisterWorkoutScreen(fromRoutine: routine),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Container(
        height: 220,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              AppTheme.coral.withValues(alpha: 0.55),
              scheme.surfaceContainer,
              scheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Icono grande decorativo de fondo.
            Positioned(
              right: -24,
              top: -12,
              child: Icon(
                Icons.fitness_center,
                size: 180,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withValues(
                        alpha: 0.9,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: const BoxDecoration(
                            color: AppTheme.coral,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(routine.level, style: text.labelSmall),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              routine.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 12,
                              children: [
                                _info(
                                  context,
                                  Icons.fitness_center,
                                  '${routine.exercises.length} ejercicios',
                                  AppTheme.coral,
                                ),
                                _info(
                                  context,
                                  Icons.timer_outlined,
                                  '~${routine.estimatedMin} min',
                                  scheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: AppTheme.coral,
                        shape: const CircleBorder(),
                        elevation: 8,
                        shadowColor: AppTheme.coral.withValues(alpha: 0.5),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _start(context),
                          child: const SizedBox.square(
                            dimension: 56,
                            child: Icon(
                              Icons.play_arrow_rounded,
                              size: 32,
                              color: Colors.white,
                              semanticLabel: 'Empezar entrenamiento',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, IconData icon, String label, Color c) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _WeeklyChallenge extends StatelessWidget {
  const _WeeklyChallenge({required this.done, required this.goal});

  final int done;
  final int goal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goal == 0 ? 0.0 : (done / goal).clamp(0.0, 1.0);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reto semanal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Icon(Icons.emoji_events, size: 20, color: scheme.secondary),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$done de $goal días',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: scheme.secondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ThinProgress(value: progress),
          ],
        ),
      ),
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final liters = store.waterMl / 1000;
    final goal = store.waterGoalMl / 1000;
    final ratio = store.waterGoalMl == 0
        ? 0.0
        : store.waterMl / store.waterGoalMl;
    final status = ratio >= 1
        ? '¡Meta cumplida!'
        : ratio >= 0.7
        ? 'Meta casi lista'
        : 'Sigue bebiendo';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Agua hoy',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Añadir 250 ml',
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => store.addWater(250),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(
                          TextSpan(
                            text: _l(liters),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            children: [
                              TextSpan(
                                text: ' / ${_l(goal)} L',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.water_drop, size: 22, color: scheme.primaryFixed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _l(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
}
