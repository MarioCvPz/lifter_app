import '../models/models.dart';
import 'routine_generator.dart';

/// Cambios que hace el entrenador en el plan de su cliente. Todo lo que
/// toca queda marcado como suyo ([PlanExercise.byTrainer]) y como
/// personalizado ([PlanExercise.isCustom]), para que no se pierda al
/// actualizar el plan. Solo calcula: guardar lo hace el [AppStore].
class CoachPlan {
  CoachPlan._();

  // Límites de lo que puede escribir el entrenador.
  static const maxSets = 10;
  static const maxReps = 50;
  static const maxRestSeconds = 600;
  static const maxNoteLength = 200;

  /// [exercise] marcado como del entrenador.
  static PlanExercise mark(PlanExercise exercise) =>
      exercise.copyWith(isCustom: true, byTrainer: true);

  /// Añade [exercise] al día con las series y repeticiones que le
  /// corresponden a [client] (luego el entrenador las puede cambiar).
  static PlanDay add(PlanDay day, Exercise exercise, UserProfile client) =>
      day.withExercise(_prescribe(exercise, client));

  /// Cambia [oldId] por [replacement] en el mismo lugar.
  static PlanDay replace(
    PlanDay day,
    String oldId,
    Exercise replacement,
    UserProfile client,
  ) => day.replacing(oldId, _prescribe(replacement, client));

  /// Pone [changed] (otras series, repeticiones, descanso o nota) en el día.
  static PlanDay update(PlanDay day, PlanExercise changed) =>
      day.updating(mark(changed));

  static PlanExercise _prescribe(Exercise exercise, UserProfile client) =>
      mark(RoutineGenerator.prescribe(exercise, client, isCustom: true));

  /// Aviso si [client] no tiene el material o el ejercicio carga una zona
  /// lesionada, o null si puede hacerlo. Es solo un aviso: el entrenador
  /// decide.
  static String? warningFor(Exercise exercise, UserProfile client) {
    if (!client.equipment.contains(exercise.equipment)) {
      return '${_name(client)} no tiene marcado este material '
          '(${exercise.equipment.toLowerCase()}).';
    }
    for (final zone in exercise.stressedZones) {
      if (client.injuries.contains(zone)) {
        return 'Carga una zona lesionada de ${_name(client)} '
            '(${zone.toLowerCase()}).';
      }
    }
    return null;
  }

  static String _name(UserProfile client) =>
      client.name.isEmpty ? 'Tu cliente' : client.name;

  /// Mensaje de error si las series, repeticiones o descanso no son
  /// razonables, o null.
  static String? validate({
    required int? sets,
    required int? minReps,
    required int? maxRepsValue,
    required int? restSeconds,
  }) {
    if (sets == null || sets < 1 || sets > maxSets) {
      return 'Las series tienen que estar entre 1 y $maxSets.';
    }
    if (minReps == null ||
        maxRepsValue == null ||
        minReps < 1 ||
        maxRepsValue > maxReps) {
      return 'Las repeticiones tienen que estar entre 1 y $maxReps.';
    }
    if (minReps > maxRepsValue) {
      return 'El mínimo de repeticiones no puede ser mayor que el máximo.';
    }
    if (restSeconds == null ||
        restSeconds < 0 ||
        restSeconds > maxRestSeconds) {
      return 'El descanso tiene que estar entre 0 y $maxRestSeconds s.';
    }
    return null;
  }
}
