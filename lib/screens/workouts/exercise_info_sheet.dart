import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_report.dart';
import '../../data/stats.dart';
import '../../data/workout_draft.dart';
import '../../models/models.dart';
import 'exercise_card.dart';

/// Abre la hoja del ejercicio con dos pestañas: "Cómo hacerlo" y
/// "Historial". [showHistory] abre directamente la segunda (botón
/// "Historial" de la tarjeta).
Future<void> showExerciseInfoSheet(
  BuildContext context,
  Exercise exercise, {
  bool showHistory = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => DefaultTabController(
      length: 2,
      initialIndex: showHistory ? 1 : 0,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text(exercise.name, style: Theme.of(context).textTheme.titleLarge),
            const TabBar(
              tabs: [
                Tab(text: 'Cómo hacerlo'),
                Tab(text: 'Historial'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [_HowTo(exercise), _History(exercise)],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Datos del catálogo (no hay vídeos): grupo, material, patrón, tipo,
/// nivel y zonas que carga.
class _HowTo extends StatelessWidget {
  const _HowTo(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final zones = exercise.stressedZones;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _InfoTile(
          Icons.accessibility_new,
          'Grupo muscular',
          exercise.muscleGroup,
        ),
        _InfoTile(Icons.fitness_center, 'Material', exercise.equipment),
        _InfoTile(Icons.swap_calls, 'Patrón', exercise.pattern.label),
        _InfoTile(
          Icons.category_outlined,
          'Tipo',
          exercise.isCompound ? 'Multiarticular' : 'Aislamiento',
        ),
        _InfoTile(Icons.signal_cellular_alt, 'Nivel', exercise.level),
        if (zones.isNotEmpty)
          _InfoTile(
            Icons.healing_outlined,
            'Zonas que carga',
            zones.join(', '),
          ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}

/// Últimas veces que hizo el ejercicio: fecha, series y comentario.
class _History extends StatelessWidget {
  const _History(this.exercise);

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final history = SessionScope.of(context).historyOf(exercise.id);
    if (history.isEmpty) {
      return const Center(child: Text('Aún no hay historial.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final item in history)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(longDate(item.date)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_describe(item.entry)),
                if (item.coachReply case final reply?)
                  TrainerNoteBox(reply, prefix: 'Tu entrenador: '),
              ],
            ),
          ),
      ],
    );
  }

  /// "10 × 60 kg · 8 × 65 kg", y el comentario debajo si lo hay.
  String _describe(WorkoutExercise entry) {
    final sets = entry.sets
        .map((s) => '${s.reps} × ${formatKg(s.weightKg)} kg')
        .join(' · ');
    final comment = entry.comment;
    return comment == null ? sets : '$sets\n"$comment"';
  }
}
