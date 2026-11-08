import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/data/achievements.dart';
import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/data/catalog.dart';
import 'package:lifter_app/models/models.dart';

import 'helpers.dart';

void main() {
  test('El catálogo inicial (assets/seed/catalog.json) es válido', () {
    final json = File('assets/seed/catalog.json').readAsStringSync();
    final seed = CatalogSeed.fromJson(jsonDecode(json) as Map<String, dynamic>);

    expect(seed.exercises, hasLength(10));
    expect(seed.foods, hasLength(6));
    expect(seed.templates, hasLength(3));
    // Ids únicos.
    expect({for (final e in seed.exercises) e.id}, hasLength(10));
    expect({for (final f in seed.foods) f.id}, hasLength(6));
    for (final t in seed.templates) {
      expect(t.isTemplate, isTrue);
      expect(t.recommendedDays, isNotNull);
      expect(t.exercises, isNotEmpty);
      // Todos los ejercicios de las plantillas existen en el catálogo.
      expect(seed.exercises, containsAll(t.exercises));
    }
  });

  test('CP-08 Solo un admin puede modificar el catálogo', () async {
    final store = AppStore()..user = profile(role: UserRole.trainer);

    expect(
      await store.saveFood(chicken),
      'Solo un admin puede editar el catálogo.',
    );
    expect(
      await store.deleteFood(chicken.id),
      'Solo un admin puede editar el catálogo.',
    );
    expect(
      await store.seedCatalog(),
      'Solo un admin puede cargar el catálogo.',
    );
  });

  test('Roles: permisos y valores por defecto', () async {
    // Un rol desconocido o ausente se trata como usuario normal.
    expect(UserRole.fromName(null), UserRole.user);
    expect(UserRole.fromName('superadmin'), UserRole.user);
    expect(UserRole.fromName('trainer'), UserRole.trainer);

    final user = AppStore()..user = profile();
    expect(user.isTrainer, isFalse);
    expect(user.isAdmin, isFalse);
    expect(
      await user.setRole('otro', UserRole.admin),
      'Solo un admin puede cambiar roles.',
    );

    final trainer = AppStore()..user = profile(role: UserRole.trainer);
    expect(trainer.isTrainer, isTrue);
    expect(trainer.isAdmin, isFalse);

    // Un admin también tiene las funciones de entrenador.
    final admin = AppStore()..user = profile(role: UserRole.admin);
    expect(admin.isTrainer, isTrue);
    expect(admin.isAdmin, isTrue);
  });

  test('Las insignias se desbloquean al llegar al objetivo', () {
    final store = AppStore()..user = profile();
    Achievement byName(String n) =>
        achievementsFor(store).firstWhere((a) => a.name == n);

    expect(byName('Primer paso').unlocked, isFalse);

    store.workouts.add(workoutOn(DateTime.now()));
    expect(byName('Primer paso').unlocked, isTrue);
    expect(byName('Habitual').unlocked, isFalse);
    expect(byName('Habitual').progress, closeTo(0.1, 0.001));
  });
}
