import 'dart:convert';

import 'package:excel/excel.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/client_report.dart';
import 'package:lifter_app/data/report_export.dart';
import 'package:lifter_app/models/models.dart';

const _bench = Exercise(
  id: 'ex1',
  name: 'Press de banca',
  muscleGroup: 'Pecho',
  equipment: 'Barra',
  level: 'Intermedio',
);

Workout _workout(
  DateTime date, {
  double kg = 50,
  int reps = 10,
  String? routineId,
}) => Workout(
  id: date.toIso8601String(),
  name: 'Sesión',
  date: date,
  durationMin: 30,
  routineId: routineId,
  exercises: [
    WorkoutExercise(
      exercise: _bench,
      sets: [WorkoutSet(reps: reps, weightKg: kg)],
    ),
  ],
);

AppUser _user(String name, {int days = 3}) => AppUser(
  uid: name,
  profile: UserProfile(
    name: name,
    username: name,
    email: '$name@test.com',
    daysPerWeek: days,
  ),
);

void main() {
  // Miércoles 11/11/2026: la semana actual empieza el lunes 9/11.
  final now = DateTime(2026, 11, 11, 18);

  group('ClientReport', () {
    final report = ClientReport(
      user: _user('Ana'),
      weeks: 2,
      now: now,
      assignedRoutineIds: {'r1'},
      workouts: [
        _workout(DateTime(2026, 11, 10), routineId: 'r1'), // esta semana
        _workout(DateTime(2026, 11, 9)), // esta semana (lunes)
        _workout(DateTime(2026, 11, 4), kg: 60), // semana anterior
        _workout(DateTime(2026, 10, 20)), // fuera del periodo
      ],
    );

    test('CP-09 Estadísticas de cliente: entrenos del periodo', () {
      expect(report.weekStarts, [DateTime(2026, 11, 2), DateTime(2026, 11, 9)]);
      expect(report.sessions, 3);
      expect(report.sessionsByWeek, [1, 2]);
      expect(report.volumeByWeek, [600, 1000]);
      expect(report.minutes, 90);
    });

    test('CP-09 Estadísticas de cliente: cumplimiento', () {
      // 3 sesiones de 3 días × 2 semanas = 50 %.
      expect(report.adherencePct, 50);
      expect(report.sessionsPerWeek, 1.5);
    });

    test('CP-09 Estadísticas de cliente: rutina asignada y último entreno', () {
      expect(report.assignedSessions, 1);
      expect(report.lastWorkout, DateTime(2026, 11, 10));
      expect(report.daysSinceLast, 1);
    });

    test('CP-09 Estadísticas de cliente: ejercicios más hechos', () {
      final top = report.topExercises();
      expect(top, hasLength(1));
      expect(top.first.times, 3);
      expect(top.first.bestKg, 60);
    });

    test('CP-09 Estadísticas de cliente: usuario sin entrenos', () {
      final empty = ClientReport(user: _user('Leo'), workouts: [], now: now);
      expect(empty.sessions, 0);
      expect(empty.adherencePct, 0);
      expect(empty.daysSinceLast, isNull);
      expect(empty.sessionsByWeek, [0, 0, 0, 0]);
    });
  });

  group('Informe', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    final report = TrainerReport(
      trainerName: 'Entrenador',
      weeks: 2,
      createdAt: now,
      clients: [
        ClientReport(
          user: _user('Ana'),
          weeks: 2,
          now: now,
          workouts: [_workout(DateTime(2026, 11, 11))],
        ),
        ClientReport(
          user: _user('Leo', days: 4),
          weeks: 2,
          now: now,
          workouts: [],
        ),
      ],
    );

    test('CP-10 El informe Excel tiene 5 hojas y una fila por usuario', () {
      final book = xl.Excel.decodeBytes(report.buildExcel());
      expect(book.tables.keys, [
        'Resumen',
        'Sesiones por semana',
        'Volumen por semana',
        'Entrenos',
        'Ejercicios',
      ]);
      final resumen = book.tables['Resumen']!;
      expect(resumen.maxRows, 3); // cabecera + 2 usuarios
      expect(resumen.rows[1][0]?.value.toString(), 'Ana');
      expect(book.tables['Entrenos']!.maxRows, 2);
    });

    test('CP-10 El informe PDF se genera', () async {
      final bytes = await report.buildPdf();
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    });
  });
}
