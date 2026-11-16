Vamos a programar el **generador de rutinas** de LiFTeR+: a partir del perfil del cuestionario inicial, la app crea un **plan semanal** con los ejercicios de cada día. Sustituye a la recomendación actual, que solo tiene en cuenta los días (`recommendedRoutine()` en `stats.dart`). Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue".

Este prompt va **después** de los prompts 1 (cuestionario), 2 (calorías) y 3 (catálogo). Antes de empezar, revisa:
- `UserProfile`: `trainingDays`, `sessionMinutes`, `goal`, `experience`, `equipment` e `injuries`;
- `Exercise`: `pattern`, `equipment`, `level`, tipo y `stressedZones`;
- `AppStore.exercises`, `Routine` y `recommendedRoutine()`;
- `screens/home/home_screen.dart`: cómo elige hoy el entrenamiento del día (rutina asignada por el entrenador, rutina activa o plantilla recomendada) y la tarjeta del agua (`_WaterCard`);
- `screens/profile/`: Perfil y Editar perfil.

## Reglas (ya decididas, no las cambies)

### 1. Estructura según el número de días elegidos

| Días | Estructura |
|---|---|
| 2 | Full body A · Full body B |
| 3 | Empuje · Pierna · Tirón. **Excepción:** principiante → Full body A · B · C |
| 4 | Empuje · Tirón · Pierna · Brazos |
| 5 | Empuje · Tirón · Pierna · Torso · Pierna B |
| 6 | Empuje · Tirón · Pierna · Empuje · Tirón · Pierna B |

### 2. Huecos de cada día

Cada tipo de día tiene una lista de **patrones por orden de prioridad**. Se usan los **N primeros** según los minutos de la sesión: **45 → 5**, **60 → 6**, **90 → 8**. Si algún perfil antiguo tuviera 30 minutos, trátalo como 45.

| Día | Patrones, por orden |
|---|---|
| Full body A | sentadilla, empuje_horizontal, tiron_vertical, bisagra, hombro_lateral, core, biceps, triceps |
| Full body B | bisagra, empuje_vertical, tiron_horizontal, unilateral, pecho_aislamiento, core, triceps, biceps |
| Full body C | sentadilla, tiron_horizontal, empuje_horizontal, gluteo, hombro_posterior, core, femoral_aislamiento, biceps |
| Empuje | empuje_horizontal, empuje_horizontal, empuje_vertical, pecho_aislamiento, hombro_lateral, triceps, triceps, core |
| Tirón | tiron_vertical, tiron_horizontal, tiron_horizontal, tiron_vertical, hombro_posterior, biceps, biceps, core |
| Pierna | sentadilla, bisagra, unilateral, cuadriceps_aislamiento, femoral_aislamiento, gemelo, core, gluteo |
| Pierna B | bisagra, sentadilla, gluteo, femoral_aislamiento, unilateral, gemelo, core, cuadriceps_aislamiento |
| Torso | empuje_horizontal, tiron_horizontal, empuje_vertical, tiron_vertical, hombro_lateral, biceps, triceps, pecho_aislamiento |
| Brazos | biceps, triceps, biceps, triceps, hombro_lateral, hombro_posterior, biceps, core |

### 3. Cómo se rellena cada hueco

Para cada hueco se busca en el catálogo un ejercicio de ese patrón que cumpla **todo** esto:

1. El usuario tiene su material (`equipment` está en el material del perfil).
2. Su nivel no es superior al del usuario: principiante → solo principiante; intermedio → principiante o intermedio; avanzado → todos.
3. No carga ninguna zona lesionada (`stressedZones` sin elementos en común con `injuries`).
4. No está repetido en el mismo día.

Más reglas:
- Si el mismo tipo de día aparece dos veces en la semana, se intenta no repetir ejercicios entre ellos.
- **Preferencia:** en los primeros huecos, multiarticulares; después, el orden del catálogo.
- Si un día tiene dos huecos seguidos del mismo patrón de empuje horizontal, intenta que uno sea **plano** y el otro **inclinado** (mira el nombre del ejercicio: si contiene "inclinado"). Si no es posible, cualquiera.
- **Sin aleatoriedad:** con el mismo perfil, siempre el mismo plan.
- **Si no hay candidato:** se repite la búsqueda ignorando solo el nivel. Si sigue sin haber, el hueco se salta. **Nunca se ignoran el material ni las lesiones.**
- Dentro de cada día, los multiarticulares van antes que los de aislamiento.

### 4. Series, repeticiones y descanso

| Objetivo | Repeticiones | Descanso |
|---|---|---|
| Ganar fuerza | 4–6 en multiarticulares (8–12 en aislamiento) | 150 s |
| Ganar masa muscular o recomposición | 8–12 | 90 s |
| Perder grasa o salud general | 10–15 | 60 s |

**Series:** 3 para principiante; 4 en multiarticulares y 3 en aislamiento para intermedio y avanzado.

### 5. Días de la semana

Los días de la estructura se asignan, en orden, a los `trainingDays` del usuario ordenados de lunes a domingo. Por ejemplo, con L-X-V y Empuje · Pierna · Tirón: lunes Empuje, miércoles Pierna y viernes Tirón.

## Pasos

**Paso 1. Modelo del plan.**
- Propón las clases, por ejemplo:
  - `TrainingPlan` (estructura, fecha de generación y días);
  - `PlanDay` (día de la semana, nombre, ejercicios y la lista de ids de ejercicios que **el usuario ha quitado**);
  - `PlanExercise` (ejercicio, series, repeticiones mínimas y máximas, descanso y un `bool isCustom` que indica que **lo ha añadido o sustituido el usuario**).
- Cada clase con `fromMap` y `toMap`.
- Guárdalo en `users/{uid}/plan/current`. Las reglas actuales ya permiten al usuario leer y escribir sus subcolecciones; compruébalo.
- Explícamelo antes de programarlo.

**Paso 2. El generador.**
- Crea la clase `RoutineGenerator` en `lib/data/`. Recibe un `UserProfile` y la lista de `Exercise`, y devuelve un `TrainingPlan`.
- **Dart puro**, sin Firebase ni Flutter.
- Métodos pequeños, uno por regla: estructura, huecos, elegir ejercicio, series y repeticiones, y días de la semana.
- Las tablas de arriba van en **constantes**.

**Paso 3. Actualizar el plan sin perder los cambios del usuario.** Añade al generador un método que reciba el plan actual y el perfil nuevo, y devuelva el plan nuevo **respetando los cambios del usuario**:
- Genera el plan base con el perfil nuevo.
- En cada día nuevo, aplica los cambios que el usuario hizo en el día del mismo tipo (por ejemplo, Empuje → Empuje): quita los ejercicios que había quitado y vuelve a poner los que había añadido o sustituido (`isCustom`).
- **Excepción 1:** si un ejercicio del usuario ya no se puede hacer (no tiene el material o carga una zona lesionada), se sustituye por otro del mismo patrón que sí se pueda, y se devuelve un aviso con el cambio.
- **Excepción 2:** si su tipo de día desaparece (por ejemplo, pasa de 4 a 3 días y ya no hay día de Brazos), el ejercicio se mueve al día cuya lista de patrones contenga su patrón (si hay varios, el primero de la semana), y se devuelve un aviso.
- El método devuelve el plan y la lista de avisos en español, para mostrarlos al usuario.

**Paso 4. Tests** en `test/routine_generator_test.dart`, nombrados **CP-14**. Comprueba:
- la estructura para 2 a 6 días y la excepción del principiante con 3 días;
- el número de ejercicios según los minutos;
- que un usuario **solo con peso corporal** recibe solo ejercicios de peso corporal;
- que un usuario con **lesión de rodilla** no recibe ningún ejercicio que cargue la rodilla;
- que un **principiante** no recibe ejercicios avanzados si hay alternativas;
- que no hay ejercicios repetidos en un mismo día;
- que con el mismo perfil se obtiene el mismo plan;
- las series y repeticiones según el objetivo y el nivel;
- que al cambiar los días se **mantienen** los ejercicios añadidos por el usuario y no vuelven los que había quitado;
- las dos excepciones del paso 3 (material o lesión nuevos, y día que desaparece), con su aviso.

Usa como catálogo de prueba el de `assets/seed/catalog.json`, cargado con `CatalogSeed.fromJson`.

**Paso 5. Guardar y escuchar el plan** (`AppStore`).
- Generar y guardar el plan al terminar el cuestionario (`completeOnboarding`).
- Escuchar el plan guardado.
- Métodos para **cambiar, quitar y añadir** un ejercicio de un día (marcando `isCustom` o guardando el id quitado). Solo se usarán desde la pantalla de entrenamiento (prompt 5); también se usará ahí la lista de "Sugeridos para este día" (los ejercicios de los huecos que quedaron fuera por los minutos, filtrados por material, nivel y lesiones), así que déjala preparada en `data/`.
- Un único método para guardar los cambios de **días, minutos, material, lesiones, objetivo o experiencia**: guarda el perfil y actualiza el plan con el método del paso 3. Lo usarán "Editar perfil" y los ajustes del paso 8.
- **No hay botón "Regenerar plan"** en ningún sitio.
- La pantalla "Tu plan" del cuestionario debe mostrar el plan generado en lugar de `recommendedRoutine()`.

**Paso 6. Nueva pantalla de Inicio.** Rediséñala así, de arriba abajo, con `AppTheme` y sin saturarla:
1. **Saludo** como ahora.
   - En la barra de navegación de abajo, el botón seleccionado muestra **solo el icono**, sin texto.
2. **Semana L–D**: siete botones con el número del día. Los días de entreno llevan un punto; hoy, un borde de color `coral`; el día seleccionado, relleno de `coral`. Por defecto está seleccionado **hoy**, y al tocar otro día se ve su entreno abajo.
3. **Franja de hoy** con dos columnas compactas e **iguales**: **calorías** (consumidas hoy / objetivo, con barra) y **agua** (litros bebidos hoy / objetivo, con barra y botones **−** y **+**). Las dos columnas tienen la misma estructura (título con icono, cifra, barra) y la misma altura, para que **las dos barras queden alineadas**. Al tocar las calorías se va a Nutrición. Reutiliza la lógica que ya existe en `_WaterCard` (`addWater`, vaso de 250 ml, "Deshacer"):
   - el botón **−** se desactiva en 0, así que nunca puede salir un número negativo;
   - al llegar al objetivo, un mensaje positivo: "¡Objetivo de agua cumplido!";
   - al pasar del **doble** del objetivo, un aviso: "Estás bebiendo mucha agua, ten cuidado". Solo una vez al cruzar ese límite, no en cada vaso.
4. **"Entreno de hoy"** (o el nombre del día seleccionado, por ejemplo "Jueves"):
   - el día y el nombre del entreno, por ejemplo **"Martes · Empuje"**, **sin** minutos ni número de días del plan;
   - la lista **numerada** solo con los **nombres** de los ejercicios, **sin** series, repeticiones ni descanso. Es **solo un resumen**: sin `⋯` ni botones por ejercicio;
   - **no** se añaden, sustituyen ni quitan ejercicios desde Inicio: todo eso se hace **dentro del entrenamiento** (prompt 5);
   - el botón grande **"Empezar entrenamiento"**, que abre la pantalla de entrenamiento con los ejercicios del día y sus series, repeticiones y descanso.
   - Si el día seleccionado **no es de entreno**, esta sección **no aparece**.
5. Quita de Inicio lo que no esté en esta lista (estadísticas de la semana, reto semanal…) solo si te lo confirmo: **pregúntame antes** qué hacer con cada bloque que hay ahora.

**Prioridad del entreno de hoy:** si el usuario tiene una **rutina asignada por su entrenador** para hoy, esa va en lugar del día del plan, con una etiqueta "De tu entrenador". Revisa cómo funciona hoy la rutina activa antes de tocarlo y explícame el orden que vas a programar.

**Paso 7. Rutinas.** De momento **no toques** la pestaña Rutinas (De tu entrenador, Planes recomendados, Mis rutinas): es de mi compañero. Solo quita de ella la recomendación antigua si ya no tiene sentido, y pregúntame antes.

**Paso 8. Ajustes de entrenamiento.** En Perfil, añade una sección **"Ajustes de entrenamiento"** con tres opciones:
- **Días de entrenamiento**;
- **Material**;
- **Lesiones**.

Cada una abre **la misma pantalla del cuestionario** (reutiliza el widget del paso correspondiente, sin copiar código) con un botón "Guardar". Al guardar, se usa el método del paso 5, y si el plan devuelve avisos se muestran en un diálogo (por ejemplo, "Hemos cambiado Sentadilla búlgara por Zancadas porque ya no tienes mancuernas"). "Editar perfil" debe usar ese mismo método cuando cambien esos datos.

Ejecuta `flutter analyze` y `flutter test`.

**Resumen final:**
- archivos creados y cambiados;
- cómo probarlo a mano con dos perfiles muy distintos: un principiante en casa, 3 días, con lesión de rodilla; y un avanzado en gimnasio, 5 días. Y además: añadir un ejercicio, cambiar los días desde Ajustes y comprobar que el ejercicio sigue ahí;
- resultados de los tests para la memoria.
