import '../models/models.dart';

// Catálogo fijo de la app: no se guarda en Firestore, va en el código.

const List<Exercise> exerciseCatalog = [
  Exercise(
    id: 'ex1',
    name: 'Press de banca',
    muscleGroup: 'Pecho',
    equipment: 'Barra',
    level: 'Intermedio',
  ),
  Exercise(
    id: 'ex2',
    name: 'Sentadilla',
    muscleGroup: 'Piernas',
    equipment: 'Barra',
    level: 'Intermedio',
  ),
  Exercise(
    id: 'ex3',
    name: 'Peso muerto',
    muscleGroup: 'Espalda',
    equipment: 'Barra',
    level: 'Avanzado',
  ),
  Exercise(
    id: 'ex4',
    name: 'Dominadas',
    muscleGroup: 'Espalda',
    equipment: 'Peso corporal',
    level: 'Intermedio',
  ),
  Exercise(
    id: 'ex5',
    name: 'Press militar',
    muscleGroup: 'Hombros',
    equipment: 'Barra',
    level: 'Intermedio',
  ),
  Exercise(
    id: 'ex6',
    name: 'Remo con barra',
    muscleGroup: 'Espalda',
    equipment: 'Barra',
    level: 'Intermedio',
  ),
  Exercise(
    id: 'ex7',
    name: 'Curl de bíceps',
    muscleGroup: 'Brazos',
    equipment: 'Mancuernas',
    level: 'Principiante',
  ),
  Exercise(
    id: 'ex8',
    name: 'Extensión de tríceps',
    muscleGroup: 'Brazos',
    equipment: 'Polea',
    level: 'Principiante',
  ),
  Exercise(
    id: 'ex9',
    name: 'Zancadas',
    muscleGroup: 'Piernas',
    equipment: 'Mancuernas',
    level: 'Principiante',
  ),
  Exercise(
    id: 'ex10',
    name: 'Plancha',
    muscleGroup: 'Core',
    equipment: 'Peso corporal',
    level: 'Principiante',
  ),
];

const List<Food> foodCatalog = [
  Food(
    id: 'f1',
    name: 'Pechuga de pollo',
    kcalPer100: 110,
    proteinPer100: 23,
    carbsPer100: 0,
    fatPer100: 1.5,
  ),
  Food(
    id: 'f2',
    name: 'Arroz blanco cocido',
    kcalPer100: 130,
    proteinPer100: 2.7,
    carbsPer100: 28,
    fatPer100: 0.3,
  ),
  Food(
    id: 'f3',
    name: 'Huevo entero',
    kcalPer100: 143,
    proteinPer100: 13,
    carbsPer100: 1.1,
    fatPer100: 9.5,
  ),
  Food(
    id: 'f4',
    name: 'Plátano',
    kcalPer100: 89,
    proteinPer100: 1.1,
    carbsPer100: 23,
    fatPer100: 0.3,
  ),
  Food(
    id: 'f5',
    name: 'Avena',
    kcalPer100: 379,
    proteinPer100: 13,
    carbsPer100: 67,
    fatPer100: 6.5,
  ),
  Food(
    id: 'f6',
    name: 'Yogur griego',
    kcalPer100: 97,
    proteinPer100: 9,
    carbsPer100: 3.6,
    fatPer100: 5,
  ),
];

final List<Routine> routineTemplates = [
  Routine(
    id: 'tpl-full',
    name: 'Full body 3 días',
    description: 'Plantilla para 3 días semanales. Cuerpo completo.',
    templateName: 'Full body',
    isTemplate: true,
    exercises: [
      exerciseCatalog[1],
      exerciseCatalog[0],
      exerciseCatalog[3],
      exerciseCatalog[9],
    ],
  ),
  Routine(
    id: 'tpl-ul',
    name: 'Torso / Pierna',
    description: 'Plantilla de 4 días: dos de torso y dos de pierna.',
    templateName: 'Torso/Pierna',
    isTemplate: true,
    exercises: [
      exerciseCatalog[0],
      exerciseCatalog[5],
      exerciseCatalog[1],
      exerciseCatalog[2],
    ],
  ),
  Routine(
    id: 'tpl-ppl',
    name: 'Push / Pull / Legs',
    description: 'Plantilla de 6 días o 3 días según disponibilidad.',
    templateName: 'Push/Pull/Legs',
    isTemplate: true,
    exercises: [
      exerciseCatalog[0],
      exerciseCatalog[4],
      exerciseCatalog[5],
      exerciseCatalog[1],
    ],
  ),
];
