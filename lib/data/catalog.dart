import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/models.dart';

// El catálogo (ejercicios, alimentos y plantillas de rutina) vive en Firestore,
// en las colecciones `exercises`, `foods` y `routineTemplates`. La app lo lee
// desde AppStore y los admins lo editan desde su panel.
//
// Este archivo solo sirve para la carga inicial: lee los datos de
// assets/seed/catalog.json para que un admin los suba con un botón cuando la
// base de datos está vacía.

/// Nombres de las colecciones del catálogo en Firestore.
abstract final class CatalogCollections {
  static const exercises = 'exercises';
  static const foods = 'foods';
  static const templates = 'routineTemplates';
}

class CatalogSeed {
  const CatalogSeed({
    required this.exercises,
    required this.foods,
    required this.templates,
  });

  final List<Exercise> exercises;
  final List<Food> foods;
  final List<Routine> templates;

  static const assetPath = 'assets/seed/catalog.json';

  static Future<CatalogSeed> load() async {
    final json = await rootBundle.loadString(assetPath);
    return CatalogSeed.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  factory CatalogSeed.fromJson(Map<String, dynamic> m) {
    final exercises = [
      for (final e in m['exercises'] as List)
        Exercise.fromMap(Map<String, dynamic>.from(e)),
    ];
    final byId = {for (final e in exercises) e.id: e};
    return CatalogSeed(
      exercises: exercises,
      foods: [
        for (final f in m['foods'] as List)
          Food.fromMap(Map<String, dynamic>.from(f)),
      ],
      templates: [
        for (final t in m['routineTemplates'] as List)
          Routine(
            id: t['id'] as String,
            name: t['name'] as String,
            description: t['description'] as String? ?? '',
            templateName: t['templateName'] as String? ?? 'Plantilla',
            recommendedDays: (t['recommendedDays'] as num?)?.toInt(),
            isTemplate: true,
            exercises: [
              for (final id in t['exerciseIds'] as List) byId[id as String]!,
            ],
          ),
      ],
    );
  }
}

/// Grupos musculares del catálogo, en el orden en que se muestran en las
/// listas de ejercicios.
const muscleGroups = [
  'Pecho',
  'Espalda',
  'Hombros',
  'Brazos',
  'Piernas',
  'Core',
];

/// Ejercicios agrupados por músculo: los grupos en el orden de
/// [muscleGroups] (y al final cualquier otro que haya en Firestore), y
/// dentro de cada uno por orden alfabético. Un `Map` de Dart recuerda el
/// orden en que se añaden las claves (como un `LinkedHashMap` de Java).
Map<String, List<Exercise>> exercisesByMuscle(List<Exercise> exercises) {
  final others = {
    for (final e in exercises)
      if (!muscleGroups.contains(e.muscleGroup)) e.muscleGroup,
  }.toList()..sort();
  final groups = <String, List<Exercise>>{};
  for (final group in [...muscleGroups, ...others]) {
    final inGroup = [
      for (final e in exercises)
        if (e.muscleGroup == group) e,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (inGroup.isNotEmpty) groups[group] = inGroup;
  }
  return groups;
}

/// Quita mayúsculas y tildes para comparar textos: así "platano" encuentra
/// "Plátano".
String _plain(String text) {
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  var result = text.trim().toLowerCase();
  accents.forEach((accent, letter) {
    result = result.replaceAll(accent, letter);
  });
  return result;
}

/// Alimentos cuyo nombre contiene [query] (sin distinguir mayúsculas ni
/// tildes) y que son de la categoría [category] (null = todas), ordenados
/// por nombre.
List<Food> filterFoods(
  List<Food> foods, {
  String query = '',
  FoodCategory? category,
}) {
  final text = _plain(query);
  return [
    for (final f in foods)
      if (_plain(f.name).contains(text) &&
          (category == null || f.category == category))
        f,
  ]..sort((a, b) => _plain(a.name).compareTo(_plain(b.name)));
}

/// Categorías que tienen al menos un alimento, en el orden de
/// [FoodCategory]. Así no salen filtros que no darían ningún resultado.
List<FoodCategory> foodCategoriesIn(List<Food> foods) {
  final used = {for (final f in foods) f.category};
  return [
    for (final c in FoodCategory.values)
      if (used.contains(c)) c,
  ];
}

/// Ejercicios cuyo nombre contiene [query] (sin distinguir mayúsculas) y
/// que son del grupo [group] (null = todos).
List<Exercise> filterExercises(
  List<Exercise> exercises, {
  String query = '',
  String? group,
}) {
  final text = query.trim().toLowerCase();
  return [
    for (final e in exercises)
      if (e.name.toLowerCase().contains(text) &&
          (group == null || e.muscleGroup == group))
        e,
  ];
}
