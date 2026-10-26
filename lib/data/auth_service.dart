import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../models/models.dart';

/// Entrar, registrarse y salir con Firebase Auth. Al crear una cuenta guarda
/// también su perfil en `users/{uid}`.
///
/// Los métodos devuelven null si todo va bien o un mensaje de error para
/// mostrar al usuario.
class AuthService {
  bool _googleReady = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

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
      final UserCredential cred;
      if (kIsWeb) {
        // En web, google_sign_in no permite authenticate(): se usa la
        // ventana emergente de Firebase.
        cred = await _auth.signInWithPopup(GoogleAuthProvider());
      } else {
        // En Android el ID de cliente sale de google-services.json.
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize();
          _googleReady = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null) return 'Google no devolvió credenciales.';
        cred = await _auth.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      if (cred.additionalUserInfo?.isNewUser ?? false) {
        final fbUser = cred.user!;
        await _userDoc(fbUser.uid).set(defaultProfile(fbUser).toMap());
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
      // Cerrar la ventana emergente en web no es un error.
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        return null;
      }
      if (e.code == 'popup-blocked') {
        return 'El navegador ha bloqueado la ventana de Google. Permite las '
            'ventanas emergentes para esta página.';
      }
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

  /// Perfil a partir de los datos de la cuenta de Firebase (nombre de
  /// Google o la parte del correo antes de la @).
  static UserProfile defaultProfile(User fbUser) {
    final email = fbUser.email ?? '';
    final name = fbUser.displayName ?? email.split('@').first;
    return UserProfile(name: name, username: _usernameFrom(name), email: email);
  }

  static String _usernameFrom(String name) {
    return name.trim().toLowerCase().replaceAll(' ', '');
  }

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _db.collection('users').doc(uid);
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
}
