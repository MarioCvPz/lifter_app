import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/models/models.dart';

import 'helpers.dart';

void main() {
  test('CP-13 El catálogo tiene 85 ejercicios con ids únicos y ex1–ex10', () {
    final exercises = readSeed().exercises;

    expect(exercises, hasLength(85));
    expect({for (final e in exercises) e.id}, hasLength(85));
    final ids = {for (final e in exercises) e.id};
    for (var i = 1; i <= 10; i++) {
      expect(ids, contains('ex$i'));
    }
    // Los antiguos conservan su nombre (las plantillas y los tests los usan).
    final bench = exercises.firstWhere((e) => e.id == 'ex1');
    expect(bench.name, 'Press de banca');
  });

  test('CP-13 Todos los datos de los ejercicios son valores válidos', () {
    for (final e in readSeed().exercises) {
      final reason = 'Ejercicio ${e.id}';
      expect(e.pattern, isNot(MovementPattern.other), reason: reason);
      expect(ProfileOptions.equipment, contains(e.equipment), reason: reason);
      expect(Routine.levels, contains(e.level), reason: reason);
      expect(
        ProfileOptions.injuries,
        containsAll(e.stressedZones),
        reason: reason,
      );
    }

    // El JSON trae las zonas en minúscula; al leerlas quedan como en el
    // cuestionario. Y el tipo se lee bien.
    final bench = readSeed().exercises.firstWhere((e) => e.id == 'ex1');
    expect(bench.pattern, MovementPattern.horizontalPush);
    expect(bench.isCompound, isTrue);
    expect(bench.stressedZones, ['Hombro', 'Codo', 'Muñeca']);
  });

  test(
    'CP-13 Un ejercicio antiguo sin los campos nuevos se lee sin fallar',
    () {
      // Así están las copias guardadas dentro de entrenos, rutinas y
      // plantillas antiguas.
      final old = Exercise.fromMap({
        'id': 'ex1',
        'name': 'Press de banca',
        'muscleGroup': 'Pecho',
        'equipment': 'Barra',
        'level': 'Intermedio',
      });

      expect(old.pattern, MovementPattern.other);
      expect(old.isCompound, isFalse);
      expect(old.stressedZones, isEmpty);

      // Al guardarlo y volver a leerlo, los campos nuevos se conservan.
      final again = Exercise.fromMap(readSeed().exercises.first.toMap());
      expect(again.pattern, MovementPattern.horizontalPush);
      expect(again.isCompound, isTrue);
      expect(again.stressedZones, ['Hombro', 'Codo', 'Muñeca']);
    },
  );

  test('CP-13 Solo un admin puede actualizar los ejercicios', () async {
    for (final role in [UserRole.user, UserRole.trainer]) {
      final store = AppStore()..user = profile(role: role);
      expect(
        await store.updateExercisesFromSeed(readSeed()),
        'Solo un admin puede actualizar los ejercicios.',
      );
    }
  });

  test('CP-13 Solo se crean las plantillas del archivo que faltan', () {
    final seed = readSeed();
    final store = AppStore();

    // Sin plantillas en Firestore faltan todas.
    expect(store.missingSeedTemplates(seed), hasLength(seed.templates.length));

    // Si una ya existe, no se vuelve a crear.
    store.templates.add(seed.templates.first);
    expect(store.missingSeedTemplates(seed).map((t) => t.id), [
      for (final t in seed.templates.skip(1)) t.id,
    ]);
  });
}
