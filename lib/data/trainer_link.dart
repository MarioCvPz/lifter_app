import 'dart:math';

import '../models/models.dart';

/// Códigos de entrenador: 6 caracteres en mayúsculas, sin los que se
/// confunden al dictarlos o copiarlos (O, 0, I, 1). Solo calcula: no lee
/// ni escribe en Firestore.
class TrainerCode {
  TrainerCode._();

  static const length = 6;

  /// 32 símbolos: letras sin I ni O y números sin 0 ni 1. Con 6 caracteres
  /// salen unos mil millones de códigos distintos.
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Código nuevo al azar. Se puede pasar un [random] fijo en los tests.
  static String generate([Random? random]) {
    final rnd = random ?? Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < length; i++)
        alphabet.codeUnitAt(rnd.nextInt(alphabet.length)),
    ]);
  }

  /// Lo que escribe el usuario, sin espacios y en mayúsculas ("ab c2de"
  /// → "ABC2DE").
  static String normalize(String text) =>
      text.replaceAll(RegExp(r'\s'), '').toUpperCase();

  /// True si [code] (ya normalizado) tiene el formato de un código.
  static bool isValidFormat(String code) =>
      code.length == length && code.split('').every(alphabet.contains);
}

/// Lo que ve el cliente en "Mi entrenador".
enum MyTrainerState { none, pending, linked }

/// Reglas del vínculo cliente–entrenador que no dependen de Firebase.
/// Las usan el [AppStore] y los tests.
class TrainerLinkRules {
  TrainerLinkRules._();

  static const codeNotFound =
      'Ese código no existe. Pídeselo de nuevo a tu entrenador.';
  static const badFormat =
      'El código tiene 6 caracteres (letras y números). Revísalo.';
  static const alreadyHasTrainer =
      'Ya tienes un entrenador o una solicitud enviada. Cancélala o '
      'desvincúlate antes de enviar otra.';
  static const ownCode = 'Ese es tu propio código.';

  /// Estado del cliente según su vínculo (null = sin entrenador).
  static MyTrainerState stateOf(TrainerLink? link) {
    if (link == null) return MyTrainerState.none;
    return link.isAccepted ? MyTrainerState.linked : MyTrainerState.pending;
  }

  /// Error al enviar una solicitud con [code], o null si se puede. Solo
  /// revisa lo que se sabe sin Firestore; que el código exista se comprueba
  /// después.
  static String? validateRequest({
    required String code,
    required TrainerLink? current,
  }) {
    if (current != null) return alreadyHasTrainer;
    if (!TrainerCode.isValidFormat(code)) return badFormat;
    return null;
  }

  /// Solicitud nueva (pendiente) del cliente al entrenador del código.
  static TrainerLink newRequest({
    required String clientId,
    required String clientName,
    required String trainerId,
    required String trainerName,
    required String code,
    DateTime? now,
  }) => TrainerLink(
    clientId: clientId,
    clientName: clientName,
    trainerId: trainerId,
    trainerName: trainerName,
    code: code,
    status: LinkStatus.pending,
    createdAt: now ?? DateTime.now(),
  );
}
