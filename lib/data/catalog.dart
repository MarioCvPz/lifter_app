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
