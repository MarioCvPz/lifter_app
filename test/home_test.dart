import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/stats.dart';
import 'package:lifter_app/models/models.dart';
import 'package:lifter_app/screens/home/home_screen.dart';
import 'package:lifter_app/theme/app_theme.dart';

import 'helpers.dart';

/// Plan con un solo día de entreno: hoy, con el press de banca.
TrainingPlan planForToday() => TrainingPlan(
  generatedAt: DateTime(2026, 11, 10),
  days: [
    PlanDay(
      weekday: DateTime.now().weekday,
      type: PlanDayType.push,
      exercises: const [
        PlanExercise(
          exercise: bench,
          sets: 4,
          minReps: 8,
          maxReps: 12,
          restSeconds: 90,
        ),
      ],
    ),
  ],
);

AssignedRoutine trainerRoutine() => AssignedRoutine(
  id: 'a1',
  routine: const Routine(
    id: 'a1',
    name: 'Rutina de Marta',
    description: '',
    templateName: 'Entrenador',
    exercises: [squat],
  ),
  trainerId: 't1',
  trainerName: 'Marta',
  userId: 'u1',
  userName: 'Ana',
  createdAt: DateTime(2026, 11, 1),
);

void main() {
  final today = DateTime.now().weekday;
  // Un día que no es hoy, para el día de descanso.
  final restDay = today % 7 + 1;

  test('El entreno del día: entrenador, plan o descanso', () {
    final store = AppStore()
      ..user = profile()
      ..plan = planForToday();

    final fromPlan = store.workoutFor(today);
    expect(fromPlan?.fromTrainer, isFalse);
    expect(fromPlan?.routine.exercises, [bench]);
    expect(fromPlan?.name, 'Empuje');
    expect(fromPlan?.exerciseCountLabel, '1 ejercicio');
    expect(store.workoutFor(restDay), isNull);

    // La rutina del entrenador va en lugar del día del plan, pero no en
    // los días de descanso.
    store.assignedToMe.add(trainerRoutine());
    final fromTrainer = store.workoutFor(today);
    expect(fromTrainer?.fromTrainer, isTrue);
    expect(fromTrainer?.name, 'Rutina de Marta');
    expect(store.workoutFor(restDay), isNull);
  });

  test('La píldora de hoy: hecho, descanso u hora de entrenar', () {
    final now = DateTime.now();
    final store = AppStore()..user = profile();
    // Sin plan: como antes.
    expect(store.todayStatus(now), endsWith(': hora de entrenar'));

    store.plan = planForToday();
    expect(store.todayStatus(now), endsWith(': hora de entrenar'));
    final tomorrow = now.add(const Duration(days: 1));
    expect(store.todayStatus(tomorrow), 'Hoy: descanso');

    // Si ha entrenado, manda eso aunque sea día de descanso.
    store.workouts.add(workoutOn(tomorrow));
    expect(store.todayStatus(tomorrow), 'Hoy: entreno hecho');
  });

  test('Los litros se muestran con hasta dos decimales y coma', () {
    expect(formatLiters(0), '0');
    expect(formatLiters(250), '0,25');
    expect(formatLiters(500), '0,5');
    expect(formatLiters(750), '0,75');
    expect(formatLiters(1000), '1');
    expect(formatLiters(1250), '1,25');
    expect(formatLiters(10000), '10');
    expect(formatLiters(2630), '2,63');
  });

  test('Mensajes del agua solo al cruzar el objetivo o el doble', () {
    // 70 kg → objetivo de 2.500 ml (35 ml por kg, redondeado).
    final store = AppStore()..user = profile(weightKg: 70);
    expect(store.waterGoalMl, 2500);

    expect(store.waterMessage(2250, 2500), '¡Objetivo de agua cumplido!');
    expect(store.waterMessage(2500, 2750), isNull); // ya estaba cumplido
    expect(
      store.waterMessage(4750, 5000),
      isNull,
    ); // justo el doble aún no avisa
    expect(
      store.waterMessage(5000, 5250),
      'Estás bebiendo mucha agua, ten cuidado',
    );
    expect(store.waterMessage(5250, 5500), isNull); // solo una vez
  });

  testWidgets('Inicio muestra el entreno de hoy y lo oculta en descanso', (
    tester,
  ) async {
    final store = AppStore()
      ..user = profile()
      ..plan = planForToday()
      ..assignedToMe.add(trainerRoutine());
    await pumpScreen(tester, store, const HomeScreen());

    expect(find.text('Entreno de hoy'), findsOneWidget);
    expect(find.text('De tu entrenador'), findsOneWidget);
    expect(find.text('Rutina de Marta'), findsOneWidget);
    expect(find.text('1 ejercicio'), findsOneWidget);
    // Ya no se listan los ejercicios, solo cuántos son.
    expect(find.text('Sentadilla'), findsNothing);
    expect(
      find.text('Hoy · ${ProfileOptions.weekdayNames[today - 1]}'),
      findsOneWidget,
    );
    expect(find.text('Empezar entrenamiento'), findsOneWidget);

    // Al tocar un día de descanso, la sección desaparece.
    final restDayNumber = DateTime.now()
        .add(Duration(days: restDay - today))
        .day;
    await tester.tap(find.text('$restDayNumber').first);
    await tester.pump();
    expect(find.text('Entreno de hoy'), findsNothing);
    expect(find.text('Empezar entrenamiento'), findsNothing);
  });

  testWidgets('Agua: el aviso solo sale al cumplir el objetivo', (
    tester,
  ) async {
    // 70 kg → objetivo de 2,5 L. Le falta un vaso.
    final store = AppStore()
      ..user = profile(weightKg: 70)
      ..waterMl = 2250;
    await pumpScreen(tester, store, const HomeScreen());

    await tester.tap(find.byTooltip('Añadir 250 ml'));
    await tester.pumpAndSettle();
    expect(find.text('¡Objetivo de agua cumplido!'), findsOneWidget);
    expect(find.text('Deshacer'), findsNothing);
    expect(find.text('2,5 / 2,5 L', findRichText: true), findsOneWidget);
  });

  testWidgets('Inicio cabe en un móvil estrecho (360 px)', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = AppStore()
      ..user = profile()
      ..plan = planForToday();
    await tester.pumpWidget(
      SessionScope(
        store: store,
        child: MaterialApp(theme: AppTheme.dark(), home: const HomeScreen()),
      ),
    );
    // Si algo se saliera de su sitio, Flutter lanzaría un error de overflow.
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Añadir 250 ml'), findsOneWidget);
  });
}
