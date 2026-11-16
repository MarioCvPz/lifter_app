Vamos a rehacer la **pantalla de registro de entrenamiento** de LiFTeR+ para que se use **mientras se entrena**, en directo: cronómetro, temporizador de descanso y series que se van marcando. Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue".

Este prompt va **después** del prompt 4 (generador de rutinas). Antes de empezar, revisa:
- `screens/workouts/register_workout_screen.dart`: hoy es un formulario con nombre, **duración escrita a mano** (o 5 min por ejercicio) y series con reps y kg. Se abre desde Entrenamientos, desde una rutina (`fromRoutine`) y desde el botón "Empezar entrenamiento" de Inicio (día del plan).
- Los modelos `Workout`, `WorkoutExercise`, `WorkoutSet`, `Routine` y los del plan (`PlanDay`, `PlanExercise`, con series, repeticiones y descanso).
- Cómo guarda el `AppStore` un entrenamiento y cómo se calculan las estadísticas, los logros y el resumen del entrenador a partir de `durationMin` y las series.

## Qué queremos (referencia: apps como Hevy)

### Antes de empezar: vista previa del entreno
- En la pestaña **Entrenos**, arriba, una tarjeta como la de Inicio con **el entreno de hoy** (día, nombre y número de ejercicios). Si hoy no toca, la del **próximo** día de entreno ("Jueves · Tirón").
- Al **pulsar esa tarjeta** (y también la tarjeta del entreno en Inicio) se abre una **vista previa**: el nombre del entreno y la lista de ejercicios con sus **series, repeticiones y descanso** (por ejemplo, "Press de banca · 4 × 8–12 · 1:30"), y abajo un botón grande **"Comenzar entrenamiento"**, que abre la pantalla en directo.
- El botón "Empezar entrenamiento" de Inicio sigue abriendo directamente la pantalla en directo.
- La vista previa es solo para ver: los cambios de ejercicios se hacen dentro del entrenamiento.
- Lo que ya hay hoy en la pestaña Entrenos (historial, etc.) se queda debajo, sin cambios.

### Cabecera
- A la izquierda, un **cronómetro** con el tiempo total del entrenamiento (`mm:ss`, o `h:mm:ss` si pasa de una hora). Empieza al abrir la pantalla y no se escribe a mano.
- En el centro, el título "Entrenamiento".
- A la derecha, un botón de **temporizador de descanso** (icono de reloj) y un menú `⋯` con "Añadir ejercicio", "Terminar entrenamiento" y "Descartar entrenamiento".
- Además, al final de la lista de ejercicios, un botón grande **"Añadir ejercicio"**. Si el entrenamiento viene del plan, arriba de la lista salen los **sugeridos para ese día** (los huecos que se quedaron fuera por los minutos), igual que en Inicio; debajo, el catálogo con buscador.
- **Lista para añadir o sustituir ejercicios (la misma en los dos casos):** ordenada y **dividida por grupo muscular**, con un título por grupo (Pecho, Espalda, Hombros, Brazos, Piernas, Core) y los ejercicios de cada grupo debajo, por orden alfabético. Arriba, el buscador y chips para saltar a un grupo. Si hay sugeridos, van en su propia sección al principio. Un solo widget reutilizable en `screens/workouts/`.
- Debajo, el nombre del entrenamiento (por ejemplo, "Empuje") y un resumen en vivo: **"X de Y series · Z kg levantados"**, contando solo las series marcadas.

### Tarjeta de cada ejercicio
- Número de orden, nombre del ejercicio y unas etiquetas pequeñas con **las series, las repeticiones objetivo y el descanso** (por ejemplo, "4 series", "8–12 reps", "Descanso 1:30"). Si viene del plan, son las del plan; si viene de una rutina o se añade a mano, valores por defecto (3 series, sin objetivo de reps y 90 s).
- Una fila por serie con su número, **peso (kg)**, **repeticiones** y un botón **✓** para marcarla como hecha. La fila marcada cambia de color.
- En los campos vacíos, como pista, el peso y las repeticiones de **la última vez** que el usuario hizo ese ejercicio, si existen.
- Debajo: **"Añadir serie"**, **"Historial"** y un botón **✓✓** para marcar todas las series del ejercicio.
- Un botón `⋯` con este menú (es **el único sitio** de la app donde se añaden, sustituyen o quitan ejercicios del plan; en Inicio solo se ve el resumen):
  - **Añadir ejercicio:** abre la lista de "Sugeridos para este día" y el catálogo con buscador (la misma que el botón "Añadir ejercicio" del final), y lo inserta **justo después** de este ejercicio.
  - **Cómo hacerlo / Historial:** una hoja con dos pestañas. "Cómo hacerlo" muestra el grupo muscular, el material, el patrón y el nivel (no hay vídeos). "Historial" muestra las últimas veces que lo hizo (fecha y series) o "Aún no hay historial".
  - **Sustituir por otro ejercicio:** lista del catálogo con buscador y chips por grupo muscular. Arriba, primero, los del **mismo patrón** que el usuario puede hacer con su material y sin cargar sus lesiones.
  - **Comentario de hoy:** un texto que se guarda con ese ejercicio en este entrenamiento (por ejemplo, "Molestia en el hombro en la última serie"). Lo podrá ver su entrenador.
  - **Cambiar el orden:** subir o bajar el ejercicio.
  - **Eliminar ejercicio**, con confirmación.

### Temporizador de descanso
- El botón de la cabecera abre una hoja con **30 s, 1:00, 1:30, 2:00, 2:30 y 3:00**. Al elegir uno, aparece una barra fija abajo con la **cuenta atrás**, "+15 s", "−15 s" y "Saltar".
- Un interruptor **"Descanso automático"** (activado por defecto): al marcar una serie, empieza solo el descanso de ese ejercicio.
- Al terminar, una vibración corta (`HapticFeedback` de Flutter, sin paquetes nuevos) y la barra desaparece.

### Terminar
- "Terminar entrenamiento" abre un resumen: **duración** (la del cronómetro, que se puede corregir por si se apuntó tarde), series hechas, volumen y ejercicios.
- Solo se guardan las **series marcadas**. Los ejercicios sin ninguna serie marcada no se guardan. Si no hay ninguna serie marcada, avisa y no guarda.
- Al guardar, `durationMin` es la del cronómetro redondeada (mínimo 1).
- Si el usuario intenta salir con el botón atrás, pregunta si quiere **descartar** el entrenamiento.
- **Si el entrenamiento salió de un día del plan** y el usuario **añadió, quitó o sustituyó** algún ejercicio, después de guardar pregunta: **"¿Quieres guardar estos cambios en tu plan para la próxima vez?"**. Con "Sí", se actualiza ese día del plan con los métodos del prompt 4 (los añadidos y sustituidos quedan marcados como `isCustom` y los quitados se apuntan como quitados), para que no se pierdan si luego cambia sus días, su material o sus lesiones. Con "Solo hoy", el plan no cambia. Si vino de una rutina propia, la misma pregunta actualiza la rutina.

### Fuera de alcance (no lo hagas ahora)
Vídeos, apuntar RIR, notas permanentes, calculadora de peso o 1RM, superseries, minimizar el entrenamiento para seguir usando la app y recuperar un entrenamiento si se cierra la app.

## Pasos

**Paso 1. Diseño y modelo.**
- Propón cómo vas a organizar la pantalla: un borrador del entrenamiento (como el `_DraftExercise` actual, pero con objetivo de series, repeticiones, descanso, comentario y si cada serie está hecha) y los widgets separados (cabecera, tarjeta de ejercicio, fila de serie, barra de descanso y hojas del menú), cada uno en su archivo dentro de `screens/workouts/`.
- Modelo: añade a `WorkoutExercise` un `comment` (String, opcional). Los entrenamientos antiguos sin ese campo deben leerse sin fallar.
- **No cambies** `WorkoutSet`, `durationMin` ni nada que usen las estadísticas, los logros o el panel del entrenador.
- Explícamelo antes de programarlo.

**Paso 2. Cronómetro, cabecera y resumen en vivo.** Con un `Timer.periodic` de un segundo, guardando la hora de inicio y calculando el tiempo como `ahora − inicio` (así no se desajusta). Cancela el `Timer` en `dispose`.

**Paso 3. Tarjetas de ejercicio y series**, con el ✓, "Añadir serie", ✓✓ y las pistas de la última vez.

**Paso 4. Temporizador de descanso** y descanso automático.

**Paso 5. Menú `⋯` del ejercicio:** cómo hacerlo / historial, sustituir, comentario, cambiar el orden y quitar. Para "sustituir", reutiliza la búsqueda de alternativas del prompt 4 si ya existe; si no, una función sencilla en `data/` que puedan usar las dos pantallas.

**Paso 6. Terminar, descartar y guardar**, incluida la pregunta de guardar los cambios en el plan o la rutina. Comprueba que el entrenamiento guardado aparece en el historial, cuenta en las estadísticas y los logros, y lo ve el entrenador.

**Paso 7. Vista previa y entradas.** Crea la tarjeta de la pestaña Entrenos y la pantalla de vista previa. Todos los sitios que abren hoy `RegisterWorkoutScreen` (Entrenamientos, rutinas y "Empezar entrenamiento" de Inicio) deben abrir la pantalla nueva con sus ejercicios. Desde Entrenamientos, sin rutina, empieza vacía con "Añadir ejercicio".

**Paso 8. Tests** en `test/live_workout_test.dart`, nombrados **CP-15**. Comprueba con la lógica del borrador (sin Firebase):
- que solo se guardan las series marcadas y que un ejercicio sin series marcadas no se guarda;
- el resumen "X de Y series · Z kg";
- que la duración sale del tiempo transcurrido (mínimo 1 minuto);
- que el comentario se guarda y que un entrenamiento antiguo sin comentario se lee bien;
- que "Sustituir" propone primero ejercicios del mismo patrón y nunca uno sin el material del usuario o que cargue una lesión;
- que, si se añade o se quita un ejercicio de un día del plan y se elige "Sí", el día del plan queda con esos cambios, y con "Solo hoy" no cambia.
- **CP-15 (widget):** la pantalla muestra los ejercicios de una rutina y, al marcar una serie, el resumen cambia.

Si algún test existente (por ejemplo, el de registro de entrenamiento, CP-02) deja de pasar porque ya no hay campo de duración, **avísame** antes de cambiarlo: hay que actualizar la memoria.

Ejecuta `flutter analyze` y `flutter test`.

**Resumen final:**
- archivos creados y cambiados;
- cómo probarlo a mano: empezar el día de hoy del plan, marcar series, usar el descanso, sustituir un ejercicio, añadir un comentario, terminar y revisar el historial;
- resultados de los tests para la memoria.
