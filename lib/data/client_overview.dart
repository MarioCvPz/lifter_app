import '../models/models.dart';
import 'formatters.dart';
import 'nutrition_calculator.dart';
import 'week_summary.dart';

/// Datos de un cliente para la lista "Mis clientes" del modo entrenador: su
/// nota de la semana, los avisos y sus notas. Es Dart puro: recibe los
/// datos ya cargados (los lee [AppStore.loadClientOverviews]) y solo
/// calcula, así que se prueba con tests normales.
class ClientOverview {
  ClientOverview({
    required this.user,
    required DateTime today,
    required this.plan,
    required this.coach,
    required this.workouts,
    required this.nutrition,
    required this.weights,
    required this.steps,
    required this.replies,
  }) : today = _dateOnly(today);

  // --------------------------------------------------------- Constantes --

  /// Semanas de entrenos que se cargan (para las notas, el último entreno y
  /// las estadísticas de la ficha). La actual cuenta como una.
  static const workoutWeeks = 4;

  /// Semanas de comida, pasos y peso: la actual y la anterior (para la
  /// diferencia de la nota y del peso).
  static const otherWeeks = 2;

  /// Días sin entrenar a partir de los que sale el aviso.
  static const minDaysWithoutTraining = 3;

  /// Días seguidos sin comida a partir de los que sale el aviso.
  static const minDaysWithoutFood = 2;

  /// Primer día que se carga de entrenos.
  static DateTime workoutsFrom(DateTime today) =>
      _weeksBack(today, workoutWeeks);

  /// Primer día que se carga de comida, pasos y peso.
  static DateTime othersFrom(DateTime today) => _weeksBack(today, otherWeeks);

  /// Lunes de hace [weeks] - 1 semanas.
  static DateTime _weeksBack(DateTime today, int weeks) {
    final monday = WeekSummary.mondayOf(today);
    return DateTime(monday.year, monday.month, monday.day - 7 * (weeks - 1));
  }

  // ------------------------------------------------------------- Datos --

  final AppUser user;

  /// Hoy a las 00:00.
  final DateTime today;
  final TrainingPlan? plan;

  /// Objetivos que le ha puesto el entrenador (vacío si ninguno).
  final CoachSettings coach;

  /// Entrenos desde [workoutsFrom], del más reciente al más antiguo.
  final List<Workout> workouts;
  final List<NutritionEntry> nutrition;
  final List<WeightEntry> weights;
  final List<StepsEntry> steps;

  /// Lo que el entrenador ha hecho con cada nota, por su id.
  final Map<String, CoachReply> replies;

  String get uid => user.uid;
  UserProfile get profile => user.profile;
  String get name => profile.name.isEmpty ? '(sin nombre)' : profile.name;

  /// Iniciales para el círculo: "Ana López" → "AL".
  String get initials {
    final words = profile.name.trim().split(RegExp(r'\s+'));
    final letters = [
      for (final w in words.take(2))
        if (w.isNotEmpty) w[0].toUpperCase(),
    ];
    return letters.isEmpty ? '?' : letters.join();
  }

  /// Su semana actual, con sus objetivos (los del entrenador si los hay).
  late final WeekSummary week = WeekSummary(
    weekStart: today,
    today: today,
    plan: plan,
    workouts: workouts,
    nutrition: nutrition,
    kcalGoal: NutritionCalculator.macrosWithCoach(profile, coach).kcal,
    weights: weights,
    steps: steps,
    stepsGoal: coach.stepsGoal ?? profile.stepsGoal,
  );

  int get score => week.score;

  DateTime? get lastWorkout => workouts.isEmpty ? null : workouts.first.date;

  /// "Ganar masa · Entrenos 2/4 · último: ayer".
  String get subtitle {
    final last = lastWorkout;
    final lastText = last == null
        ? 'sin entrenos'
        : relativeDayLabel(last, today).toLowerCase();
    return '${profile.goal.label} · Entrenos '
        '${week.doneWorkouts}/${week.plannedWorkouts} · último: $lastText';
  }

  // ------------------------------------------------------------ Notas --

  /// Sus notas (comentarios en ejercicios), de la más reciente a la más
  /// antigua.
  late final List<ClientNote> notes = [
    for (final w in workouts)
      for (final (i, e) in w.exercises.indexed)
        if ((e.comment ?? '').trim().isNotEmpty)
          ClientNote(
            clientId: uid,
            clientName: name,
            workoutId: w.id,
            exerciseIndex: i,
            exercise: e.exercise,
            date: w.date,
            text: e.comment?.trim() ?? '',
            reply: replies[CoachReply.idFor(w.id, i)],
          ),
  ];

  int get unreadNotes => notes.where((n) => !n.isRead).length;

  /// El mismo cliente con [changed] en sus respuestas (al responder o
  /// marcar como leída, sin volver a leer Firestore).
  ClientOverview withReplies(Iterable<CoachReply> changed) => ClientOverview(
    user: user,
    today: today,
    plan: plan,
    coach: coach,
    workouts: workouts,
    nutrition: nutrition,
    weights: weights,
    steps: steps,
    replies: {...replies, for (final r in changed) r.id: r},
  );

  // ----------------------------------------------------------- Avisos --

  /// Sus avisos, del más grave al menos grave.
  late final List<ClientAlert> alerts = [
    ?ClientAlert.noTraining(
      plan: plan,
      lastWorkout: lastWorkout,
      loadedFrom: workoutsFrom(today),
      today: today,
    ),
    ?ClientAlert.noFood(
      nutrition: nutrition,
      loadedFrom: othersFrom(today),
      today: today,
    ),
    ?ClientAlert.unreadNotes(unreadNotes),
  ];

  /// El aviso más grave, o null si va al día.
  ClientAlert? get alert => alerts.isEmpty ? null : alerts.first;

  bool get needsAttention => alerts.isNotEmpty;

  // ---------------------------------------------------- Orden y filtro --

  /// Orden de la lista: primero los que tienen aviso (de más grave a menos)
  /// y después por nota, de menor a mayor. Con todo igual, por nombre.
  static int compare(ClientOverview a, ClientOverview b) {
    final byAlert = _alertRank(a).compareTo(_alertRank(b));
    if (byAlert != 0) return byAlert;
    final byScore = a.score.compareTo(b.score);
    if (byScore != 0) return byScore;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Gravedad del aviso como número (0 = el más grave). Sin aviso, el
  /// último.
  static int _alertRank(ClientOverview c) =>
      c.alert?.kind.index ?? ClientAlertKind.values.length;

  /// [clients] ordenados con [compare], con el [filter] y cuyo nombre
  /// contiene [query] (sin distinguir mayúsculas).
  static List<ClientOverview> visible(
    Iterable<ClientOverview> clients, {
    ClientFilter filter = ClientFilter.all,
    String query = '',
  }) {
    final q = query.trim().toLowerCase();
    return [
      for (final c in clients)
        if (filter.accepts(c) && c.name.toLowerCase().contains(q)) c,
    ]..sort(compare);
  }
}

/// Tipos de aviso, del más grave al menos grave (el orden del enum es el
/// de la lista de clientes).
enum ClientAlertKind { noTraining, noFood, unreadNotes }

/// Aviso de un cliente en la lista, por ejemplo "4 días sin entrenar".
class ClientAlert {
  const ClientAlert(this.kind, this.text);

  final ClientAlertKind kind;
  final String text;

  /// "X días sin entrenar": si lleva [ClientOverview.minDaysWithoutTraining]
  /// días o más sin entrenar y en medio tenía días de entreno en su plan
  /// (hoy no cuenta, aún puede entrenar). Si no hay ningún entreno desde
  /// [loadedFrom], se cuenta desde ahí ("Más de 20 días…").
  static ClientAlert? noTraining({
    required TrainingPlan? plan,
    required DateTime? lastWorkout,
    required DateTime loadedFrom,
    required DateTime today,
  }) {
    if (plan == null || plan.days.isEmpty) return null;
    final todayDate = _dateOnly(today);
    // Si entrenó el sábado y hoy es martes: 3 días, desde el domingo.
    final DateTime firstDay;
    final int days;
    if (lastWorkout == null) {
      firstDay = _dateOnly(loadedFrom);
      days = _daysBetween(firstDay, todayDate);
    } else {
      firstDay = _addDays(_dateOnly(lastWorkout), 1);
      days = _daysBetween(_dateOnly(lastWorkout), todayDate);
    }
    if (days < ClientOverview.minDaysWithoutTraining) return null;
    // ¿Tenía que entrenar algún día entre medias (sin contar hoy)?
    var missedPlannedDay = false;
    for (var d = firstDay; d.isBefore(todayDate); d = _addDays(d, 1)) {
      if (plan.dayFor(d.weekday) != null) missedPlannedDay = true;
    }
    if (!missedPlannedDay) return null;
    final text = lastWorkout == null
        ? 'Más de $days días sin entrenar'
        : '$days días sin entrenar';
    return ClientAlert(ClientAlertKind.noTraining, text);
  }

  /// "Sin registrar comida desde el lunes": si lleva
  /// [ClientOverview.minDaysWithoutFood] días seguidos o más sin apuntar
  /// nada, contando hasta ayer (hoy aún puede apuntar). Si hoy ya ha
  /// apuntado algo, no hay aviso.
  static ClientAlert? noFood({
    required List<NutritionEntry> nutrition,
    required DateTime loadedFrom,
    required DateTime today,
  }) {
    final todayDate = _dateOnly(today);
    DateTime? lastDay;
    for (final e in nutrition) {
      final day = _dateOnly(e.date);
      if (lastDay == null || day.isAfter(lastDay)) lastDay = day;
    }
    if (lastDay != null && !lastDay.isBefore(todayDate)) return null;
    final firstEmpty = lastDay == null
        ? _dateOnly(loadedFrom)
        : _addDays(lastDay, 1);
    final emptyDays = _daysBetween(firstEmpty, todayDate);
    if (emptyDays < ClientOverview.minDaysWithoutFood) return null;
    final since = emptyDays >= WeekSummary.daysInWeek
        ? 'hace más de una semana'
        : 'el ${ProfileOptions.weekdayNames[firstEmpty.weekday - 1].toLowerCase()}';
    return ClientAlert(
      ClientAlertKind.noFood,
      'Sin registrar comida desde $since',
    );
  }

  /// "Te ha dejado 2 notas" si tiene notas sin leer.
  static ClientAlert? unreadNotes(int count) {
    if (count == 0) return null;
    return ClientAlert(
      ClientAlertKind.unreadNotes,
      'Te ha dejado $count ${count == 1 ? 'nota' : 'notas'}',
    );
  }
}

/// Filtros de la lista de clientes.
enum ClientFilter {
  all('Todos'),
  attention('Necesitan atención'),
  upToDate('Al día');

  const ClientFilter(this.label);

  final String label;

  bool accepts(ClientOverview client) => switch (this) {
    ClientFilter.all => true,
    ClientFilter.attention => client.needsAttention,
    ClientFilter.upToDate => !client.needsAttention,
  };
}

/// Nivel de la nota de la semana, para el color del círculo: verde (≥ 70),
/// ámbar (50–69) o rojizo (< 50).
enum ScoreLevel {
  good,
  fair,
  low;

  static const goodFrom = 70;
  static const fairFrom = 50;

  static ScoreLevel of(int score) {
    if (score >= goodFrom) return ScoreLevel.good;
    if (score >= fairFrom) return ScoreLevel.fair;
    return ScoreLevel.low;
  }
}

/// Nota que un cliente dejó en un ejercicio, con lo que ha hecho el
/// entrenador con ella ([reply]).
class ClientNote {
  const ClientNote({
    required this.clientId,
    required this.clientName,
    required this.workoutId,
    required this.exerciseIndex,
    required this.exercise,
    required this.date,
    required this.text,
    this.reply,
  });

  final String clientId;
  final String clientName;
  final String workoutId;
  final int exerciseIndex;
  final Exercise exercise;
  final DateTime date;
  final String text;
  final CoachReply? reply;

  String get id => CoachReply.idFor(workoutId, exerciseIndex);
  bool get isRead => reply?.isRead ?? false;
  String? get replyText => reply?.reply;

  /// Las notas de todos los [clients]: primero las no leídas y, dentro de
  /// cada grupo, de la más reciente a la más antigua.
  static List<ClientNote> allOf(Iterable<ClientOverview> clients) =>
      [for (final c in clients) ...c.notes]..sort(compare);

  static int compare(ClientNote a, ClientNote b) {
    if (a.isRead != b.isRead) return a.isRead ? 1 : -1;
    return b.date.compareTo(a.date);
  }
}

// ------------------------------------------------------------ Fechas --

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Suma días con el constructor de fecha, para no fallar con el cambio de
/// hora.
DateTime _addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Días entre dos fechas. En UTC no hay cambio de hora, así que la resta
/// da días exactos.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
