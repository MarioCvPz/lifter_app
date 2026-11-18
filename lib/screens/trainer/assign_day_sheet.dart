import 'package:flutter/material.dart';

import '../../models/models.dart';

/// Hoja para elegir a qué día del plan del cliente va la rutina que se va
/// a asignar. Muestra sus días de entreno en orden ("Día 1 · Lunes"…) y lo
/// que tiene ahora cada uno. Devuelve el número de día, o null si se cierra.
Future<int?> showAssignDayPicker(
  BuildContext context, {
  required String clientName,
  required TrainingPlan plan,
  required List<AssignedRoutine> assigned,
}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) =>
        _AssignDaySheet(clientName: clientName, plan: plan, assigned: assigned),
  );
}

class _AssignDaySheet extends StatelessWidget {
  const _AssignDaySheet({
    required this.clientName,
    required this.plan,
    required this.assigned,
  });

  final String clientName;
  final TrainingPlan plan;

  /// Rutinas que ya le he asignado a este cliente.
  final List<AssignedRoutine> assigned;

  /// Lo que hace ahora el cliente el día [dayNumber]: mi rutina si ya le
  /// asigné una a ese día, o el día de su plan.
  String _currentFor(int dayNumber, PlanDay day) {
    for (final a in assigned) {
      if (a.dayNumber == dayNumber) {
        return 'Ahora: ${a.routine.name} (la nueva la sustituye)';
      }
    }
    return 'Ahora: ${day.name} (de su plan)';
  }

  @override
  Widget build(BuildContext context) {
    final days = plan.days;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            '¿Qué día de $clientName?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'La rutina solo sustituye a ese día de su plan.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < days.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('Día ${i + 1} · ${days[i].weekdayName}'),
              subtitle: Text(_currentFor(i + 1, days[i])),
              onTap: () => Navigator.pop(context, i + 1),
            ),
        ],
      ),
    );
  }
}
