import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';

/// Estado de la app. La sesión va con Firebase Auth y los datos de cada
/// usuario se guardan en Firestore bajo `users/{uid}`:
///   - `users/{uid}`             → perfil
///   - `users/{uid}/workouts`    → entrenamientos
///   - `users/{uid}/routines`    → rutinas propias
///   - `users/{uid}/nutrition`   → registros de comidas
/// El catálogo de ejercicios, alimentos y plantillas sigue en el código.
class AppStore extends ChangeNotifier {
  /// True mientras se comprueba si hay una sesión guardada.
  bool loading = false;
  UserProfile? user;
  bool get isLoggedIn => user != null;

  final List<Exercise> exercises = const [
    Exercise(
      id: 'ex1',
      name: 'Press de banca',
      muscleGroup: 'Pecho',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex2',
      name: 'Sentadilla',
      muscleGroup: 'Piernas',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex3',
      name: 'Peso muerto',
      muscleGroup: 'Espalda',
      equipment: 'Barra',
      level: 'Avanzado',
    ),
    Exercise(
      id: 'ex4',
      name: 'Dominadas',
      muscleGroup: 'Espalda',
      equipment: 'Peso corporal',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex5',
      name: 'Press militar',
      muscleGroup: 'Hombros',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex6',
      name: 'Remo con barra',
      muscleGroup: 'Espalda',
      equipment: 'Barra',
      level: 'Intermedio',
    ),
    Exercise(
      id: 'ex7',
      name: 'Curl de bíceps',
      muscleGroup: 'Brazos',
      equipment: 'Mancuernas',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex8',
      name: 'Extensión de tríceps',
      muscleGroup: 'Brazos',
      equipment: 'Polea',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex9',
      name: 'Zancadas',
      muscleGroup: 'Piernas',
      equipment: 'Mancuernas',
      level: 'Principiante',
    ),
    Exercise(
      id: 'ex10',
      name: 'Plancha',
      muscleGroup: 'Core',
      equipment: 'Peso corporal',
      level: 'Principiante',
    ),
  ];

  final List<Food> foods = const [
    Food(
      id: 'f1',
      name: 'Pechuga de pollo',
      kcalPer100: 110,
      proteinPer100: 23,
      carbsPer100: 0,
      fatPer100: 1.5,
    ),
    Food(
      id: 'f2',
      name: 'Arroz blanco cocido',
      kcalPer100: 130,
      proteinPer100: 2.7,
      carbsPer100: 28,
      fatPer100: 0.3,
    ),
    Food(
      id: 'f3',
      name: 'Huevo entero',
      kcalPer100: 143,
      proteinPer100: 13,
      carbsPer100: 1.1,
      fatPer100: 9.5,
    ),
    Food(
      id: 'f4',
      name: 'Plátano',
      kcalPer100: 89,
      proteinPer100: 1.1,
      carbsPer100: 23,
      fatPer100: 0.3,
    ),
    Food(
      id: 'f5',
      name: 'Avena',
      kcalPer100: 379,
      proteinPer100: 13,
      carbsPer100: 67,
      fatPer100: 6.5,
    ),
    Food(
      id: 'f6',
      name: 'Yogur griego',
      kcalPer100: 97,
      proteinPer100: 9,
      carbsPer100: 3.6,
      fatPer100: 5,
    ),
  ];

  late final List<Routine> _templates;
  final List<Routine> _myRoutines = [];
  final List<Workout> workouts = [];
  final List<NutritionEntry> nutritionLogs = [];

  List<Routine> get routines => [..._templates, ..._myRoutines];

  /// Rutinas que me han asignado mis entrenadores.
  final List<AssignedRoutine> assignedToMe = [];

  /// Rutinas que he asignado yo (solo entrenadores y admins).
  final List<AssignedRoutine> assignedByMe = [];

  /// Agua bebida hoy, en ml (users/{uid}/water/{aaaa-mm-dd}).
  int waterMl = 0;

  String? get currentUid => _auth.currentUser?.uid;

  /// Foto de la cuenta de Google, si entró con Google.
  String? get photoUrl => _auth.currentUser?.photoURL;
  UserRole get role => user?.role ?? UserRole.user;
  bool get isAdmin => role == UserRole.admin;
  bool get isTrainer => role == UserRole.trainer || role == UserRole.admin;

  StreamSubscription<User?>? _authSub;
  final List<StreamSubscription<Object?>> _dataSubs = [];
  StreamSubscription<Object?>? _trainerSub;
  bool _googleReady = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  AppStore() {
    _templates = [
      Routine(
        id: 'tpl-full',
        name: 'Full body 3 días',
        description: 'Plantilla para 3 días semanales. Cuerpo completo.',
        templateName: 'Full body',
        isTemplate: true,
        exercises: [exercises[1], exercises[0], exercises[3], exercises[9]],
      ),
      Routine(
        id: 'tpl-ul',
        name: 'Torso / Pierna',
        description: 'Plantilla de 4 días: dos de torso y dos de pierna.',
        templateName: 'Torso/Pierna',
        isTemplate: true,
        exercises: [exercises[0], exercises[5], exercises[1], exercises[2]],
      ),
      Routine(
        id: 'tpl-ppl',
        name: 'Push / Pull / Legs',
        description: 'Plantilla de 6 días o 3 días según disponibilidad.',
        templateName: 'Push/Pull/Legs',
        isTemplate: true,
        exercises: [exercises[0], exercises[4], exercises[5], exercises[1]],
      ),
    ];
  }

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
    waterMl = 0;

    if (fbUser == null) {
      user = null;
    } else {
      // Perfil provisional hasta que llegue el documento de Firestore.
      user = _defaultProfile(fbUser);
      _listenUserData(fbUser.uid);
    }
    loading = false;
    notifyListeners();
  }

  void _listenUserData(String uid) {
    final userDoc = _userDoc(uid);
    _dataSubs.addAll([
      userDoc.snapshots().listen((snap) {
        final data = snap.data();
        if (data == null) return;
        user = UserProfile.fromMap(data);
        // El rol puede cambiar en cualquier momento (lo cambia un admin).
        _updateTrainerSub(uid);
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

  /// Escucha las rutinas asignadas por mí solo mientras sea entrenador.
  void _updateTrainerSub(String uid) {
    if (!isTrainer) {
      _trainerSub?.cancel();
      _trainerSub = null;
      assignedByMe.clear();
      return;
    }
    _trainerSub ??= _db
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
        }, onError: _onError);
  }

  void _cancelDataSubs() {
    for (final sub in _dataSubs) {
      sub.cancel();
    }
    _dataSubs.clear();
    _trainerSub?.cancel();
    _trainerSub = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDataSubs();
    super.dispose();
  }

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    if (!_validEmail(email)) return 'Introduce un correo válido.';
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (name.trim().isEmpty) return 'El nombre no puede estar vacío.';
    if (!_validEmail(email)) return 'Introduce un correo válido.';
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user!;
      await fbUser.updateDisplayName(name.trim());
      final profile = UserProfile(
        name: name.trim(),
        username: _usernameFrom(name),
        email: email.trim(),
      );
      await _userDoc(fbUser.uid).set(profile.toMap());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } on FirebaseException catch (e) {
      return 'No se pudo guardar el perfil: ${e.message ?? e.code}';
    }
  }

  /// Entra (o crea la cuenta) con Google. Devuelve null si va bien o si el
  /// usuario cierra el selector de cuentas.
  Future<String?> signInWithGoogle() async {
    try {
      // En Android el ID de cliente sale de google-services.json.
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize();
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return 'Google no devolvió credenciales.';

      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      if (cred.additionalUserInfo?.isNewUser ?? false) {
        final name = account.displayName ?? account.email.split('@').first;
        final profile = UserProfile(
          name: name,
          username: _usernameFrom(name),
          email: account.email,
        );
        await _userDoc(cred.user!.uid).set(profile.toMap());
      }
      return null;
    } on GoogleSignInException catch (e) {
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return null;
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          return 'Google no está configurado: actívalo en Firebase y vuelve '
              'a descargar google-services.json.';
        default:
          return 'No se pudo entrar con Google: '
              '${e.description ?? e.code.name}';
      }
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } on FirebaseException catch (e) {
      return 'No se pudo guardar el perfil: ${e.message ?? e.code}';
    }
  }

  Future<String?> resetPassword(String email) async {
    if (!_validEmail(email)) return 'Escribe tu correo para recuperarla.';
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  Future<void> logout() async {
    // Para que la próxima vez vuelva a salir el selector de cuentas.
    if (_googleReady) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  void updateProfile(UserProfile next) {
    user = next;
    notifyListeners();
    // merge: para no borrar el campo `role`, que no va en toMap().
    _save(_userDoc(_uid).set(next.toMap(), SetOptions(merge: true)));
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

  void assignRoutine(AppUser to, Routine routine) {
    final doc = _db.collection('assignedRoutines').doc();
    final assigned = AssignedRoutine(
      id: doc.id,
      routine: routine,
      trainerId: _uid,
      trainerName: user?.name ?? 'Entrenador',
      userId: to.uid,
      userName: to.profile.name,
      createdAt: DateTime.now(),
    );
    _save(doc.set(assigned.toMap()));
  }

  void deleteAssignedRoutine(String id) {
    assignedByMe.removeWhere((r) => r.id == id);
    notifyListeners();
    _save(_db.collection('assignedRoutines').doc(id).delete());
  }

  void addNutrition(NutritionEntry entry) {
    _save(
      _userDoc(_uid).collection('nutrition').doc(entry.id).set(entry.toMap()),
    );
  }

  void removeNutrition(String id) {
    _save(_userDoc(_uid).collection('nutrition').doc(id).delete());
  }

  DailyMacros macrosFor(DateTime day) {
    final ofDay = nutritionLogs.where((e) => _sameDay(e.date, day));
    return DailyMacros(
      kcal: ofDay.fold(0, (s, e) => s + e.kcal),
      protein: ofDay.fold(0, (s, e) => s + e.protein),
      carbs: ofDay.fold(0, (s, e) => s + e.carbs),
      fat: ofDay.fold(0, (s, e) => s + e.fat),
    );
  }

  List<NutritionEntry> nutritionFor(DateTime day) {
    return nutritionLogs.where((e) => _sameDay(e.date, day)).toList();
  }

  /// Objetivo diario orientativo según peso y objetivo del perfil:
  /// mantenimiento ≈ 33 kcal/kg, ajustado por objetivo; proteína y grasa
  /// por kg de peso y el resto de calorías en hidratos.
  DailyMacros macroTargets() {
    final weight = user?.weightKg ?? 75;
    final goal = user?.goal ?? 'Salud general';
    final factor = switch (goal) {
      'Pérdida de grasa' => 0.85,
      'Hipertrofia' => 1.10,
      'Fuerza' => 1.05,
      _ => 1.0,
    };
    final kcal = weight * 33 * factor;
    final protein = weight * (goal == 'Salud general' ? 1.6 : 2.0);
    final fat = weight * 0.9;
    final carbs = ((kcal - protein * 4 - fat * 9) / 4).clamp(
      0,
      double.infinity,
    );
    return DailyMacros(
      kcal: kcal,
      protein: protein,
      carbs: carbs.toDouble(),
      fat: fat,
    );
  }

  DateTime get _monday {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday - 1));
  }

  Iterable<Workout> get _thisWeek =>
      workouts.where((w) => !w.date.isBefore(_monday));

  /// Entrenamientos desde el lunes de esta semana.
  int workoutsThisWeek() => _thisWeek.length;

  /// Volumen (reps × kg) acumulado esta semana.
  double volumeThisWeek() => _thisWeek.fold(0, (s, w) => s + w.volumeKg);

  bool trainedOn(DateTime day) => workouts.any((w) => _sameDay(w.date, day));

  /// Días seguidos entrenando, contando hasta hoy (o hasta ayer si hoy
  /// todavía no has entrenado).
  int streakDays() {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!trainedOn(day)) day = day.subtract(const Duration(days: 1));
    var streak = 0;
    while (trainedOn(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Mayor número de días seguidos entrenando de todo el historial.
  int bestStreak() {
    final days = {
      for (final w in workouts) DateTime(w.date.year, w.date.month, w.date.day),
    }.toList()..sort();
    var best = 0;
    var current = 0;
    DateTime? prev;
    for (final d in days) {
      // Se compara por fecha de calendario para no fallar con el cambio de hora.
      final next = prev == null
          ? null
          : DateTime(prev.year, prev.month, prev.day + 1);
      current = next != null && DateUtils.isSameDay(d, next) ? current + 1 : 1;
      if (current > best) best = current;
      prev = d;
    }
    return best;
  }

  double totalVolume() => workouts.fold(0, (s, w) => s + w.volumeKg);

  int totalMinutes() => workouts.fold(0, (s, w) => s + w.durationMin);

  int totalSets() => workouts.fold(
    0,
    (s, w) => s + w.exercises.fold(0, (t, e) => t + e.sets.length),
  );

  /// Ejercicio que más veces aparece en tus entrenos.
  String? favoriteExercise() {
    final counts = <String, int>{};
    for (final w in workouts) {
      for (final e in w.exercises) {
        counts[e.exercise.name] = (counts[e.exercise.name] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Días distintos con alguna comida registrada.
  int nutritionDaysLogged() => {
    for (final n in nutritionLogs)
      DateTime(n.date.year, n.date.month, n.date.day),
  }.length;

  /// Entrenos de cada una de las últimas [weeks] semanas (la última es la
  /// actual).
  List<int> workoutsPerWeek({int weeks = 8}) {
    final counts = List.filled(weeks, 0);
    for (final w in workouts) {
      final diff = _monday.difference(
        DateTime(w.date.year, w.date.month, w.date.day - (w.date.weekday - 1)),
      );
      final weeksAgo = (diff.inHours / (24 * 7)).round();
      if (weeksAgo >= 0 && weeksAgo < weeks) counts[weeks - 1 - weeksAgo]++;
    }
    return counts;
  }

  /// La rutina del último entreno que salió de una rutina.
  Routine? activeRoutine() {
    final all = [...routines, for (final a in assignedToMe) a.routine];
    for (final w in workouts) {
      if (w.routineId == null) continue;
      for (final r in all) {
        if (r.id == w.routineId) return r;
      }
    }
    return null;
  }

  int sessionsThisWeek(String routineId) =>
      _thisWeek.where((w) => w.routineId == routineId).length;

  /// Objetivo de agua orientativo: 35 ml por kg, redondeado a 100 ml.
  int get waterGoalMl {
    final ml = (user?.weightKg ?? 75) * 35;
    return (ml / 100).round() * 100;
  }

  void addWater(int ml) {
    waterMl = (waterMl + ml).clamp(0, 20000);
    notifyListeners();
    _save(
      _waterDoc(
        _uid,
        DateTime.now(),
      ).set({'ml': waterMl, 'date': Timestamp.now()}),
    );
  }

  DocumentReference<Map<String, dynamic>> _waterDoc(String uid, DateTime day) {
    final key =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-'
        '${day.day.toString().padLeft(2, '0')}';
    return _userDoc(uid).collection('water').doc(key);
  }

  Routine recommendedRoutine() {
    final days = user?.daysPerWeek ?? 4;
    if (days <= 3) return _templates.firstWhere((r) => r.id == 'tpl-full');
    if (days <= 4) return _templates.firstWhere((r) => r.id == 'tpl-ul');
    return _templates.firstWhere((r) => r.id == 'tpl-ppl');
  }

  String get _uid => _auth.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
  }

  UserProfile _defaultProfile(User fbUser) {
    final email = fbUser.email ?? '';
    final name = fbUser.displayName ?? email.split('@').first;
    return UserProfile(name: name, username: _usernameFrom(name), email: email);
  }

  String _usernameFrom(String name) {
    return name.trim().toLowerCase().replaceAll(' ', '');
  }

  void _save(Future<void> write) {
    unawaited(write.catchError(_onError));
  }

  void _onError(Object error) {
    debugPrint('Firestore: $error');
  }

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'Esta cuenta está desactivada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con ese correo.';
      case 'weak-password':
        return 'La contraseña es demasiado débil.';
      case 'too-many-requests':
        return 'Demasiados intentos. Prueba de nuevo más tarde.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'operation-not-allowed':
        return 'El acceso con correo no está activado en Firebase.';
      default:
        return e.message ?? 'Error de autenticación (${e.code}).';
    }
  }

  bool _validEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email.trim());
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
