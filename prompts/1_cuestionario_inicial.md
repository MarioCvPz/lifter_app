Vamos a implementar el **cuestionario inicial** de LiFTeR+. Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue".

## Qué queremos

Después del primer inicio de sesión (con correo o con Google), el usuario ve un cuestionario de varios pasos, uno por pantalla, con barra de progreso y botones "Atrás" y "Siguiente". **No puede entrar en la app hasta completarlo.** Al terminar ve una pantalla **"Tu plan"** con lo que la app ha calculado para él. Al pulsar "Empezar", se guardan los datos en su perfil (`users/{uid}`) y pasa a la pantalla principal. Los usuarios que ya lo han completado no lo vuelven a ver.

### Preguntas, en este orden

1. **Datos personales:** nombre y apellidos. El nombre viene rellenado si existe (por ejemplo, el de Google). El correo **no se pide**.
2. **Objetivo:** ganar masa muscular, perder grasa, recomposición corporal, ganar fuerza o salud general.
3. **Datos físicos:** sexo (**solo Hombre o Mujer**: se usa en la fórmula de calorías), fecha de nacimiento (con selector de fecha; se muestra la edad calculada), altura (cm) y peso (kg).
4. **Actividad diaria** (sin contar el gimnasio): sedentario, ligeramente activo, activo o muy activo, cada uno con una frase de ejemplo debajo (por ejemplo, "Trabajo sentado y me muevo poco").
5. **Experiencia:** principiante (menos de 6 meses), intermedio (de 6 meses a 2 años) o avanzado (más de 2 años). Usa `Routine.levels`.
6. **Disponibilidad:**
   - **Qué días de la semana puede entrenar:** siete botones L M X J V S D, con selección múltiple, mínimo 2 y máximo 6. Debajo se muestra "Entrenarás X días por semana".
   - **Tiempo por sesión:** 45, 60 o 90 minutos (la última opción con el texto "90 min o más").
7. **Dónde entrenas y con qué material:**
   - Primero el **lugar**: gimnasio, casa o al aire libre. Cada lugar **marca automáticamente** el material típico:
     - Gimnasio: todo.
     - Casa: mancuernas, bandas elásticas y peso corporal.
     - Al aire libre: peso corporal y bandas elásticas.
   - Debajo, las opciones de `EditProfileScreen.equipmentOptions` (**añade una nueva: "Barra de dominadas"**) para que el usuario **ajuste** lo marcado. Al menos una.
8. **Lesiones o zonas a evitar (opcional):** hombro, codo, muñeca, cuello, espalda baja, cadera, rodilla y tobillo, con selección múltiple, o "Ninguna".

### Pantalla final "Tu plan"

Una pantalla **sencilla**, con tarjetas y el estilo de la app, sin gráficas, que muestra:
- La rutina recomendada (hoy, la de `recommendedRoutine()` de `stats.dart`).
- Los días de entrenamiento y la duración de cada sesión.
- Las calorías y la proteína diarias (`macroTargets()`) y el objetivo de agua (`waterGoalMl`).
- Un botón **"Empezar"**, que guarda y entra en la app, y otro **"Cambiar respuestas"**, que vuelve al primer paso.

Esos cálculos leen hoy el perfil del `AppStore` (`user`). Piensa la forma más sencilla de mostrarlos **con las respuestas del cuestionario antes de guardarlas**; por ejemplo, que las funciones puedan recibir un `UserProfile`. Explícame la opción que elijas.

### Validaciones

- Nombre obligatorio.
- Edad entre 14 y 90 años.
- Altura entre 120 y 230 cm.
- Peso entre 30 y 250 kg.
- De 2 a 6 días.
- Al menos un material.

No se pasa de paso si hay un error, y el mensaje se muestra en español.

## Lo que hay en el código y debes tener en cuenta

- `UserProfile` (`models/models.dart`) tiene **valores por defecto** (178 cm, 78 kg, intermedio, 'Hipertrofia', 4 días…), así que hoy no se puede saber si el usuario ha rellenado algo: hace falta un campo nuevo.
- `AppStore._onAuthChanged` pone un **perfil provisional** (`AuthService.defaultProfile`) antes de que llegue el documento de Firestore. Hay que esperar al perfil real para decidir si se muestra el cuestionario; si no, aparecería un instante a quien ya lo completó.
- `app.dart` decide la pantalla inicial con `_store.loading` e `isLoggedIn`.
- `goal` es un texto con los valores `'Hipertrofia'`, `'Fuerza'`, `'Pérdida de grasa'` y `'Salud general'`. Se usa en:
  - `stats.dart` (`macroTargets`);
  - `edit_profile_screen.dart`;
  - `profile_screen.dart`;
  - `trainer_screen.dart`;
  - `report_export.dart`.

  En Firestore ya hay perfiles con esos textos.
- `EditProfileScreen.sexes` incluye `'Otro'`: **quítalo**. Los perfiles con `'Otro'` se leerán como `'Hombre'`.
- `daysPerWeek` lo usan la recomendación y las estadísticas del entrenador (cumplimiento). **Mantenlo**: al guardar, es el número de días elegidos.
- Las reglas de Firestore ya dejan al usuario editar su perfil salvo `role`: **no hay que tocar `firestore.rules`**.

## Pasos

**Paso 1. Modelo.**
- Añade a `UserProfile`:
  - `surname` (String);
  - `birthDate` (DateTime?);
  - `activityLevel`;
  - `trainingDays` (List<int>, 1 = lunes … 7 = domingo);
  - `sessionMinutes` (int, por defecto 60);
  - `trainingPlace`;
  - `injuries` (List<String>);
  - `onboardingCompleted` (bool, por defecto false).
- Añade un getter `age`.
- Crea tres `enum` siguiendo el patrón de `UserRole`:
  - `ActivityLevel` (`label` y descripción corta);
  - `TrainingGoal` (`label`);
  - `TrainingPlace` (`label` y material por defecto).
- `TrainingGoal.fromName()` acepta también los textos antiguos: `'Hipertrofia'` → ganar masa muscular, `'Pérdida de grasa'` → perder grasa, `'Fuerza'` → ganar fuerza y `'Salud general'` → salud general.
- En Firestore se guarda el `name` de cada enum y la fecha como `Timestamp`. Actualiza `fromMap` y `toMap`.
- Las listas de opciones (lesiones, minutos, material, días) van en un único sitio, sin duplicar.

**Paso 2. Que el resto de la app siga funcionando.**
- Adapta al enum `TrainingGoal` todos los usos de `goal` de la lista de arriba (para mostrarlo, usa `label`).
- **No cambies todavía cómo se calculan las macros.**
- Ejecuta `flutter analyze` y `flutter test`: el test **CP-04** debe seguir pasando igual.

**Paso 3. Saber cuándo ha llegado el perfil real.**
- Añade al `AppStore` un indicador de que ya llegó el perfil de Firestore.
- Añade el método `completeOnboarding(UserProfile profile)`, que guarda con `onboardingCompleted = true` y `daysPerWeek = trainingDays.length`, igual que `updateProfile`.

**Paso 4. Navegación** en `app.dart`:
- sin sesión → login;
- con sesión y perfil sin cargar → indicador de carga;
- `onboardingCompleted == false` → cuestionario;
- si no → `MainShell`.

**Paso 5. Pantalla del cuestionario.**
- Crea `screens/onboarding/onboarding_screen.dart` con los pasos, la barra de progreso y los botones.
- Cada pregunta va en su propio widget, en `screens/onboarding/steps/`, uno por archivo.
- Usa `AppTheme` y, si encajan, los widgets de `widgets/brand.dart`.
- Hazlas de una en una, parando cada dos o tres.

**Paso 6. "Tu plan" y guardado.**
- "Empezar" llama a `completeOnboarding`.
- Muestra un indicador mientras guarda y un mensaje si falla.

**Paso 7. Editar perfil.**
- Añade a `EditProfileScreen` los campos nuevos.
- Cambia el selector de número de días por los botones de días de la semana.
- **Reutiliza los widgets del cuestionario**, sin copiar código.

**Paso 8. Tests** en `test/onboarding_test.dart`. Nombra los tests con los casos de la memoria:
- **CP-11:** `UserProfile.fromMap`/`toMap` con los campos nuevos.
- **CP-11:** un perfil antiguo sin esos campos se lee sin fallar y con `onboardingCompleted = false`.
- **CP-11:** `TrainingGoal.fromName` con los textos antiguos.
- **CP-11:** el cálculo de `age` y el material por defecto de cada `TrainingPlace`.
- **CP-11 (widget):** con un perfil sin completar se muestra el cuestionario, y no se puede pasar del paso 1 sin nombre.

Ejecuta `flutter analyze` y `flutter test` (todos deben pasar).

**Resumen final:**
- archivos creados y modificados;
- cómo probarlo a mano: crear una cuenta nueva, completar el cuestionario, revisar "Tu plan", cerrar sesión y volver a entrar para comprobar que no vuelve a salir;
- resultados de los tests para anotarlos en la memoria.
