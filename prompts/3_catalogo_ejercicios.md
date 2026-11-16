Vamos a **ampliar el catálogo de ejercicios** de LiFTeR+ de 10 a 85 y a añadir a cada ejercicio los datos que necesitará el generador de rutinas. Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue".

## Situación actual

- El catálogo está en Firestore (`exercises`, `foods` y `routineTemplates`). El admin lo carga la primera vez con **"Cargar catálogo inicial"**, que llama a `AppStore.seedCatalog()` con los datos de `assets/seed/catalog.json` (clase `CatalogSeed` en `data/catalog.dart`). Ese botón **solo aparece si el catálogo está vacío**.
- **Ya he sustituido `assets/seed/catalog.json` por la versión nueva**, con 85 ejercicios. Los alimentos y las plantillas no han cambiado.
  - Los ejercicios `ex1` a `ex10` **conservan su id y su nombre**, porque las plantillas y los tests los usan.
  - Los nuevos tienen ids como `press_banca_con_mancuernas`.
  - El campo `equipment` sigue siendo un texto (un material por ejercicio).
- Cada ejercicio trae **tres campos nuevos**:
  - `pattern`: el patrón de movimiento. Puede ser `empuje_horizontal`, `empuje_vertical`, `tiron_horizontal`, `tiron_vertical`, `sentadilla`, `bisagra`, `unilateral`, `gluteo`, `pecho_aislamiento`, `hombro_lateral`, `hombro_posterior`, `biceps`, `triceps`, `cuadriceps_aislamiento`, `femoral_aislamiento`, `gemelo` o `core`.
  - `type`: `multiarticular` o `aislamiento`.
  - `stressedZones`: las zonas que carga, con los mismos nombres que las lesiones del cuestionario (hombro, codo, muñeca, cuello, espalda baja, cadera, rodilla, tobillo).
- El nuevo material **"Barra de dominadas"** ya se añadió a `EditProfileScreen.equipmentOptions` en el prompt del cuestionario.

## Pasos

**Paso 1. Modelo `Exercise`.**
- Añade `pattern` (un `enum MovementPattern` con `label` en español y `fromName()`, siguiendo el patrón de `UserRole`), `type` (`bool isCompound` o un enum, lo que sea más sencillo) y `stressedZones` (List<String>).
- **Compatibilidad:** los entrenamientos, rutinas y plantillas guardados en Firestore llevan **copias antiguas** de los ejercicios, sin estos campos. `fromMap` debe leerlos sin fallar, con valores por defecto: por ejemplo, un patrón "otro" y la lista de zonas vacía.
- Comprueba que `CatalogSeed.fromJson` lee el JSON nuevo.

**Paso 2. Actualizar el catálogo que ya está en Firestore.**
- En la base de datos ya están los 10 ejercicios antiguos, y el botón de carga inicial no aparece porque el catálogo no está vacío.
- Añade al `AppStore` un método `updateExercisesFromSeed()`, solo para el admin:
  - sube **solo los ejercicios** del JSON con un `WriteBatch` (crea los nuevos y sobrescribe `ex1`–`ex10` con sus campos nuevos);
  - **actualiza las copias** de esos ejercicios dentro de las plantillas, igual que hace `saveExercise`;
  - **no toca alimentos ni plantillas**, para no perder lo que el admin haya editado.
- Ojo: un `WriteBatch` admite como máximo 500 operaciones, así que 85 ejercicios caben.
- En la pestaña Catálogo del panel de administración (`admin_screen.dart`, `_CatalogTab`), añade un botón **"Actualizar ejercicios desde el archivo"**, visible aunque el catálogo no esté vacío, con un diálogo de confirmación que diga cuántos ejercicios se van a subir.
- **Toca lo mínimo de las pantallas de administración**: las ha hecho mi compañero.

**Paso 3. Formulario de ejercicio del admin** (`_ExerciseDialog`, en `catalog_screens.dart`).
- Añade los campos nuevos de la forma más sencilla:
  - un desplegable para el patrón;
  - un interruptor o desplegable para el tipo;
  - chips de selección múltiple para las zonas.
- Así, los ejercicios que cree el admin también sirven para el generador.

**Paso 4. Mostrar los datos nuevos** donde ayuden, sin rediseñar nada: por ejemplo, el patrón en el subtítulo de la lista de ejercicios del admin.

**Paso 5. Tests.**
- Crea `test/exercise_catalog_test.dart` con tests nombrados **CP-13** que comprueben:
  - que el JSON tiene 85 ejercicios con ids únicos y que `ex1`–`ex10` existen;
  - que todos los `pattern`, `equipment`, `level` y `stressedZones` son valores válidos;
  - que un ejercicio antiguo (sin los campos nuevos) se lee sin fallar;
  - que un usuario que no es admin no puede llamar a `updateExercisesFromSeed()` (debe devolver el mensaje de error, como en CP-08).
- Si algún test existente esperaba **10 ejercicios** en el seed, **avísame** antes de cambiarlo: hay que actualizar la memoria (CP-07).

Ejecuta `flutter analyze` y `flutter test`.

**Resumen final:**
- archivos cambiados;
- cómo probarlo: entrar como admin → Catálogo → "Actualizar ejercicios desde el archivo" → comprobar que hay 85 ejercicios, que las plantillas siguen funcionando y que en "Registrar entrenamiento" aparecen los nuevos;
- resultados de los tests.
