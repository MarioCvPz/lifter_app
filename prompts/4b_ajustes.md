Vamos a hacer unos **ajustes pequeños** después del prompt 4. Lee primero `CLAUDE.md` y sigue sus reglas. Trabaja **por pasos**: al terminar cada paso, para, explícame qué has hecho y espera a que te diga "sigue". No cambies nada que no esté en esta lista.

**Paso 1. Inicio: el entreno del día, resumido.**
- En la tarjeta del entreno del día, **quita la lista de ejercicios**. Debe mostrar solo:
  - el día ("Hoy · Martes"),
  - el nombre del entreno ("Empuje"),
  - debajo, **el número de ejercicios** ("6 ejercicios"),
  - y el botón "Empezar entrenamiento".
- Todo lo demás de Inicio se queda igual.

**Paso 2. Agua.**
- Al pulsar **+**, **no** muestres el aviso de abajo (`SnackBar` "+250 ml de agua" con "Deshacer"). El cambio se ve directamente en la cifra y la barra. Para deshacer ya está el botón **−**.
- **Arregla cómo se muestran los litros**: hoy, con vasos de 250 ml, sale 0,3 · 0,5 · 0,8 · 1. Debe salir **0,25 · 0,5 · 0,75 · 1 · 1,25…**: hasta dos decimales, sin ceros sobrantes al final y con coma decimal. Haz una función pequeña para formatear litros y úsala en todos los sitios donde se muestre el agua (Inicio, Nutrición y la ayuda si sale ahí).
- Lo demás se mantiene: el **−** desactivado en 0, el mensaje al cumplir el objetivo y el aviso al pasar del doble.

**Paso 3. Quitar "Kettlebell".**
- Quítalo de las opciones de material (`ProfileOptions` / `EditProfileScreen.equipmentOptions`) y del material por defecto de los lugares si aparece.
- Ningún ejercicio del catálogo usa Kettlebell, compruébalo.
- Si un perfil guardado tiene "Kettlebell" en su material, al leerlo se ignora (no debe fallar ni mostrarse).

**Paso 4. El generador: en el gimnasio, ejercicios de gimnasio.**
Hoy, a un usuario de gimnasio le pueden salir ejercicios de casa (con bandas o peso corporal) porque también tiene ese material marcado. Cambia la **preferencia** al rellenar cada hueco, sin tocar los filtros obligatorios (material, nivel y lesiones):
- Si `trainingPlace` es **gimnasio**:
  - primero, ejercicios con **Barra, Mancuernas, Máquinas, Polea o Barra de dominadas**;
  - **Peso corporal** solo si no hay ninguno de los anteriores para ese hueco (por ejemplo, algunos de core);
  - **Bandas elásticas, nunca**.
- En casa y al aire libre no cambia nada.
- Además, para **todos** los lugares: entre los candidatos válidos, prefiere los del **mismo nivel que el usuario** y después los de nivel inferior. Así un avanzado recibe primero ejercicios de avanzado.
- Pon estas preferencias en constantes con nombre y en un método pequeño, como el resto de reglas.
- Los ejercicios que el usuario añadió o sustituyó (`isCustom`) no se tocan.
- Añade a `test/routine_generator_test.dart` (CP-14):
  - un avanzado de gimnasio con todo el material no recibe ningún ejercicio con bandas, y solo recibe de peso corporal en huecos sin alternativa de gimnasio;
  - un usuario de casa con mancuernas, bandas y peso corporal sigue recibiendo esos ejercicios.
- Explícame cómo aplicar el cambio a los planes que **ya están guardados** (por ejemplo, actualizarlos al abrir la app si el plan se generó con la versión anterior del generador, o desde Ajustes). Propón la forma más sencilla y espera a que te diga cuál.

Ejecuta `flutter analyze` y `flutter test`.

**Resumen final:** archivos cambiados, cómo probar cada paso a mano y resultado de los tests.
