import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../workouts/register_workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final user = store.user;
    final macros = store.macrosFor(DateTime.now());
    final last = store.workouts.isEmpty ? null : store.workouts.first;
    final rec = store.recommendedRoutine();

    return Scaffold(
      appBar: AppBar(title: const Text('SocialGym')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hola, ${user?.name ?? 'atleta'}',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Objetivo: ${user?.goal ?? '—'} · ${user?.daysPerWeek ?? 0} días/semana',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Entrenos',
                  value: '${store.workouts.length}',
                  icon: Icons.fitness_center,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Kcal hoy',
                  value: macros.kcal.toStringAsFixed(0),
                  icon: Icons.local_fire_department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rutina recomendada',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(rec.name, style: Theme.of(context).textTheme.titleLarge),
                  Text(rec.description),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              RegisterWorkoutScreen(fromRoutine: rec),
                        ),
                      );
                    },
                    child: const Text('Empezar entrenamiento'),
                  ),
                ],
              ),
            ),
          ),
          if (last != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: Text('Último: ${last.name}'),
                subtitle: Text(
                  '${last.exercises.length} ejercicios · ${last.durationMin} min',
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RegisterWorkoutScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Registrar entrenamiento'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
            Text(label),
          ],
        ),
      ),
    );
  }
}
