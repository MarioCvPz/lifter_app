import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Ayuda de cada pantalla. Si cambia cómo funciona una pantalla, actualiza
/// aquí su texto.
enum HelpTopic {
  login('Cómo entrar', [
    (
      Icons.login,
      'Iniciar sesión',
      'Escribe tu correo y contraseña y pulsa "Iniciar sesión".',
    ),
    (
      Icons.person_add_alt,
      'Crear cuenta',
      'Pulsa "¿No tienes cuenta? Regístrate", rellena tu nombre, correo y '
          'una contraseña de al menos 6 caracteres.',
    ),
    (
      Icons.g_mobiledata,
      'Con Google',
      'Pulsa "Continuar con Google" y elige tu cuenta. Si es la primera '
          'vez, se crea tu perfil automáticamente.',
    ),
    (
      Icons.lock_reset,
      '¿Olvidaste la contraseña?',
      'Escribe tu correo y pulsa "¿Has olvidado tu contraseña?". Te llegará '
          'un correo para cambiarla (mira también en spam).',
    ),
  ]),

  home('Cómo funciona Inicio', [
    (
      Icons.local_fire_department,
      'Racha',
      'Días seguidos en los que has entrenado. Si hoy aún no has entrenado, '
          'cuenta hasta ayer.',
    ),
    (
      Icons.calendar_view_week,
      'Tu semana',
      'De lunes a domingo. Los días de entreno de tu plan llevan un punto y '
          'hoy tiene el borde en coral. Toca un día para ver su entreno.',
    ),
    (
      Icons.local_dining,
      'Calorías',
      'Lo que llevas hoy frente a tu objetivo. Tócalas para ir a '
          'Nutrición.',
    ),
    (
      Icons.water_drop,
      'Agua',
      'Pulsa + para sumar un vaso de 250 ml y − para quitarlo si te '
          'equivocas. El objetivo se calcula con tu peso (35 ml por kg).',
    ),
    (
      Icons.play_circle,
      'Entreno de hoy',
      'Los ejercicios del día según tu plan o, si tu entrenador te ha '
          'asignado una rutina, la suya. Pulsa "Empezar entrenamiento" para '
          'apuntarlo. Los días de descanso no aparece.',
    ),
  ]),

  workouts('Cómo funcionan los entrenos', [
    (
      Icons.history,
      'Historial',
      'Aquí están todos tus entrenos, el más reciente arriba. Toca uno para '
          'ver sus ejercicios y series.',
    ),
    (
      Icons.add,
      'Registrar',
      'Pulsa "Registrar" para apuntar un entreno nuevo desde cero. Para '
          'empezar desde una rutina, hazlo desde Rutinas o Inicio.',
    ),
    (
      Icons.swipe_left,
      'Borrar',
      'Desliza un entreno hacia la izquierda para borrarlo. Si te equivocas, '
          'pulsa "Deshacer" en el aviso de abajo.',
    ),
    (
      Icons.bar_chart,
      'Volumen',
      'Los kg de cada entreno son la suma de repeticiones × peso de todas '
          'sus series.',
    ),
  ]),

  registerWorkout('Cómo funciona el entrenamiento', [
    (
      Icons.timer_outlined,
      'Cronómetro',
      'Arriba a la izquierda va el tiempo total. Empieza solo al abrir el '
          'entrenamiento; al terminar puedes corregirlo.',
    ),
    (
      Icons.check_circle_outline,
      'Series',
      'Escribe kg y repeticiones y pulsa ✓ al acabar cada serie. En gris '
          'ves lo que hiciste la última vez: si no escribes nada, se usa '
          'eso. ✓✓ marca todas. Desliza una serie a la izquierda para '
          'borrarla.',
    ),
    (
      Icons.hourglass_bottom,
      'Descanso',
      'Con "Descanso automático", al marcar una serie empieza la cuenta '
          'atrás del ejercicio. Con el reloj de arriba eliges otro tiempo.',
    ),
    (
      Icons.more_horiz,
      'Ejercicios',
      'Con ⋯ en cada ejercicio puedes ver cómo se hace y tu historial, '
          'sustituirlo, añadir otro después, dejar un comentario para tu '
          'entrenador, moverlo o quitarlo.',
    ),
    (
      Icons.flag_outlined,
      'Terminar',
      'Solo se guardan las series marcadas. Si has cambiado ejercicios de '
          'tu plan o de tu rutina, te preguntará si quieres guardarlos para '
          'la próxima vez.',
    ),
  ]),

  routines('Cómo funcionan las rutinas', [
    (
      Icons.search,
      'Buscar y filtrar',
      'Busca por nombre de rutina o de ejercicio. Filtra por grupo muscular '
          '(chips) y por nivel (pestañas).',
    ),
    (
      Icons.radio_button_checked,
      'Rutina activa',
      'La rutina de tu último entreno hecho desde una rutina, con las '
          'sesiones que llevas esta semana. Pulsa "Continuar" para seguir.',
    ),
    (
      Icons.view_list,
      'Secciones',
      '"De tu entrenador": las que te ha asignado tu entrenador. "Planes '
          'recomendados": plantillas de la app. "Mis rutinas": las tuyas.',
    ),
    (
      Icons.visibility,
      'Ver rutina',
      'Muestra sus ejercicios. Desde ahí pulsa "Empezar entreno" para '
          'apuntar una sesión con esa rutina.',
    ),
    (
      Icons.add_circle,
      'Crear y borrar',
      'Pulsa "Crear rutina personalizada", ponle nombre y elige ejercicios. '
          'Tus rutinas se borran con la papelera de su tarjeta.',
    ),
    (
      Icons.info_outline,
      'Nivel y duración',
      'El nivel es el del ejercicio más exigente. La duración es una '
          'estimación de 5 minutos por ejercicio.',
    ),
  ]),

  nutrition('Cómo funciona Nutrición', [
    (
      Icons.calendar_today,
      'Elegir día',
      'Usa las flechas para ver días anteriores. Lo que añadas se apunta en '
          'el día que estés viendo.',
    ),
    (
      Icons.pie_chart_outline,
      'Resumen del día',
      'Calorías, proteínas, hidratos y grasas frente a tu objetivo. La '
          'barra se pone en rojo si te pasas.',
    ),
    (
      Icons.add,
      'Añadir alimento',
      'Busca en el catálogo, toca el alimento y escribe los gramos. Las '
          'calorías y macros se calculan solas.',
    ),
    (Icons.close, 'Quitar', 'Pulsa la X de un registro para borrarlo.'),
    (
      Icons.tune,
      'Tu objetivo',
      'Es orientativo. Partimos de tu metabolismo basal (fórmula de '
          'Mifflin-St Jeor, con tu sexo, edad, altura y peso), lo '
          'multiplicamos por tu actividad diaria y sumamos o restamos según '
          'tu objetivo, sin bajar nunca del basal. La proteína es de 1,8 g '
          'por kg (con un tope si hay sobrepeso), la grasa el 25 % de las calorías y el resto, hidratos. '
          'Si cambias tus datos en el Perfil, se recalcula.',
    ),
  ]),

  profile('Cómo funciona el Perfil', [
    (
      Icons.edit,
      'Editar perfil',
      'Pulsa "Editar perfil" para cambiar tus datos, tu material y tus '
          'días disponibles, y después "Guardar". La foto es la de tu cuenta '
          'de Google; si no entras con Google se muestra tu inicial.',
    ),
    (
      Icons.military_tech,
      'Insignias',
      'Se consiguen entrenando: rachas, número de entrenos, volumen, comidas '
          'y agua. Las bloqueadas salen con candado y su progreso; toca una '
          'para ver qué te falta.',
    ),
    (
      Icons.insights,
      'Estadísticas',
      'Totales de todo tu historial y un gráfico con los entrenos de las '
          'últimas 8 semanas (la barra coral es la semana actual).',
    ),
    (
      Icons.tune,
      'Para qué sirven',
      'Tus datos físicos, tu actividad diaria y tu objetivo ajustan las '
          'calorías y los macros; el peso, también el agua. Tus días, '
          'minutos, material, lesiones, objetivo y experiencia deciden tu '
          'plan de entrenamiento.',
    ),
    (
      Icons.badge,
      'Tu rol',
      'Si eres entrenador o admin aparece una etiqueta y los botones de tu '
          'panel. El rol solo lo puede cambiar un admin.',
    ),
    (
      Icons.logout,
      'Cerrar sesión',
      'Al final de la página. Tus datos siguen guardados en tu cuenta.',
    ),
  ]),

  trainer('Cómo funciona el panel de entrenador', [
    (
      Icons.assignment_add,
      'Asignar rutina',
      'Pulsa "Asignar rutina", elige el usuario y crea su rutina. Le '
          'aparecerá en Rutinas → "De tu entrenador".',
    ),
    (
      Icons.groups,
      'Tus usuarios',
      'Un usuario pasa a ser tuyo cuando le asignas una rutina. Arriba eliges '
          'el periodo (4, 8 o 12 semanas) y ves sus sesiones, el cumplimiento '
          '(sesiones hechas frente a sus días por semana) y cuándo entrenó por '
          'última vez.',
    ),
    (
      Icons.person_search,
      'Ficha',
      'Toca un usuario para ver sus sesiones por semana, sus ejercicios más '
          'hechos y las rutinas que le has asignado.',
    ),
    (
      Icons.download,
      'Informes',
      'Con el botón de descarga sacas un Excel (tablas por usuario, por '
          'semana, entrenos y ejercicios) o un PDF con gráficas del periodo '
          'elegido.',
    ),
    (
      Icons.delete_outline,
      'Asignadas',
      'En la pestaña "Asignadas" ves todas tus rutinas asignadas. Con la '
          'papelera borras una; el usuario deja de verla.',
    ),
  ]),

  admin('Cómo funciona la administración', [
    (
      Icons.insights,
      'Resumen',
      'Usuarios por rol, usuarios activos, entrenos de la semana, tamaño del '
          'catálogo, ejercicios más usados y quién lleva 2 semanas sin '
          'entrenar.',
    ),
    (
      Icons.groups,
      'Usuarios',
      'Busca por nombre o correo y desliza hacia abajo (o pulsa ↻) para '
          'recargar.',
    ),
    (
      Icons.manage_accounts,
      'Cambiar rol',
      'Elige el nuevo rol en el desplegable de cada usuario y confirma. Así '
          'se nombran entrenadores u otros admins.',
    ),
    (
      Icons.lock_outline,
      'Tu propio rol',
      'No puedes cambiarte el rol a ti mismo. El primer admin se pone desde '
          'la consola de Firebase.',
    ),
    (
      Icons.restaurant_menu,
      'Catálogo',
      'Alimentos, ejercicios y plantillas de rutina que ve todo el mundo. '
          'Toca uno para editarlo, "Añadir" para crear y la papelera para '
          'borrar. Si está vacío, pulsa "Cargar catálogo inicial".',
    ),
  ]);

  const HelpTopic(this.title, this.items);

  final String title;
  final List<(IconData, String, String)> items;
}

/// Botón ⓘ que abre la ayuda de la pantalla.
class HelpButton extends StatelessWidget {
  const HelpButton(this.topic, {super.key});

  final HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Cómo se usa',
      icon: const Icon(Icons.info_outline),
      onPressed: () => showHelp(context, topic),
    );
  }
}

void showHelp(BuildContext context, HelpTopic topic) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final text = Theme.of(ctx).textTheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, controller) {
          return ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(topic.title, style: text.headlineSmall),
              const SizedBox(height: 16),
              for (final (icon, title, body) in topic.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppTheme.coral.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 20, color: AppTheme.coral),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: text.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              body,
                              style: text.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          );
        },
      );
    },
  );
}
