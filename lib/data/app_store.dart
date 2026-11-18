import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'catalog.dart';
import 'client_overview.dart';
import 'routine_generator.dart';
import 'trainer_link.dart';

/// Estado de la app. La sesión va con Firebase Auth y los datos de cada
/// usuario se guardan en Firestore bajo `users/{uid}`:
///   - `users/{uid}`             → perfil
///   - `users/{uid}/workouts`    → entrenamientos
///   - `users/{uid}/routines`    → rutinas propias
///   - `users/{uid}/nutrition`   → registros de comidas
///   - `users/{uid}/plan/current` → plan de entrenamiento generado
///   - `users/{uid}/weights`, `users/{uid}/steps` → peso y pasos, un
///     documento por día ([dayKey])
///   - `users/{uid}/coach/settings` → objetivos que pone su entrenador
///   - `users/{uid}/coachReplies` → notas leídas y respondidas por su
///     entrenador ([CoachReply])
/// Entrenadores y clientes:
///   - `trainerCodes/{code}` → código de cada entrenador
///   - `trainerLinks/{clientId}` → solicitud o vínculo de cada cliente
/// El catálogo es común a todos y también está en Firestore:
///   - `exercises`, `foods`, `routineTemplates` (solo los admins lo editan)
/// Los datos calculados (rachas, macros…) están en stats.dart.
class AppStore extends ChangeNotifier {
  /// Entrar, registrarse y salir.
  final AuthService auth = AuthService();

  /// True mientras se comprueba si hay una sesión guardada.
  bool loading = false;
  UserProfile? user;
  bool get isLoggedIn => user != null;

  /// True cuando ya se sabe cómo es el perfil en Firestore. Hasta entonces
  /// [user] es un perfil provisional y no se puede decidir si mostrar el
  /// cuestionario inicial.
  bool profileLoaded = false;

  final List<Routine> _myRoutines = [];
  final List<Workout> workouts = [];
  final List<NutritionEntry> nutritionLogs = [];

  /// Catálogo común (colecciones `exercises`, `foods` y `routineTemplates`).
  final List<Exercise> exercises = [];
  final List<Food> foods = [];
  final List<Routine> templates = [];

  /// Grupos musculares que aparecen en el catálogo de ejercicios.
  List<String> get muscleGroups =>
      {for (final e in exercises) e.muscleGroup}.toList()..sort();

  List<Routine> get routines => [...templates, ..._myRoutines];

  /// Rutinas que me han asignado mis entrenadores.
  final List<AssignedRoutine> assignedToMe = [];

  /// Rutinas que he asignado yo (solo entrenadores y admins).
  final List<AssignedRoutine> assignedByMe = [];

  /// Plan de entrenamiento semanal (users/{uid}/plan/current), o null si
  /// todavía no hay ninguno.
  TrainingPlan? plan;

  /// Agua bebida hoy, en ml (users/{uid}/water/{aaaa-mm-dd}).
  int waterMl = 0;

  /// Registros de peso y de pasos, del más reciente al más antiguo.
  final List<WeightEntry> weights = [];
  final List<StepsEntry> steps = [];

  /// Mi vínculo con un entrenador (`trainerLinks/{miUid}`), o null si no
  /// tengo ni he enviado ninguna solicitud.
  TrainerLink? myTrainerLink;

  /// Objetivos que me ha puesto un entrenador, o null si no hay. Se siguen
  /// usando aunque me desvincule, hasta que pulse "Volver al automático".
  CoachSettings? coachSettings;

  /// Como entrenador: solicitudes y clientes (`trainerLinks` con mi uid).
  final List<TrainerLink> trainerLinks = [];

  /// Lo que mi entrenador ha hecho con mis notas (leídas y respuestas),
  /// por id de nota ([CoachReply.idFor]).
  final Map<String, CoachReply> coachReplies = {};

  /// Modo entrenador: datos de mis clientes para la lista "Mis clientes" y
  /// la pestaña Notas. No se escuchan en tiempo real (serían muchas
  /// lecturas): se cargan con [loadClientOverviews].
  List<ClientOverview> clientOverviews = [];
  bool clientsLoading = false;
  String? clientsError;

  /// Clientes con los que se cargó [clientOverviews], o null si aún no se
  /// ha cargado nada.
  Set<String>? _overviewsFor;

  /// Tema elegido (oscuro por defecto). Se guarda en el propio dispositivo
  /// con shared_preferences y no en Firestore, porque es una preferencia
  /// del dispositivo y así también se aplica en la pantalla de login.
  ThemeMode themeMode = ThemeMode.dark;

  /// Clave con la que se guarda el tema en shared_preferences.
  static const themeKey = 'themeMode';

  /// Modo que eligió un entrenador ("Usuario" o "Entrenador"). Se guarda
  /// en el dispositivo, como el tema, para arrancar en el último usado.
  bool _trainerModeChosen = false;

  /// Clave con la que se guarda el modo en shared_preferences.
  static const trainerModeKey = 'trainerMode';

  String? get currentUid => _auth.currentUser?.uid;

  /// Día en que se creó la cuenta, o null si no se sabe (por ejemplo, en
  /// los tests, que no usan Firebase). Limita hasta dónde se puede ir
  /// hacia atrás en la pestaña Progreso.
  DateTime? get accountCreatedAt =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.metadata.creationTime;

  /// Foto de la cuenta de Google, si entró con Google.
  String? get photoUrl => _auth.currentUser?.photoURL;
  UserRole get role => user?.role ?? UserRole.user;
  bool get isAdmin => role == UserRole.admin;
  bool get isTrainer => role == UserRole.trainer || role == UserRole.admin;

  /// True si la app está en modo entrenador. Quien no es entrenador (o
  /// deja de serlo) siempre está en modo usuario, aunque lo tenga guardado.
  bool get inTrainerMode => isTrainer && _trainerModeChosen;

  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<Object?>> _dataSubs = [];

  /// Escuchas que solo tienen los entrenadores.
  final List<StreamSubscription<Object?>> _trainerSubs = [];

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Empieza a escuchar la sesión de Firebase Auth. Se llama una vez al
  /// arrancar la app (los tests crean el store sin llamarlo).
  void start() {
    loading = true;
    _authSub = _auth.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? fbUser) {
    _cancelDataSubs();
    workouts.clear();
    nutritionLogs.clear();
    _myRoutines.clear();
    assignedToMe.clear();
    assignedByMe.clear();
    exercises.clear();
    foods.clear();
    templates.clear();
    waterMl = 0;
    weights.clear();
    steps.clear();
    myTrainerLink = null;
    coachSettings = null;
    trainerLinks.clear();
    coachReplies.clear();
    clientOverviews = [];
    clientsError = null;
    _overviewsFor = null;
    plan = null;
    profileLoaded = false;

    if (fbUser == null) {
      user = null;
    } else {
      // Perfil provisional hasta que llegue el documento de Firestore.
      user = AuthService.defaultProfile(fbUser);
      _listenUserData(fbUser.uid);
    }
    loading = false;
    notifyListeners();
  }

  void _listenUserData(String uid) {
    final userDoc = _userDoc(uid);
    _dataSubs.addAll([
      _db
          .collection(CatalogCollections.exercises)
          .orderBy('name')
          .snapshots()
          .listen((snap) {
            exercises
              ..clear()
              ..addAll(
                snap.docs.map(
                  (d) => Exercise.fromMap({...d.data(), 'id': d.id}),
                ),
              );
            notifyListeners();
          }, onError: _onError),
      _db
          .collection(CatalogCollections.foods)
          .orderBy('name')
          .snapshots()
          .listen((snap) {
            foods
              ..clear()
              ..addAll(
                snap.docs.map((d) => Food.fromMap({...d.data(), 'id': d.id})),
              );
            notifyListeners();
          }, onError: _onError),
      _db
          .collection(CatalogCollections.templates)
          .orderBy('name')
          .snapshots()
          .listen((snap) {
            templates
              ..clear()
              ..addAll(
                snap.docs.map(
                  (d) => Routine.fromMap(d.id, d.data(), isTemplate: true),
                ),
              );
            notifyListeners();
          }, onError: _onError),
      // includeMetadataChanges: también avisa cuando el servidor confirma
      // lo que antes solo venía de la caché local.
      userDoc.snapshots(includeMetadataChanges: true).listen((snap) {
        final data = snap.data();
        if (data == null) {
          // Sin documento. Si lo dice la caché, aún no lo sabemos seguro;
          // si lo dice el servidor, es una cuenta recién creada y se sigue
          // con el perfil provisional.
          if (snap.metadata.isFromCache) return;
          profileLoaded = true;
          notifyListeners();
          return;
        }
        user = UserProfile.fromMap(data);
        profileLoaded = true;
        // El rol puede cambiar en cualquier momento (lo cambia un admin).
        _updateTrainerSub(uid);
        notifyListeners();
      }, onError: _onError),
      _planDoc(uid).snapshots().listen((snap) {
        final data = snap.data();
        plan = data == null ? null : TrainingPlan.fromMap(data);
        notifyListeners();
      }, onError: _onError),
      _waterDoc(uid, DateTime.now()).snapshots().listen((snap) {
        waterMl = (snap.data()?['ml'] as num?)?.toInt() ?? 0;
        notifyListeners();
      }, onError: _onError),
      _db
          .collection('assignedRoutines')
          .where('userId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            assignedToMe
              ..clear()
              ..addAll(
                snap.docs.map((d) => AssignedRoutine.fromMap(d.id, d.data())),
              )
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            notifyListeners();
          }, onError: _onError),
      userDoc
          .collection('workouts')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snap) {
            workouts
              ..clear()
              ..addAll(snap.docs.map((d) => Workout.fromMap(d.id, d.data())));
            notifyListeners();
          }, onError: _onError),
      userDoc
          .collection('routines')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snap) {
            _myRoutines
              ..clear()
              ..addAll(snap.docs.map((d) => Routine.fromMap(d.id, d.data())));
            notifyListeners();
          }, onError: _onError),
      userDoc
          .collection('weights')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snap) {
            weights
              ..clear()
              ..addAll(snap.docs.map((d) => WeightEntry.fromMap(d.data())));
            notifyListeners();
          }, onError: _onError),
      userDoc
          .collection('steps')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snap) {
            steps
              ..clear()
              ..addAll(snap.docs.map((d) => StepsEntry.fromMap(d.data())));
            notifyListeners();
          }, onError: _onError),
      _linkDoc(uid).snapshots().listen((snap) {
        final data = snap.data();
        myTrainerLink = data == null ? null : TrainerLink.fromMap(data);
        notifyListeners();
      }, onError: _onError),
      _coachDoc(uid).snapshots().listen((snap) {
        final data = snap.data();
        coachSettings = data == null ? null : CoachSettings.fromMap(data);
        notifyListeners();
      }, onError: _onError),
      _repliesOf(uid).snapshots().listen((snap) {
        coachReplies
          ..clear()
          ..addEntries(
            snap.docs.map((d) => MapEntry(d.id, CoachReply.fromMap(d.data()))),
          );
        notifyListeners();
      }, onError: _onError),
      userDoc
          .collection('nutrition')
          .orderBy('date', descending: true)
          .snapshots()
          .listen((snap) {
            nutritionLogs
              ..clear()
              ..addAll(
                snap.docs.map((d) => NutritionEntry.fromMap(d.id, d.data())),
              );
            notifyListeners();
          }, onError: _onError),
    ]);
  }

  /// Escucha mis rutinas asignadas y mis solicitudes y clientes solo
  /// mientras sea entrenador (el rol puede cambiar en cualquier momento).
  void _updateTrainerSub(String uid) {
    if (!isTrainer) {
      _cancelTrainerSubs();
      assignedByMe.clear();
      trainerLinks.clear();
      return;
    }
    if (_trainerSubs.isNotEmpty) return;
    _trainerSubs.addAll([
      _db
          .collection('assignedRoutines')
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            assignedByMe
              ..clear()
              ..addAll(
                snap.docs.map((d) => AssignedRoutine.fromMap(d.id, d.data())),
              )
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            notifyListeners();
          }, onError: _onError),
      _db
          .collection('trainerLinks')
          .where('trainerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
            trainerLinks
              ..clear()
              ..addAll(snap.docs.map((d) => TrainerLink.fromMap(d.data())))
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            notifyListeners();
          }, onError: _onError),
    ]);
  }

  void _cancelTrainerSubs() {
    for (final sub in _trainerSubs) {
      sub.cancel();
    }
    _trainerSubs.clear();
  }

  void _cancelDataSubs() {
    for (final sub in _dataSubs) {
      sub.cancel();
    }
    _dataSubs.clear();
    _cancelTrainerSubs();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataSubs();
    super.dispose();
  }

  /// Guarda las respuestas del cuestionario inicial, lo marca como hecho y
  /// guarda [newPlan], el plan que se le ha enseñado en "Tu plan".
  /// `daysPerWeek` se rellena con los días elegidos porque lo usan la
  /// recomendación de rutina y las estadísticas del entrenador.
  /// Espera a Firestore para que la pantalla
  /// pueda mostrar un indicador y avisar si falla. Devuelve el mensaje de
  /// error, o null si se guardó bien.
  Future<String?> completeOnboarding(
    UserProfile profile,
    TrainingPlan newPlan,
  ) async {
    profile
      ..onboardingCompleted = true
      ..daysPerWeek = profile.trainingDays.length;
    final error = await _saveProfileAndPlan(profile, newPlan);
    if (error != null) return 'No se pudieron guardar tus respuestas: $error';
    user = profile;
    plan = newPlan;
    notifyListeners();
    return null;
  }

  /// El único método para guardar cambios de días, minutos, material,
  /// lesiones, objetivo o experiencia (lo usarán "Editar perfil" y
  /// "Ajustes de entrenamiento"). Guarda el perfil y, si cambia algo de lo
  /// que depende el plan, lo actualiza con [RoutineGenerator.update], que
  /// respeta los cambios que hizo el usuario.
  /// Devuelve un record con el error (o null) y los avisos del plan.
  Future<({String? error, List<String> warnings})> saveTrainingProfile(
    UserProfile next,
  ) async {
    next.daysPerWeek = next.trainingDays.length;
    final update = _planUpdateFor(next);
    final error = await _saveProfileAndPlan(next, update?.plan);
    if (error != null) {
      return (
        error: 'No se pudieron guardar los cambios: $error',
        warnings: const <String>[],
      );
    }
    final stepsChanged = user?.stepsGoal != next.stepsGoal;
    user = next;
    if (update != null) plan = update.plan;
    // Sin entrenador, si cambia su objetivo de pasos deja de usarse el que
    // le puso el entrenador anterior.
    if (stepsChanged) _clearCoachStepsGoal();
    notifyListeners();
    return (error: null, warnings: update?.warnings ?? const <String>[]);
  }

  /// Plan que corresponde a [next], o null si no hace falta tocarlo porque
  /// no cambia nada de lo que lo afecta y el plan está generado con las
  /// reglas actuales ([RoutineGenerator.isOutdated]). Si aún no había plan
  /// (cuentas de antes del generador), se crea uno.
  PlanUpdate? _planUpdateFor(UserProfile next) {
    final current = plan;
    if (current == null) {
      return PlanUpdate(
        plan: RoutineGenerator.generate(next, exercises),
        warnings: const [],
      );
    }
    final previous = user;
    final unchanged = previous != null && previous.sameTrainingAs(next);
    if (unchanged && !RoutineGenerator.isOutdated(current)) return null;
    return RoutineGenerator.update(current, next, exercises);
  }

  /// Guarda el perfil y el plan (si no es null) a la vez, en un WriteBatch:
  /// o se guardan los dos o ninguno. Devuelve el error de Firebase, o null.
  Future<String?> _saveProfileAndPlan(
    UserProfile profile,
    TrainingPlan? newPlan,
  ) async {
    try {
      final batch = _db.batch();
      // merge: para no borrar el campo `role`, que no va en toMap().
      batch.set(_userDoc(_uid), profile.toMap(), SetOptions(merge: true));
      if (newPlan != null) batch.set(_planDoc(_uid), newPlan.toMap());
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? e.code;
    }
  }

  // --- Cambios del usuario en un día del plan ---
  // Los usará la pantalla de entrenamiento (prompt 5). Devuelven el mensaje
  // de error, o null si se hizo el cambio.

  static const _notTrainingDay = 'Ese día no es de entreno.';
  static const _alreadyInDay = 'Ese ejercicio ya está en el entreno del día.';

  /// Añade [exercise] al día [weekday] (1 = lunes) como ejercicio del
  /// usuario (`isCustom`), con las series y repeticiones de su perfil.
  String? addPlanExercise(int weekday, Exercise exercise) {
    final day = plan?.dayFor(weekday);
    final profile = user;
    if (day == null || profile == null) return _notTrainingDay;
    if (day.contains(exercise.id)) return _alreadyInDay;
    _savePlanDay(day.withExercise(_customExercise(exercise, profile)));
    return null;
  }

  /// Quita el ejercicio del día. No vuelve aunque se actualice el plan.
  String? removePlanExercise(int weekday, String exerciseId) {
    final day = plan?.dayFor(weekday);
    if (day == null) return _notTrainingDay;
    _savePlanDay(day.withoutExercise(exerciseId));
    return null;
  }

  /// Cambia el ejercicio [oldId] por [replacement] en el mismo lugar. El
  /// nuevo queda como del usuario y el antiguo, como quitado.
  String? replacePlanExercise(int weekday, String oldId, Exercise replacement) {
    final day = plan?.dayFor(weekday);
    final profile = user;
    if (day == null || profile == null) return _notTrainingDay;
    if (day.contains(replacement.id)) return _alreadyInDay;
    _savePlanDay(day.replacing(oldId, _customExercise(replacement, profile)));
    return null;
  }

  /// Guarda [day] en el plan de una sola vez (con todos los cambios del
  /// entreno en directo). Ver `WorkoutDraft.applyToPlanDay`.
  void updatePlanDay(PlanDay day) => _savePlanDay(day);

  PlanExercise _customExercise(Exercise exercise, UserProfile profile) =>
      RoutineGenerator.prescribe(exercise, profile, isCustom: true);

  /// Pone [day] en el plan y lo sube a Firestore sin esperar, como el resto
  /// de escrituras.
  void _savePlanDay(PlanDay day) {
    final current = plan;
    if (current == null) return;
    final next = current.withDay(day);
    plan = next;
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return; // en los tests no hay Firebase
    _save(_planDoc(uid).set(next.toMap()));
  }

  // Las escrituras no se esperan: Firestore las aplica primero en local
  // (los listeners actualizan la UI al momento) y las sube cuando hay red.
  void addWorkout(Workout workout) {
    _save(
      _userDoc(
        _uid,
      ).collection('workouts').doc(workout.id).set(workout.toMap()),
    );
  }

  void deleteWorkout(String id) {
    // Se quita ya de la lista para que la UI no espere al listener.
    workouts.removeWhere((w) => w.id == id);
    notifyListeners();
    _save(_userDoc(_uid).collection('workouts').doc(id).delete());
  }

  void addRoutine(Routine routine) {
    _save(
      _userDoc(
        _uid,
      ).collection('routines').doc(routine.id).set(routine.toMap()),
    );
  }

  void deleteRoutine(String id) {
    _myRoutines.removeWhere((r) => r.id == id);
    notifyListeners();
    _save(_userDoc(_uid).collection('routines').doc(id).delete());
  }

  // --- Entrenadores y admins ---

  /// Lista de usuarios registrados. Las reglas de Firestore solo lo permiten
  /// a entrenadores y admins.
  Future<List<AppUser>> fetchUsers() async {
    final snap = await _db.collection('users').get();
    final users = [
      for (final d in snap.docs)
        AppUser(uid: d.id, profile: UserProfile.fromMap(d.data())),
    ];
    users.sort(
      (a, b) =>
          a.profile.name.toLowerCase().compareTo(b.profile.name.toLowerCase()),
    );
    return users;
  }

  /// Cambia el rol de otro usuario. Solo admins (lo comprueban las reglas).
  Future<String?> setRole(String uid, UserRole role) async {
    if (!isAdmin) return 'Solo un admin puede cambiar roles.';
    if (uid == _uid) return 'No puedes cambiar tu propio rol.';
    try {
      await _userDoc(uid).update({'role': role.name});
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudo cambiar el rol: ${e.message ?? e.code}';
    }
  }

  /// Asigna [routine] al día [dayNumber] del plan de [to] (1 = su primer
  /// día de entreno). Solo hay una rutina por día: si ya le había asignado
  /// otra a ese día, se borra en el mismo lote para no dejar restos.
  void assignRoutine(AppUser to, Routine routine, {required int dayNumber}) {
    final assignedRoutines = _db.collection('assignedRoutines');
    final batch = _db.batch();
    for (final old in assignedByMe) {
      if (old.userId == to.uid && old.dayNumber == dayNumber) {
        batch.delete(assignedRoutines.doc(old.id));
      }
    }
    final doc = assignedRoutines.doc();
    final assigned = AssignedRoutine(
      id: doc.id,
      routine: routine,
      trainerId: _uid,
      trainerName: user?.name ?? 'Entrenador',
      userId: to.uid,
      userName: to.profile.name,
      createdAt: DateTime.now(),
      dayNumber: dayNumber,
    );
    batch.set(doc, assigned.toMap());
    _save(batch.commit());
  }

  void deleteAssignedRoutine(String id) {
    assignedByMe.removeWhere((r) => r.id == id);
    notifyListeners();
    _save(_db.collection('assignedRoutines').doc(id).delete());
  }

  // --- Entrenador: lado del cliente ("Mi entrenador", en Perfil) ---

  /// Lo que ve el cliente: sin entrenador, solicitud pendiente o vinculado.
  MyTrainerState get myTrainerState => TrainerLinkRules.stateOf(myTrainerLink);

  /// True si un entrenador ha aceptado mi solicitud. Solo entonces se ven
  /// sus notas en los ejercicios.
  bool get hasAcceptedTrainer => myTrainerLink?.isAccepted ?? false;

  /// Envía una solicitud al entrenador de [text] (el código que ha escrito
  /// el usuario). Espera a Firestore para poder decir si el código no
  /// existe. Devuelve el mensaje de error, o null si se envió.
  Future<String?> sendTrainerRequest(String text) async {
    final code = TrainerCode.normalize(text);
    final error = TrainerLinkRules.validateRequest(
      code: code,
      current: myTrainerLink,
    );
    if (error != null) return error;
    final uid = _sessionUid;
    if (uid == null) return 'No hay sesión.';
    try {
      final data = (await _codeDoc(code).get()).data();
      if (data == null) return TrainerLinkRules.codeNotFound;
      final trainerId = data['trainerId'] as String? ?? '';
      if (trainerId == uid) return TrainerLinkRules.ownCode;
      final link = TrainerLinkRules.newRequest(
        clientId: uid,
        clientName: user?.name ?? '',
        trainerId: trainerId,
        trainerName: data['trainerName'] as String? ?? 'Entrenador',
        code: code,
      );
      await _linkDoc(uid).set(link.toMap());
      myTrainerLink = link;
      notifyListeners();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudo enviar la solicitud: ${e.message ?? e.code}';
    }
  }

  /// Cancela mi solicitud o me desvinculo de mi entrenador. Lo que me puso
  /// (objetivos y ejercicios) se queda; sus notas dejan de verse.
  void leaveTrainer() {
    myTrainerLink = null;
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return;
    _save(_linkDoc(uid).delete());
  }

  /// "Volver al automático": deja de usar los objetivos que puso un
  /// entrenador. Solo si ya no tengo entrenador (mientras lo tengo, los
  /// cambia él; las reglas tampoco lo permiten).
  void resetMyCoachSettings() {
    if (hasAcceptedTrainer) return;
    coachSettings = null;
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return;
    _save(_coachDoc(uid).delete());
  }

  /// Quita solo el objetivo de pasos del entrenador (cuando ya no tengo
  /// entrenador y pongo el mío en Ajustes).
  void _clearCoachStepsGoal() {
    final coach = coachSettings;
    if (hasAcceptedTrainer || coach == null || coach.stepsGoal == null) return;
    final next = CoachSettings(kcalTarget: coach.kcalTarget);
    if (next.isEmpty) {
      resetMyCoachSettings();
      return;
    }
    coachSettings = next;
    final uid = _sessionUid;
    if (uid == null) return;
    _save(_coachDoc(uid).set(next.toMap()));
  }

  // --- Entrenador: código, solicitudes y clientes ---

  /// Intentos para encontrar un código libre. Con mil millones de códigos
  /// posibles, casi siempre vale el primero.
  static const _codeAttempts = 5;

  /// Crea mi código si aún no tengo ninguno (al abrir "Mi código").
  Future<String?> ensureTrainerCode() async {
    if (user?.trainerCode != null) return null;
    return _newTrainerCode();
  }

  /// "Generar otro": el código anterior deja de valer. Los clientes ya
  /// vinculados no cambian, porque su vínculo no depende del código.
  Future<String?> regenerateTrainerCode() =>
      _newTrainerCode(old: user?.trainerCode);

  /// Crea un código nuevo y lo guarda en mi perfil, todo en un WriteBatch.
  /// Si el código ya es de otro, las reglas rechazan crearlo (sería
  /// modificar un documento ajeno) y se prueba con otro.
  Future<String?> _newTrainerCode({String? old}) async {
    final uid = _sessionUid;
    final profile = user;
    if (uid == null || profile == null) return 'No hay sesión.';
    if (!isTrainer) return 'Solo los entrenadores tienen código.';
    try {
      // Si el antiguo ya no existe, no se puede borrar (las reglas miran
      // de quién es); por eso se comprueba antes.
      final oldToDelete = old != null && (await _codeDoc(old).get()).exists
          ? old
          : null;
      for (var i = 0; i < _codeAttempts; i++) {
        final code = TrainerCode.generate();
        final batch = _db.batch()
          ..set(_codeDoc(code), {
            'trainerId': uid,
            'trainerName': profile.name,
            'createdAt': Timestamp.now(),
          })
          ..update(_userDoc(uid), {'trainerCode': code});
        if (oldToDelete != null) batch.delete(_codeDoc(oldToDelete));
        try {
          await batch.commit();
          profile.trainerCode = code;
          notifyListeners();
          return null;
        } on FirebaseException catch (e) {
          if (e.code != 'permission-denied') rethrow;
        }
      }
      return 'No se pudo crear el código. Inténtalo de nuevo.';
    } on FirebaseException catch (e) {
      return 'No se pudo crear el código: ${e.message ?? e.code}';
    }
  }

  /// Acepta la solicitud de [clientId]: pasa a ser mi cliente.
  void acceptRequest(String clientId) {
    final index = trainerLinks.indexWhere((l) => l.clientId == clientId);
    if (index == -1) return;
    trainerLinks[index] = trainerLinks[index].accept();
    notifyListeners();
    if (_sessionUid == null) return;
    _save(_linkDoc(clientId).update({'status': LinkStatus.accepted.name}));
  }

  /// Rechaza la solicitud de [clientId] o lo desvincula si ya era cliente.
  void removeClientLink(String clientId) {
    trainerLinks.removeWhere((l) => l.clientId == clientId);
    notifyListeners();
    if (_sessionUid == null) return;
    _save(_linkDoc(clientId).delete());
  }

  /// Perfiles de mis clientes, ordenados por nombre. Se leen uno a uno:
  /// las reglas ya no dejan a un entrenador listar todos los usuarios.
  Future<List<AppUser>> fetchClients() async {
    final docs = await Future.wait([
      for (final id in myClientIds) _userDoc(id).get(),
    ]);
    final clients = [
      for (final d in docs)
        if (d.data() case final data?)
          AppUser(uid: d.id, profile: UserProfile.fromMap(data)),
    ];
    clients.sort(
      (a, b) =>
          a.profile.name.toLowerCase().compareTo(b.profile.name.toLowerCase()),
    );
    return clients;
  }

  /// Plan de un cliente, o null si aún no tiene.
  Future<TrainingPlan?> fetchPlanOf(String uid) async {
    final data = (await _planDoc(uid).get()).data();
    return data == null ? null : TrainingPlan.fromMap(data);
  }

  /// Objetivos que he puesto a un cliente (vacío si ninguno).
  Future<CoachSettings> fetchCoachSettingsOf(String uid) async {
    final data = (await _coachDoc(uid).get()).data();
    return data == null ? const CoachSettings() : CoachSettings.fromMap(data);
  }

  /// Guarda el plan de un cliente. Espera a Firestore para avisar si falla.
  Future<String?> saveClientPlan(String uid, TrainingPlan clientPlan) =>
      _trainerWrite(() => _planDoc(uid).set(clientPlan.toMap()));

  /// Guarda los objetivos de un cliente. Si todo vuelve al automático, se
  /// borra el documento. Devuelve el error, o null.
  Future<String?> saveClientCoachSettings(
    String uid,
    CoachSettings settings,
  ) async {
    final error = settings.validate();
    if (error != null) return error;
    return _trainerWrite(
      () => settings.isEmpty
          ? _coachDoc(uid).delete()
          : _coachDoc(uid).set(settings.toMap()),
    );
  }

  // --- Modo entrenador: lista de clientes y notas ---

  /// True si [clientOverviews] no es de los clientes que tengo ahora (por
  /// ejemplo, porque acabo de aceptar una solicitud) o aún no se ha cargado.
  bool get clientOverviewsOutdated {
    final loaded = _overviewsFor;
    final ids = myClientIds;
    return loaded == null ||
        loaded.length != ids.length ||
        !loaded.containsAll(ids);
  }

  /// Notas de mis clientes que aún no he leído (el globo de "Notas").
  int get unreadClientNotes =>
      clientOverviews.fold(0, (total, c) => total + c.unreadNotes);

  /// Carga los datos de la semana de cada cliente (ver [ClientOverview]).
  /// Se llama al abrir el modo entrenador y al tirar hacia abajo.
  Future<void> loadClientOverviews() async {
    if (_sessionUid == null) return; // en los tests no hay Firebase
    _overviewsFor = myClientIds;
    clientsLoading = true;
    clientsError = null;
    notifyListeners();
    try {
      final today = DateTime.now();
      final clients = await fetchClients();
      clientOverviews = await Future.wait([
        for (final c in clients) _fetchOverview(c, today),
      ]);
    } on FirebaseException catch (e) {
      clientsError =
          'No se pudieron cargar tus clientes: ${e.message ?? e.code}';
    }
    clientsLoading = false;
    notifyListeners();
  }

  /// Lee a la vez los datos de un cliente que necesita [ClientOverview].
  Future<ClientOverview> _fetchOverview(AppUser client, DateTime today) async {
    final doc = _userDoc(client.uid);
    Future<QuerySnapshot<Map<String, dynamic>>> since(
      String collection,
      DateTime from,
    ) => doc
        .collection(collection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('date', descending: true)
        .get();

    final workoutsFrom = ClientOverview.workoutsFrom(today);
    final othersFrom = ClientOverview.othersFrom(today);
    // `.wait` lanza todas las lecturas a la vez y espera a que acaben
    // (como lanzar varios hilos en Java y esperarlos con join).
    final (plan, coach, workouts, nutrition, weights, steps, replies) = await (
      fetchPlanOf(client.uid),
      fetchCoachSettingsOf(client.uid),
      since('workouts', workoutsFrom),
      since('nutrition', othersFrom),
      since('weights', othersFrom),
      since('steps', othersFrom),
      _repliesOf(client.uid).get(),
    ).wait;
    return ClientOverview(
      user: client,
      today: today,
      plan: plan,
      coach: coach,
      workouts: [
        for (final d in workouts.docs) Workout.fromMap(d.id, d.data()),
      ],
      nutrition: [
        for (final d in nutrition.docs) NutritionEntry.fromMap(d.id, d.data()),
      ],
      weights: [for (final d in weights.docs) WeightEntry.fromMap(d.data())],
      steps: [for (final d in steps.docs) StepsEntry.fromMap(d.data())],
      replies: {
        for (final d in replies.docs) d.id: CoachReply.fromMap(d.data()),
      },
    );
  }

  /// Datos cargados de un cliente, o null si no está en la lista.
  ClientOverview? overviewOf(String clientId) {
    for (final c in clientOverviews) {
      if (c.uid == clientId) return c;
    }
    return null;
  }

  /// Pone [changed] en las respuestas del cliente [clientId] (en local).
  void _updateReplies(String clientId, List<CoachReply> changed) {
    clientOverviews = [
      for (final c in clientOverviews)
        c.uid == clientId ? c.withReplies(changed) : c,
    ];
    notifyListeners();
  }

  /// Responde a una nota (y la marca como leída). El cliente ve la
  /// respuesta en el historial del ejercicio y en su tarjeta del entreno.
  /// Devuelve el error, o null.
  Future<String?> replyToNote(ClientNote note, String text) async {
    final error = CoachReply.validate(text);
    if (error != null) return error;
    final reply = _replyFor(note).copyWith(
      reply: text.trim(),
      readAt: note.reply?.readAt ?? DateTime.now(),
    );
    _updateReplies(note.clientId, [reply]);
    if (_sessionUid == null) return null; // en los tests no hay Firebase
    return _trainerWrite(
      () => _repliesOf(note.clientId).doc(reply.id).set(reply.toMap()),
    );
  }

  /// Marca como leídas todas las notas de un cliente (al abrir la pestaña
  /// Notas de su ficha). Se escriben todas en un lote.
  void markNotesRead(String clientId) {
    final unread = [
      for (final n in overviewOf(clientId)?.notes ?? const <ClientNote>[])
        if (!n.isRead) n,
    ];
    if (unread.isEmpty) return;
    final now = DateTime.now();
    final changed = [
      for (final n in unread) _replyFor(n).copyWith(readAt: now),
    ];
    _updateReplies(clientId, changed);
    if (_sessionUid == null) return;
    final batch = _db.batch();
    for (final r in changed) {
      batch.set(_repliesOf(clientId).doc(r.id), r.toMap());
    }
    _save(batch.commit());
  }

  /// La respuesta que ya tiene la nota o una nueva vacía.
  static CoachReply _replyFor(ClientNote note) =>
      note.reply ??
      CoachReply(
        workoutId: note.workoutId,
        exerciseIndex: note.exerciseIndex,
        exerciseId: note.exercise.id,
      );

  Future<String?> _trainerWrite(Future<void> Function() write) async {
    try {
      await write();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudo guardar: ${e.message ?? e.code}';
    }
  }

  void addNutrition(NutritionEntry entry) {
    _save(
      _userDoc(_uid).collection('nutrition').doc(entry.id).set(entry.toMap()),
    );
  }

  void removeNutrition(String id) {
    _save(_userDoc(_uid).collection('nutrition').doc(id).delete());
  }

  /// Suma (o resta, con [ml] negativo) agua al día de hoy. Nunca baja de 0.
  void addWater(int ml) {
    waterMl = (waterMl + ml).clamp(0, 20000);
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return;
    _save(
      _waterDoc(
        uid,
        DateTime.now(),
      ).set({'ml': waterMl, 'date': Timestamp.now()}),
    );
  }

  // --- Peso y pasos (pestaña Progreso y Perfil) ---
  // Un documento por día: si se registra dos veces el mismo día, se
  // sobrescribe. Se puede registrar hoy o un día anterior (ver
  // [validateLogDay]). Como el resto de escrituras, no se espera a
  // Firestore; devuelven el mensaje de error de la validación, o null.

  /// Guarda [kg] como el peso de [day] (hoy si no se indica). Si es el
  /// registro más reciente, también lo pone en el perfil (`weightKg`), para
  /// que las calorías usen el peso más reciente. Un peso de hace unos días
  /// no cambia el perfil si ya hay uno posterior.
  String? saveWeight(double kg, {DateTime? day}) {
    final date = _dateOnly(day ?? DateTime.now());
    final error =
        validateLogDay(date, DateTime.now()) ?? WeightEntry.validate(kg);
    if (error != null) return error;
    final entry = WeightEntry(date: date, kg: kg);
    _putInOrder(weights, entry, (e) => e.date);
    // La lista va de más reciente a más antiguo: si quedó la primera, es
    // la más reciente.
    final isLatest = identical(weights.first, entry);
    if (isLatest) user?.weightKg = kg;
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return null; // en los tests no hay Firebase
    // Los dos a la vez: o se guardan el registro y el perfil, o ninguno.
    final batch = _db.batch()
      ..set(
        _userDoc(uid).collection('weights').doc(dayKey(entry.date)),
        entry.toMap(),
      );
    if (isLatest) batch.update(_userDoc(uid), {'weightKg': kg});
    _save(batch.commit());
    return null;
  }

  /// Guarda [count] como los pasos de [day] (hoy si no se indica).
  String? saveSteps(int count, {DateTime? day}) {
    final date = _dateOnly(day ?? DateTime.now());
    final error =
        validateLogDay(date, DateTime.now()) ?? StepsEntry.validate(count);
    if (error != null) return error;
    final entry = StepsEntry(date: date, steps: count);
    _putInOrder(steps, entry, (e) => e.date);
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return null;
    _save(
      _userDoc(
        uid,
      ).collection('steps').doc(dayKey(entry.date)).set(entry.toMap()),
    );
    return null;
  }

  /// Borra el peso de ese día. Si era el más reciente, el perfil pasa a
  /// tener el peso del registro anterior (si queda alguno).
  void deleteWeight(DateTime day) {
    final wasLatest =
        weights.isNotEmpty && dayKey(weights.first.date) == dayKey(day);
    weights.removeWhere((e) => dayKey(e.date) == dayKey(day));
    final newLatest = wasLatest && weights.isNotEmpty ? weights.first : null;
    if (newLatest != null) user?.weightKg = newLatest.kg;
    notifyListeners();
    final uid = _sessionUid;
    if (uid == null) return;
    final batch = _db.batch()
      ..delete(_userDoc(uid).collection('weights').doc(dayKey(day)));
    if (newLatest != null) {
      batch.update(_userDoc(uid), {'weightKg': newLatest.kg});
    }
    _save(batch.commit());
  }

  /// El día de [date] a las 00:00.
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Pone [entry] en [list] en su sitio por fecha (la lista va de la más
  /// reciente a la más antigua) y quita el registro que hubiera del mismo
  /// día. Así la pantalla se actualiza sin esperar al listener.
  static void _putInOrder<T>(
    List<T> list,
    T entry,
    DateTime Function(T) dateOf,
  ) {
    list.removeWhere((e) => dayKey(dateOf(e)) == dayKey(dateOf(entry)));
    // Primera posición cuyo registro es más antiguo que el nuevo.
    final index = list.indexWhere((e) => dateOf(e).isBefore(dateOf(entry)));
    list.insert(index == -1 ? list.length : index, entry);
  }

  // --- Tema (claro u oscuro) ---

  /// Lee el tema guardado en el dispositivo. Se llama al arrancar la app.
  /// Si no hay nada guardado (o no se puede leer), se queda el oscuro.
  Future<void> loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(themeKey);
      themeMode = saved == ThemeMode.light.name
          ? ThemeMode.light
          : ThemeMode.dark;
      notifyListeners();
    } on Exception {
      // Sin acceso al almacenamiento local: se mantiene el tema oscuro.
    }
  }

  /// Cambia el tema al momento y lo guarda para la próxima vez.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeKey, mode.name);
  }

  // --- Modo usuario / entrenador ---

  /// Lee el modo guardado en el dispositivo. Se llama al arrancar la app.
  /// Si no hay nada guardado (o no se puede leer), modo usuario.
  Future<void> loadTrainerMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _trainerModeChosen = prefs.getBool(trainerModeKey) ?? false;
      notifyListeners();
    } on Exception {
      // Sin acceso al almacenamiento local: se queda en modo usuario.
    }
  }

  /// Cambia de modo al momento y lo guarda para la próxima vez. Solo los
  /// entrenadores pueden pasar a modo entrenador.
  Future<void> setTrainerMode(bool on) async {
    _trainerModeChosen = on && isTrainer;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(trainerModeKey, _trainerModeChosen);
  }

  // --- Catálogo (solo admins; lo comprueban las reglas) ---

  /// True si todavía no hay nada en el catálogo de Firestore.
  bool get catalogEmpty =>
      exercises.isEmpty && foods.isEmpty && templates.isEmpty;

  CollectionReference<Map<String, dynamic>> _catalog(String name) =>
      _db.collection(name);

  /// Sube a Firestore los datos de assets/seed/catalog.json. No borra nada:
  /// si un documento ya existe con el mismo id, lo sobrescribe.
  Future<String?> seedCatalog() async {
    if (!isAdmin) return 'Solo un admin puede cargar el catálogo.';
    try {
      final seed = await CatalogSeed.load();
      final batch = _db.batch();
      for (final e in seed.exercises) {
        batch.set(_catalog(CatalogCollections.exercises).doc(e.id), e.toMap());
      }
      for (final f in seed.foods) {
        batch.set(_catalog(CatalogCollections.foods).doc(f.id), f.toMap());
      }
      for (final t in seed.templates) {
        batch.set(_catalog(CatalogCollections.templates).doc(t.id), t.toMap());
      }
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudo cargar el catálogo: ${e.message ?? e.code}';
    }
  }

  /// Plantillas del archivo cuyo id aún no está en Firestore. Compara con
  /// [templates], que ya se mantiene al día con la escucha de
  /// `routineTemplates`, así que no hace lecturas extra.
  List<Routine> missingSeedTemplates(CatalogSeed seed) {
    final existing = {for (final t in templates) t.id};
    return [
      for (final t in seed.templates)
        if (!existing.contains(t.id)) t,
    ];
  }

  /// Sube a Firestore los ejercicios de assets/seed/catalog.json y crea
  /// las plantillas del archivo que todavía no existen:
  /// - ejercicios: crea los nuevos y sobrescribe los que ya existen
  ///   (ex1–ex10) con sus campos nuevos;
  /// - plantillas que ya existen: solo se actualizan las copias de esos
  ///   ejercicios, como en [saveExercise];
  /// - plantillas que faltan ([missingSeedTemplates]): se crean.
  /// No toca los alimentos ni el resto de lo que haya editado el admin.
  /// [seed] permite pasar el archivo ya leído (la pantalla lo lee antes
  /// para decir cuánto se sube). Devuelve el mensaje de error, o null si
  /// fue bien.
  Future<String?> updateExercisesFromSeed([CatalogSeed? seed]) async {
    if (!isAdmin) return 'Solo un admin puede actualizar los ejercicios.';
    try {
      final data = seed ?? await CatalogSeed.load();
      final byId = {for (final e in data.exercises) e.id: e};
      // Todo en un WriteBatch: o se guarda todo o nada. Admite hasta 500
      // operaciones y aquí hay 85 ejercicios más unas pocas plantillas.
      final batch = _db.batch();
      for (final e in data.exercises) {
        batch.set(_catalog(CatalogCollections.exercises).doc(e.id), e.toMap());
      }
      for (final t in templates) {
        if (!t.exercises.any((e) => byId.containsKey(e.id))) continue;
        batch.update(_catalog(CatalogCollections.templates).doc(t.id), {
          'exercises': [for (final e in t.exercises) (byId[e.id] ?? e).toMap()],
        });
      }
      for (final t in missingSeedTemplates(data)) {
        batch.set(_catalog(CatalogCollections.templates).doc(t.id), t.toMap());
      }
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudieron actualizar los ejercicios: ${e.message ?? e.code}';
    }
  }

  /// Sube a Firestore los alimentos de assets/seed/catalog.json: crea los
  /// nuevos y sobrescribe los que tienen el mismo id. Los alimentos que el
  /// admin haya creado a mano (con otro id) no se tocan, ni tampoco los
  /// ejercicios ni las plantillas. Devuelve el mensaje de error, o null.
  Future<String?> updateFoodsFromSeed([CatalogSeed? seed]) async {
    if (!isAdmin) return 'Solo un admin puede actualizar los alimentos.';
    try {
      final data = seed ?? await CatalogSeed.load();
      // Un WriteBatch admite 500 operaciones; el archivo tiene 120 alimentos.
      final batch = _db.batch();
      for (final f in data.foods) {
        batch.set(_catalog(CatalogCollections.foods).doc(f.id), f.toMap());
      }
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudieron actualizar los alimentos: ${e.message ?? e.code}';
    }
  }

  /// Id nuevo para un documento del catálogo.
  String newCatalogId(String collection) => _catalog(collection).doc().id;

  /// Crea o actualiza un ejercicio. Las plantillas guardan una copia de sus
  /// ejercicios, así que también se actualizan las que lo usan.
  Future<String?> saveExercise(Exercise exercise) {
    final batch = _db.batch();
    batch.set(
      _catalog(CatalogCollections.exercises).doc(exercise.id),
      exercise.toMap(),
    );
    for (final t in templates.where((t) => t.exercises.contains(exercise))) {
      batch.update(_catalog(CatalogCollections.templates).doc(t.id), {
        'exercises': [
          for (final e in t.exercises) (e == exercise ? exercise : e).toMap(),
        ],
      });
    }
    return _catalogWrite(batch.commit);
  }

  Future<String?> deleteExercise(Exercise exercise) async {
    final usedIn = templates.where((t) => t.exercises.contains(exercise));
    if (usedIn.isNotEmpty) {
      return 'Está en la plantilla "${usedIn.first.name}". '
          'Quítalo de ahí antes de borrarlo.';
    }
    return _catalogWrite(
      () => _catalog(CatalogCollections.exercises).doc(exercise.id).delete(),
    );
  }

  Future<String?> saveFood(Food food) => _catalogWrite(
    () => _catalog(CatalogCollections.foods).doc(food.id).set(food.toMap()),
  );

  Future<String?> deleteFood(String id) =>
      _catalogWrite(() => _catalog(CatalogCollections.foods).doc(id).delete());

  Future<String?> saveTemplate(Routine template) => _catalogWrite(
    () => _catalog(
      CatalogCollections.templates,
    ).doc(template.id).set(template.toMap()),
  );

  Future<String?> deleteTemplate(String id) => _catalogWrite(
    () => _catalog(CatalogCollections.templates).doc(id).delete(),
  );

  Future<String?> _catalogWrite(Future<void> Function() write) async {
    if (!isAdmin) return 'Solo un admin puede editar el catálogo.';
    try {
      await write();
      return null;
    } on FirebaseException catch (e) {
      return 'No se pudo guardar: ${e.message ?? e.code}';
    }
  }

  // --- Lecturas para los paneles de entrenador y admin ---

  /// Entrenos de otro usuario. Las reglas lo permiten a su entrenador y a
  /// los admins.
  Future<List<Workout>> fetchWorkoutsOf(String uid) async {
    final snap = await _userDoc(
      uid,
    ).collection('workouts').orderBy('date', descending: true).get();
    return [for (final d in snap.docs) Workout.fromMap(d.id, d.data())];
  }

  /// Entrenos de todos los usuarios, agrupados por uid (solo admins).
  Future<Map<String, List<Workout>>> fetchAllWorkouts() async {
    final snap = await _db.collectionGroup('workouts').get();
    final byUser = <String, List<Workout>>{};
    for (final d in snap.docs) {
      final uid = d.reference.parent.parent?.id;
      if (uid == null) continue;
      (byUser[uid] ??= []).add(Workout.fromMap(d.id, d.data()));
    }
    return byUser;
  }

  /// Mis clientes: los vínculos que he aceptado.
  List<TrainerLink> get clientLinks => [
    for (final l in trainerLinks)
      if (l.isAccepted) l,
  ];

  /// Solicitudes que aún no he aceptado ni rechazado.
  List<TrainerLink> get pendingRequests => [
    for (final l in trainerLinks)
      if (l.isPending) l,
  ];

  /// Uids de mis clientes (vinculados). Antes eran "a quien asigné una
  /// rutina"; ahora hace falta que el cliente lo pida y yo lo acepte.
  Set<String> get myClientIds => {for (final l in clientLinks) l.clientId};

  DocumentReference<Map<String, dynamic>> _waterDoc(String uid, DateTime day) =>
      _userDoc(uid).collection('water').doc(dayKey(day));

  DocumentReference<Map<String, dynamic>> _linkDoc(String clientId) =>
      _db.collection('trainerLinks').doc(clientId);

  DocumentReference<Map<String, dynamic>> _codeDoc(String code) =>
      _db.collection('trainerCodes').doc(code);

  DocumentReference<Map<String, dynamic>> _coachDoc(String uid) =>
      _userDoc(uid).collection('coach').doc('settings');

  CollectionReference<Map<String, dynamic>> _repliesOf(String uid) =>
      _userDoc(uid).collection('coachReplies');

  DocumentReference<Map<String, dynamic>> _planDoc(String uid) =>
      _userDoc(uid).collection('plan').doc('current');

  String get _uid => _auth.currentUser!.uid;

  /// Uid de la sesión, o null si no hay sesión o Firebase no está iniciado
  /// (por ejemplo, en los tests).
  String? get _sessionUid =>
      Firebase.apps.isEmpty ? null : _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  void _save(Future<void> write) {
    unawaited(write.catchError(_onError));
  }

  void _onError(Object error) {
    debugPrint('Firestore: $error');
  }
}

class SessionScope extends InheritedNotifier<AppStore> {
  const SessionScope({super.key, required AppStore store, required super.child})
    : super(notifier: store);

  static AppStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'SessionScope no encontrado');
    return scope!.notifier!;
  }
}
