import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Configuración de Firebase por plataforma (proyecto lifter-63e9e).
///
/// En Android no hace falta: se lee de android/app/google-services.json.
/// En web se usan los datos de la app web registrada en la consola de
/// Firebase (no son secretos; acaban dentro de la propia web).
class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatform => kIsWeb ? web : null;

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDMrknNNJn8I1Fs8oaDu29DYj-HWcquxDE',
    authDomain: 'lifter-63e9e.firebaseapp.com',
    projectId: 'lifter-63e9e',
    storageBucket: 'lifter-63e9e.firebasestorage.app',
    messagingSenderId: '606937997717',
    appId: '1:606937997717:web:8c4a247acff7889815569c',
  );
}
