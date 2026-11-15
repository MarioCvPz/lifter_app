import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lifter_app/app.dart';
import 'package:lifter_app/data/app_store.dart';
import 'package:lifter_app/models/models.dart';

import 'helpers.dart';

void main() {
  test('CP-11 UserProfile.fromMap/toMap conserva los campos nuevos', () {
    final original = UserProfile(
      name: 'Ana',
      username: 'ana',
      email: 'ana@test.com',
      surname: 'García López',
      sex: 'Mujer',
      goal: TrainingGoal.bodyRecomposition,
      birthDate: DateTime(2000, 5, 17),
      activityLevel: ActivityLevel.active,
      trainingDays: const [1, 3, 5],
      sessionMinutes: 45,
      trainingPlace: TrainingPlace.home,
      injuries: const ['Rodilla'],
      onboardingCompleted: true,
    );

    final map = original.toMap();
    // En Firestore se guarda el nombre del enum, no el texto visible.
    expect(map['goal'], 'bodyRecomposition');
    expect(map['activityLevel'], 'active');
    expect(map['trainingPlace'], 'home');
    // El rol nunca se escribe desde la app.
    expect(map.containsKey('role'), isFalse);

    final read = UserProfile.fromMap(map);
    expect(read.surname, 'García López');
    expect(read.sex, 'Mujer');
    expect(read.goal, TrainingGoal.bodyRecomposition);
    expect(read.birthDate, DateTime(2000, 5, 17));
    expect(read.activityLevel, ActivityLevel.active);
    expect(read.trainingDays, [1, 3, 5]);
    expect(read.sessionMinutes, 45);
    expect(read.trainingPlace, TrainingPlace.home);
    expect(read.injuries, ['Rodilla']);
    expect(read.onboardingCompleted, isTrue);
  });

  test('CP-11 Un perfil antiguo sin los campos nuevos se lee sin fallar', () {
    final old = UserProfile.fromMap({
      'name': 'Luis',
      'username': 'luis',
      'email': 'luis@test.com',
      'sex': 'Otro',
      'heightCm': 180,
      'weightKg': 82.5,
      'goal': 'Hipertrofia',
      'daysPerWeek': 5,
    });

    expect(old.onboardingCompleted, isFalse);
    expect(old.sex, 'Hombre'); // 'Otro' ya no existe
    expect(old.heightCm, 180);
    expect(old.weightKg, 82.5);
    expect(old.goal, TrainingGoal.muscleGain);
    expect(old.surname, '');
    expect(old.birthDate, isNull);
    expect(old.age, isNull);
    expect(old.activityLevel, ActivityLevel.sedentary);
    expect(old.trainingDays, [1, 2, 3, 4]);
    expect(old.sessionMinutes, 60);
    expect(old.trainingPlace, TrainingPlace.gym);
    expect(old.injuries, isEmpty);
  });

  test('CP-11 Duración de la sesión: 30 min ya no existe y se lee como 45', () {
    expect(ProfileOptions.sessionMinutes, [45, 60, 90]);
    UserProfile read(int minutes) =>
        UserProfile.fromMap({'sessionMinutes': minutes});
    expect(read(30).sessionMinutes, 45);
    expect(read(45).sessionMinutes, 45);
    expect(read(90).sessionMinutes, 90);
    expect(ProfileOptions.sessionLabel(60), '60 min');
    expect(ProfileOptions.sessionLabel(90), '90 min o más');
  });

  test('CP-11 Material: "Kettlebell" ya no existe y se ignora al leer', () {
    expect(ProfileOptions.equipment, isNot(contains('Kettlebell')));
    final old = UserProfile.fromMap({
      'equipment': ['Barra', 'Kettlebell', 'Mancuernas'],
    });
    expect(old.equipment, ['Barra', 'Mancuernas']);
  });

  test('CP-11 TrainingGoal.fromName acepta los textos antiguos', () {
    expect(TrainingGoal.fromName('Hipertrofia'), TrainingGoal.muscleGain);
    expect(TrainingGoal.fromName('Pérdida de grasa'), TrainingGoal.fatLoss);
    expect(TrainingGoal.fromName('Fuerza'), TrainingGoal.strength);
    expect(TrainingGoal.fromName('Salud general'), TrainingGoal.generalHealth);
    // Nombres actuales del enum.
    expect(TrainingGoal.fromName('fatLoss'), TrainingGoal.fatLoss);
    expect(
      TrainingGoal.fromName('bodyRecomposition'),
      TrainingGoal.bodyRecomposition,
    );
    // Valor desconocido o ausente: salud general.
    expect(TrainingGoal.fromName('xyz'), TrainingGoal.generalHealth);
    expect(TrainingGoal.fromName(null), TrainingGoal.generalHealth);
  });

  test('CP-11 Cálculo de la edad', () {
    final today = DateTime.now();
    UserProfile bornOn(DateTime date) =>
        profile()..birthDate = DateTime(date.year - 30, date.month, date.day);

    // Hoy cumple 30.
    expect(bornOn(today).age, 30);
    // Su cumpleaños es mañana: todavía tiene 29.
    expect(bornOn(today.add(const Duration(days: 1))).age, 29);
    // Sin fecha de nacimiento no hay edad.
    expect(profile().age, isNull);
  });

  test('CP-11 Material por defecto de cada lugar de entrenamiento', () {
    expect(TrainingPlace.gym.defaultEquipment, ProfileOptions.equipment);
    expect(TrainingPlace.home.defaultEquipment, [
      'Mancuernas',
      'Bandas elásticas',
      'Peso corporal',
    ]);
    expect(TrainingPlace.outdoors.defaultEquipment, [
      'Peso corporal',
      'Bandas elásticas',
    ]);
    // Todo el material por defecto existe en las opciones.
    for (final place in TrainingPlace.values) {
      expect(ProfileOptions.equipment, containsAll(place.defaultEquipment));
    }
  });

  testWidgets('CP-11 Mientras no llega el perfil real se muestra la carga', (
    tester,
  ) async {
    // Perfil provisional: aún no se sabe si completó el cuestionario.
    final store = AppStore()..user = profile();
    await tester.pumpWidget(LifterApp(store: store));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.textContaining('Paso 1'), findsNothing);
  });

  testWidgets(
    'CP-11 Con el perfil sin completar se muestra el cuestionario y no se '
    'pasa del paso 1 sin nombre',
    (tester) async {
      final store = AppStore()
        ..user = profile()
        ..profileLoaded = true;
      await tester.pumpWidget(LifterApp(store: store));

      expect(find.text('Paso 1 de 8'), findsOneWidget);
      expect(find.text('¿Cómo te llamas?'), findsOneWidget);
      // El nombre viene rellenado del perfil.
      expect(find.widgetWithText(TextField, 'Ana'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Ana'), '   ');
      await tester.tap(find.text('Siguiente'));
      await tester.pump();

      expect(find.text('Escribe tu nombre.'), findsOneWidget);
      expect(find.text('Paso 1 de 8'), findsOneWidget);

      // Con nombre sí avanza.
      await tester.enterText(find.byType(TextField).first, 'Ana');
      await tester.tap(find.text('Siguiente'));
      await tester.pump();
      expect(find.text('Paso 2 de 8'), findsOneWidget);
    },
  );
}
