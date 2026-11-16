# LiFTeR+ — Instrucciones para Claude

## Qué es este proyecto

LiFTeR+ es el proyecto final (TFG) del ciclo de **Desarrollo de Aplicaciones Multiplataforma (DAM)** de dos alumnos, Joel y Mario. Es una app de gimnasio para **Android y web**: registro de entrenamientos, rutinas, nutrición, logros y tres roles (usuario, entrenador y administrador).

Los dos venimos de Java y estamos aprendiendo Flutter y Dart. En el tribunal tendremos que **explicar cualquier línea del código**, así que la prioridad es que el código sea **claro y fácil de entender**, no ingenioso.

## Tecnologías

- Flutter y Dart (Material 3, tema oscuro, interfaz en español).
- Firebase Authentication (correo/contraseña y Google) y Cloud Firestore.
- Paquetes: Firebase (`firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`) y `excel`, `pdf` y `file_saver` para los informes del entrenador. **No añadas paquetes nuevos sin preguntar antes.**

## Cómo se ejecuta

```bash
flutter pub get
flutter run -d chrome        # web
flutter run                  # emulador Android abierto
flutter analyze              # debe terminar sin avisos
flutter test                 # deben pasar todos los tests
```

## Estructura del código (`lib/`)

| Carpeta / archivo | Contenido |
|---|---|
| `main.dart`, `app.dart` | Arranque, tema y pantalla inicial según la sesión |
| `models/models.dart` | Clases de datos con `fromMap()` y `toMap()` para Firestore |
| `data/app_store.dart` | `AppStore` (`ChangeNotifier`): estado de la sesión, escuchas y escrituras en Firestore |
| `data/auth_service.dart` | Registro, login, Google y recuperación de contraseña |
| `data/stats.dart` | Extensión `AppStoreStats`: cálculos (rachas, macros, rutina recomendada). No lee ni escribe en Firestore |
| `data/catalog.dart` | Nombres de las colecciones del catálogo y carga inicial desde `assets/seed/catalog.json` (`CatalogSeed`) |
| `data/achievements.dart` | Insignias, calculadas al momento |
| `data/client_report.dart`, `data/report_export.dart` | Estadísticas de clientes e informes Excel/PDF del entrenador |
| `screens/<sección>/` | Una carpeta por sección: `auth`, `home`, `workouts`, `routines`, `nutrition`, `profile`, `trainer`, `admin` (incluye `catalog_screens.dart`), `shell` |
| `widgets/` | Componentes reutilizables (`brand.dart`, `help.dart`) |
| `theme/app_theme.dart` | Colores y estilos. Usa siempre el tema, nunca colores sueltos |

Datos en Firestore: `users/{uid}` (perfil) con las subcolecciones `workouts`, `routines`, `nutrition` y `water`; el catálogo común en `exercises`, `foods` y `routineTemplates` (solo lo escribe el admin); y `assignedRoutines` (rutinas que asigna un entrenador). Las reglas están en `firestore.rules`.

Roles: un único rol por usuario (`user`, `trainer` o `admin`) en el campo `role`. El admin tiene también las funciones de entrenador.

## Arquitectura: respétala

1. **Las pantallas no hablan con Firebase.** Leen el estado con `SessionScope.of(context)` y llaman a métodos del `AppStore`.
2. **Las escrituras pasan por el `AppStore`** (con su método `_save`) o por `AuthService`.
3. **Los cálculos van en `data/stats.dart`** o en el propio modelo (getters), nunca dentro de un `build()`.
4. **Cada modelo tiene `fromMap` y `toMap`.** Al leer, usa valores por defecto (`??`) para los campos que falten, porque hay documentos antiguos en Firestore.
5. **El campo `role` nunca se escribe desde la app** (las reglas lo impiden). Por eso no va en `UserProfile.toMap()`.
6. Para listas cerradas de opciones con texto visible, sigue el patrón de `UserRole`: un `enum` con `label` y un `fromName()` con valor por defecto.

## Reglas de programación (estilo DAM)

- **Nombres** de clases, variables y métodos **en inglés** y descriptivos (`weightKg`, `daysPerWeek`), como ya está el proyecto. **Textos de la interfaz y comentarios en español.**
- **Métodos y widgets pequeños**, con una sola responsabilidad. Si un `build()` pasa de unas 80 líneas, divídelo en widgets privados (`_NombreWidget`) o en otro archivo.
- **Nada de código duplicado.** Si dos pantallas usan las mismas opciones o el mismo widget, sácalos a un sitio común.
- Usa `const` siempre que se pueda y `final` en los campos que no cambian.
- **Null safety bien hecho:** evita `!` salvo que sea seguro; explica en un comentario por qué lo es.
- **Valida lo que escribe el usuario** (números positivos, rangos razonables, campos obligatorios) y muestra mensajes de error claros en español.
- **Controla los errores de Firebase** con `try/catch` (`FirebaseException`) cuando haya que avisar al usuario.
- **Comentarios:** `///` en clases y métodos públicos explicando qué hacen y por qué. Nada de comentarios obvios.
- Sigue `flutter_lints`: `flutter analyze` sin avisos.
- Si cambias un modelo o un cálculo, **añade o actualiza un test** en `test/`. Los tests que corresponden a un caso de prueba de la memoria llevan su identificador en el nombre (por ejemplo, `CP-04`). **Si un cambio altera el resultado de un test existente, avísanos** antes de modificarlo: hay que actualizar también la memoria.
- Las pruebas no usan Firebase: los datos se cargan directamente en el `AppStore`.

## Forma de trabajar

- **Trabaja en pasos pequeños.** Al terminar cada paso, **para**, resume qué has cambiado y en qué archivos, y espera a que te digamos que sigas.
- **Explica cada cambio de forma sencilla**, comparándolo con Java cuando ayude. Somos alumnos y tenemos que entenderlo.
- **No toques archivos que no tengan que ver con la tarea.** Si crees que hace falta cambiar algo fuera de ella, pregúntalo antes.
- **No hagas commits, push ni cambios de rama:** el control de versiones lo hacemos nosotros.
- Si hay varias formas de hacer algo, propón la más sencilla y di brevemente por qué.
- Si una petición choca con estas reglas o no está clara, pregunta antes de programar.

## Flujo de ramas (para que lo tengas en cuenta)

`main` (versiones estables) ← `dev` (se junta y prueba el trabajo de los dos) ← `joel` / `mario` (ramas personales). Se trabaja siempre en la rama personal y se sube a `dev` con Pull Request.
