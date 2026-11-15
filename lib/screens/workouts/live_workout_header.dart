import 'package:flutter/material.dart';

import '../../data/workout_draft.dart';
import '../../widgets/help.dart';

/// Opciones del menú ⋯ de la cabecera. "Terminar entrenamiento" no está
/// aquí: es el botón grande del final de la lista.
enum WorkoutMenuAction {
  addExercise('Añadir ejercicio', Icons.add),
  discard('Descartar entrenamiento', Icons.delete_outline);

  const WorkoutMenuAction(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Cabecera del entrenamiento: a la izquierda el cronómetro, en el centro
/// el título y a la derecha el temporizador de descanso y el menú ⋯.
/// Implementa [PreferredSizeWidget] para poder usarse como `appBar`
/// del `Scaffold` (como hace `AppBar`).
class LiveWorkoutAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LiveWorkoutAppBar({
    super.key,
    required this.elapsed,
    required this.onRestTimer,
    required this.onMenu,
  });

  /// Tiempo total del entrenamiento.
  final Duration elapsed;

  /// Abre el temporizador de descanso. Si es null, el botón sale
  /// desactivado.
  final VoidCallback? onRestTimer;

  final ValueChanged<WorkoutMenuAction> onMenu;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Sin flecha de volver: para salir se usa el menú (o el botón atrás
      // del móvil, que pregunta antes de descartar).
      automaticallyImplyLeading: false,
      leadingWidth: 96,
      leading: Center(child: _Clock(elapsed)),
      centerTitle: true,
      title: const Text('Entrenamiento'),
      actions: [
        const HelpButton(HelpTopic.registerWorkout),
        IconButton(
          tooltip: 'Temporizador de descanso',
          onPressed: onRestTimer,
          icon: const Icon(Icons.timer_outlined),
        ),
        PopupMenuButton<WorkoutMenuAction>(
          tooltip: 'Más opciones',
          onSelected: onMenu,
          itemBuilder: (_) => [
            for (final action in WorkoutMenuAction.values)
              PopupMenuItem(
                value: action,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(action.icon),
                  title: Text(action.label),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// El cronómetro ("12:34"). Usa cifras de ancho fijo para que el texto no
/// "baile" al cambiar cada segundo.
class _Clock extends StatelessWidget {
  const _Clock(this.elapsed);

  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      formatClock(elapsed),
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: scheme.primary,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// Bloque bajo la cabecera: el nombre del entreno ("Empuje") y el resumen
/// en vivo ("3 de 12 series · 1250 kg levantados").
class WorkoutSummaryHeader extends StatelessWidget {
  const WorkoutSummaryHeader({
    super.key,
    required this.name,
    required this.summary,
  });

  final String name;
  final String summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          summary,
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
