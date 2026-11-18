import 'package:flutter/material.dart';

import '../../data/client_overview.dart';
import '../../data/client_report.dart';
// Solo lo que hace falta: formatters.dart también tiene un `shortDate`
// (con otro formato) y chocaría con el de client_report.dart.
import '../../data/formatters.dart'
    show formatKg, formatThousands, relativeDayLabel;
import '../../data/week_summary.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import 'client_widgets.dart';
import 'trainer_actions.dart';

/// Pestaña "Resumen" de la ficha de un cliente: la nota de la semana con
/// sus avisos, cuatro tarjetas (entrenos, nutrición, pasos y peso), sus
/// últimos entrenos, el informe PDF/Excel y, debajo, las estadísticas de
/// las últimas semanas y las rutinas que le he asignado.
class ClientSummaryTab extends StatelessWidget {
  const ClientSummaryTab({
    super.key,
    required this.client,
    required this.assigned,
    required this.onAssign,
  });

  final ClientOverview client;
  final List<AssignedRoutine> assigned;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    // Las estadísticas por semanas usan los entrenos ya cargados.
    final report = ClientReport(
      user: client.user,
      workouts: client.workouts,
      weeks: ClientOverview.workoutWeeks,
      assignedRoutineIds: {for (final a in assigned) a.id},
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        _WeekScoreCard(client),
        const SizedBox(height: 12),
        _WeekCards(client.week),
        const SizedBox(height: 20),
        SectionHeader('Últimos entrenos'),
        _RecentWorkouts(client),
        const SizedBox(height: 12),
        _ReportTile(report),
        const SizedBox(height: 20),
        SectionHeader('Últimas ${report.weeks} semanas'),
        _PeriodStats(report),
        const SizedBox(height: 20),
        _AssignedRoutines(assigned: assigned, onAssign: onAssign),
      ],
    );
  }
}

/// Nota de la semana, su diferencia con la anterior y los avisos.
class _WeekScoreCard extends StatelessWidget {
  const _WeekScoreCard(this.client);

  final ClientOverview client;

  String get _changeText {
    final change = client.week.scoreChange;
    if (change == 0) return 'Igual que la semana pasada';
    final sign = change > 0 ? '+' : '−';
    return '$sign${change.abs()} respecto a la semana pasada';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScoreCircle(score: client.score, size: 64),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nota de la semana', style: text.titleMedium),
                  Text(_changeText, style: text.bodySmall),
                  const SizedBox(height: 8),
                  if (client.alerts.isEmpty) const Text('Va al día.'),
                  for (final alert in client.alerts) AlertLine(alert),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Entrenos, nutrición, pasos de media y peso medio de la semana.
class _WeekCards extends StatelessWidget {
  const _WeekCards(this.week);

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final steps = week.averageSteps;
    final weight = week.averageWeight;
    return Column(
      children: [
        Row(
          children: [
            TrainerKpi(
              value: '${week.doneWorkouts}/${week.plannedWorkouts}',
              label: 'entrenos',
            ),
            TrainerKpi(
              value: '${week.nutritionDaysLogged}/${WeekSummary.daysInWeek}',
              label: 'días con comida',
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            TrainerKpi(
              value: steps == null ? '—' : formatThousands(steps),
              label: 'pasos de media',
            ),
            TrainerKpi(
              value: weight == null ? '—' : '${formatKg(weight)} kg',
              label: 'peso medio',
            ),
          ],
        ),
      ],
    );
  }
}

/// Sus últimos entrenos: día, nombre, duración, series y kg.
class _RecentWorkouts extends StatelessWidget {
  const _RecentWorkouts(this.client);

  /// Cuántos se muestran.
  static const limit = 5;

  final ClientOverview client;

  @override
  Widget build(BuildContext context) {
    final workouts = client.workouts.take(limit).toList();
    if (workouts.isEmpty) {
      return Text(
        'Sin entrenos en las últimas ${ClientOverview.workoutWeeks} semanas.',
      );
    }
    return Column(
      children: [
        for (final w in workouts)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fitness_center),
            title: Text(w.name),
            subtitle: Text(
              '${relativeDayLabel(w.date, client.today)} · '
              '${w.durationMin} min · ${_sets(w)} series · '
              '${formatThousands(w.volumeKg)} kg',
            ),
          ),
      ],
    );
  }

  static int _sets(Workout w) =>
      w.exercises.fold(0, (t, e) => t + e.sets.length);
}

/// "Informe de Ana" con el botón de PDF o Excel.
class _ReportTile extends StatelessWidget {
  const _ReportTile(this.report);

  final ClientReport report;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.description_outlined),
        title: Text('Informe de ${report.name}'),
        subtitle: Text('Últimas ${report.weeks} semanas, en PDF o Excel'),
        trailing: ExportReportButton(
          onSelected: (pdf) =>
              exportReport(context, [report], pdf: pdf, weeks: report.weeks),
        ),
      ),
    );
  }
}

/// Las estadísticas que ya tenía la ficha: sesiones, cumplimiento, minutos,
/// volumen, sesiones por semana y ejercicios más hechos.
class _PeriodStats extends StatelessWidget {
  const _PeriodStats(this.report);

  final ClientReport report;

  @override
  Widget build(BuildContext context) {
    final top = report.topExercises();
    final last = report.lastWorkout;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            TrainerKpi(value: '${report.sessions}', label: 'sesiones'),
            TrainerKpi(
              value: '${report.adherencePct.round()} %',
              label: 'cumplimiento',
            ),
            TrainerKpi(value: '${report.minutes}', label: 'minutos'),
            TrainerKpi(
              value: '${(report.volumeKg / 1000).toStringAsFixed(1)} t',
              label: 'volumen',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          last == null
              ? 'No ha registrado ningún entreno.'
              : 'Último entreno: ${longDate(last)} '
                    '(hace ${report.daysSinceLast} días). '
                    '${report.assignedSessions} sesiones con tus rutinas.',
        ),
        const SizedBox(height: 16),
        Text(
          'Sesiones por semana',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        WeekBars(report: report),
        if (top.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Ejercicios más hechos',
            style: Theme.of(context).textTheme.titleSmall,
          ),
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
      ],
    );
  }
}

/// Rutinas que le he asignado y el botón para asignarle otra.
class _AssignedRoutines extends StatelessWidget {
  const _AssignedRoutines({required this.assigned, required this.onAssign});

  final List<AssignedRoutine> assigned;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader('Rutinas que le has asignado'),
        if (assigned.isEmpty) const Text('Ninguna.'),
        for (final a in assigned)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.assignment_outlined),
            title: Text(a.routine.name),
            subtitle: Text(
              '${a.dayLabel} · ${a.routine.exercises.length} ejercicios · '
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
    );
  }
}

/// Cifra grande con su etiqueta, para las filas de datos del panel.
class TrainerKpi extends StatelessWidget {
  const TrainerKpi({super.key, required this.value, required this.label});

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

/// Barras sencillas de sesiones por semana con la línea de su objetivo.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.report});

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
