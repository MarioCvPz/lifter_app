Vamos a cambiar cómo LiFTeR+ calcula las **calorías y los macronutrientes** diarios. Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue".

Este prompt va **después del cuestionario inicial** (prompt 1): el perfil ya tiene `sex`, `birthDate` (con `age`), `heightCm`, `weightKg`, `activityLevel` y `goal` (enum `TrainingGoal`).

## Situación actual

`macroTargets()`, en `lib/data/stats.dart`, calcula `peso × 33` ajustado por objetivo, la proteína a 1,6–2,0 g/kg y la grasa a 0,9 g/kg. Ignora la altura, la edad, el sexo y la actividad.

## Reglas nuevas (ya decididas, no las cambies)

**1. Metabolismo basal (Mifflin-St Jeor)**
- Hombre: `10 × peso(kg) + 6,25 × altura(cm) − 5 × edad + 5`
- Mujer: `10 × peso(kg) + 6,25 × altura(cm) − 5 × edad − 161`
- Si falta la fecha de nacimiento (perfiles antiguos), usa 30 años.

**2. Mantenimiento = basal × factor de actividad diaria.** El factor ya incluye que el usuario entrena:

| Actividad diaria | Factor |
|---|---|
| Sedentario | 1,3 |
| Ligeramente activo | 1,4 |
| Activo | 1,5 |
| Muy activo | 1,6 |

**3. Ajuste según el objetivo (kcal fijas)**

| Objetivo | Ajuste |
|---|---|
| Ganar masa muscular | +250 |
| Perder grasa | −350 |
| Recomposición corporal | −150 |
| Ganar fuerza | +150 |
| Salud general | 0 |

**Límite de seguridad:** las calorías objetivo **nunca bajan del metabolismo basal**.

**4. Macronutrientes**
- **Proteína:** 1,8 g por kg de **peso de referencia**, que es el menor entre el peso real y `25 × altura(m)²` (el peso con un IMC de 25). Así no salen cifras exageradas con mucho sobrepeso.
- **Grasa:** el 25 % de las calorías (9 kcal/g).
- **Hidratos:** el resto (4 kcal/g).
- Redondea a números enteros.

**Ejemplo para comprobarlo:** hombre, 22 años, 78 kg, 178 cm, ligeramente activo, ganar masa muscular.
- Basal: 1.788 kcal.
- Mantenimiento: 2.503 kcal.
- **Objetivo: 2.753 kcal**, con unos **140 g** de proteína, **76 g** de grasa y **376 g** de hidratos.

## Pasos

**Paso 1. Diseño.**
- Propón una clase `NutritionCalculator` en `lib/data/` con métodos estáticos pequeños, uno por regla: `bmr`, `maintenance`, `targetCalories` y `macros`.
- Reciben un `UserProfile` y **no dependen de Firebase ni de Flutter**.
- Los números van en **constantes con nombre**. El factor de cada `ActivityLevel` y el ajuste de cada `TrainingGoal` pueden ir en los propios `enum`.
- Explícamelo antes de programarlo.

**Paso 2. Implementarlo**, con comentarios `///` que expliquen cada regla y de dónde sale (Mifflin-St Jeor; la ISSN recomienda 1,4–2,0 g/kg de proteína).

**Paso 3. Usarlo:**
- `macroTargets()` debe usar `NutritionCalculator` y devolver el mismo tipo `DailyMacros`, para no romper las pantallas.
- La pantalla "Tu plan" del cuestionario debe usarlo también.
- Si alguna pantalla o ayuda (`widgets/help.dart`) explica cómo se calculan las calorías, actualiza ese texto.

**Paso 4. Tests.**
- Crea `test/nutrition_calculator_test.dart` con tests nombrados **CP-12** que comprueben:
  - el ejemplo de arriba;
  - una mujer;
  - el límite de seguridad (un caso de perder grasa que bajaría del basal);
  - el peso de referencia (130 kg y 1,75 m → proteína de unos 77 kg, es decir, unos 138 g).
- **El test CP-04** (`test/nutrition_water_test.dart`) espera hoy un objetivo de 2.904 kcal (80 × 33 × 1,10) y 160 g de proteína: **ese resultado cambiará**.
  - Antes de modificarlo, **avísame** y dime qué perfil usa el test y qué valores salen ahora con las reglas nuevas.
  - Hay que actualizar también la memoria.

Ejecuta `flutter analyze` y `flutter test`.

**Resumen final:**
- archivos cambiados;
- los valores nuevos de CP-04;
- resultado de los tests;
- cómo comprobarlo a mano (cambiar objetivo o peso en "Editar perfil" y ver cómo cambian las calorías en Nutrición).
