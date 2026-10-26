import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'auth_service.dart';
import 'catalog.dart';

/// Estado de la app. La sesión va con Firebase Auth y los datos de cada
/// usuario se guardan en Firestore bajo `users/{uid}`:
///   - `users/{uid}`             → perfil
///   - `users/{uid}/workouts`    → entrenamientos
///   - `users/{uid}/routines`    → rutinas propias
///   - `users/{uid}/nutrition`   → registros de comidas
/// El catálogo de ejercicios, alimentos y plantillas está en catalog.dart y
/// los datos calculados (rachas, macros…) en stats.dart.
class AppStore extends ChangeNotifier {
  /// Entrar, registrarse y salir.
  final AuthService auth = AuthService();

  /// True mientras se comprueba si hay una sesión guardada.
  bool loading = false;
  UserProfile? user;
  bool get isLoggedIn => user != null;

  final List<Routine> _myRoutines = [];
  final List<Workout> workouts = [];
  final List<NutritionEntry> nutritionLogs = [];

  List<Routine> get routines => [...routineTemplates, ..._myRoutines];

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
    waterMl = 0;

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

  String get _uid => _auth.currentUser!.uid;

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
