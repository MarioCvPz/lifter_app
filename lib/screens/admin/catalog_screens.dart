import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/catalog.dart';
import '../../models/models.dart';
import '../onboarding/steps/injuries_step.dart';
import '../routines/routine_widgets.dart';

/// Pantallas del admin para editar el catálogo de Firestore: alimentos,
/// ejercicios y plantillas de rutina. Los cambios los ven todos al momento.

void _snack(BuildContext context, String? error, String ok) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(error ?? ok)));
}

Future<bool> _confirmDelete(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Borrar del catálogo?'),
      content: Text(
        'Se borrará "$name". Los registros que ya lo usan no cambian.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Borrar'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Lista con buscador, botón de añadir y acciones de editar y borrar.
class _CatalogList<T> extends StatefulWidget {
  const _CatalogList({
    required this.title,
    required this.items,
    required this.name,
    required this.subtitle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final List<T> items;
  final String Function(T) name;
  final String Function(T) subtitle;
  final VoidCallback onAdd;
  final void Function(T) onEdit;
  final void Function(T) onDelete;

  @override
  State<_CatalogList<T>> createState() => _CatalogListState<T>();
}

class _CatalogListState<T> extends State<_CatalogList<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final visible = widget.items
        .where((i) => q.isEmpty || widget.name(i).toLowerCase().contains(q))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: widget.onAdd,
        icon: const Icon(Icons.add),
        label: const Text('Añadir'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          TextField(
            onChanged: (v) => setState(() => _q = v),
            decoration: const InputDecoration(
              hintText: 'Buscar',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No hay nada todavía.', textAlign: TextAlign.center),
            ),
          for (final item in visible)
            Card(
              child: ListTile(
                title: Text(widget.name(item)),
                subtitle: Text(widget.subtitle(item)),
                onTap: () => widget.onEdit(item),
                trailing: IconButton(
                  tooltip: 'Borrar',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => widget.onDelete(item),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- Alimentos --

class FoodsAdminScreen extends StatelessWidget {
  const FoodsAdminScreen({super.key});

  Future<void> _edit(BuildContext context, [Food? food]) async {
    final store = SessionScope.of(context);
    final result = await showDialog<Food>(
      context: context,
      builder: (_) => _FoodDialog(
        food: food,
        newId: () => store.newCatalogId(CatalogCollections.foods),
      ),
    );
    if (result == null || !context.mounted) return;
    final error = await store.saveFood(result);
    if (context.mounted) _snack(context, error, 'Alimento guardado.');
  }

  Future<void> _delete(BuildContext context, Food food) async {
    final store = SessionScope.of(context);
    if (!await _confirmDelete(context, food.name)) return;
    final error = await store.deleteFood(food.id);
    if (context.mounted) _snack(context, error, 'Alimento borrado.');
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    return _CatalogList<Food>(
      title: 'Alimentos',
      items: store.foods,
      name: (f) => f.name,
      subtitle: (f) =>
          '${f.category.label} · ${_n(f.kcalPer100)} kcal · P ${_n(f.proteinPer100)} g · '
          'H ${_n(f.carbsPer100)} g · G ${_n(f.fatPer100)} g (por 100 g)',
      onAdd: () => _edit(context),
      onEdit: (f) => _edit(context, f),
      onDelete: (f) => _delete(context, f),
    );
  }
}

class _FoodDialog extends StatefulWidget {
  const _FoodDialog({required this.food, required this.newId});

  final Food? food;
  final String Function() newId;

  @override
  State<_FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<_FoodDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.food?.name);
  late final _kcal = TextEditingController(text: _n(widget.food?.kcalPer100));
  late final _protein = TextEditingController(
    text: _n(widget.food?.proteinPer100),
  );
  late final _carbs = TextEditingController(text: _n(widget.food?.carbsPer100));
  late final _fat = TextEditingController(text: _n(widget.food?.fatPer100));
  late FoodCategory _category = widget.food?.category ?? FoodCategory.other;

  @override
  void dispose() {
    for (final c in [_name, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Food(
        id: widget.food?.id ?? widget.newId(),
        name: _name.text.trim(),
        kcalPer100: _parse(_kcal.text)!,
        proteinPer100: _parse(_protein.text)!,
        carbsPer100: _parse(_carbs.text)!,
        fatPer100: _parse(_fat.text)!,
        category: _category,
      ),
    );
  }

  Widget _number(TextEditingController c, String label) => TextFormField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (v) {
      final n = _parse(v ?? '');
      if (n == null || n < 0) return 'Número ≥ 0';
      return null;
    },
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food == null ? 'Nuevo alimento' : 'Editar alimento'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Pon un nombre' : null,
                ),
                DropdownButtonFormField<FoodCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Categoría'),
                  items: [
                    for (final c in FoodCategory.values)
                      DropdownMenuItem(value: c, child: Text(c.label)),
                  ],
                  onChanged: (c) {
                    if (c != null) setState(() => _category = c);
                  },
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Valores por cada 100 g'),
                ),
                _number(_kcal, 'Calorías (kcal)'),
                _number(_protein, 'Proteínas (g)'),
                _number(_carbs, 'Hidratos (g)'),
                _number(_fat, 'Grasas (g)'),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

// ------------------------------------------------------------- Ejercicios --

class ExercisesAdminScreen extends StatelessWidget {
  const ExercisesAdminScreen({super.key});

  Future<void> _edit(BuildContext context, [Exercise? exercise]) async {
    final store = SessionScope.of(context);
    final result = await showDialog<Exercise>(
      context: context,
      builder: (_) => _ExerciseDialog(
        exercise: exercise,
        groups: store.muscleGroups,
        equipment: {for (final e in store.exercises) e.equipment}.toList()
          ..sort(),
        newId: () => store.newCatalogId(CatalogCollections.exercises),
      ),
    );
    if (result == null || !context.mounted) return;
    final error = await store.saveExercise(result);
    if (context.mounted) _snack(context, error, 'Ejercicio guardado.');
  }

  Future<void> _delete(BuildContext context, Exercise exercise) async {
    final store = SessionScope.of(context);
    if (!await _confirmDelete(context, exercise.name)) return;
    final error = await store.deleteExercise(exercise);
    if (context.mounted) _snack(context, error, 'Ejercicio borrado.');
  }

  /// "Pecho · Barra · Intermedio", y debajo el patrón y el tipo. Si el
  /// ejercicio aún no tiene patrón (copia antigua), lo avisa para que el
  /// admin lo complete.
  static String _subtitle(Exercise e) {
    final type = e.isCompound ? 'Multiarticular' : 'Aislamiento';
    final generator = e.pattern == MovementPattern.other
        ? 'Sin patrón: edítalo para el generador'
        : '${e.pattern.label} · $type';
    return '${e.muscleGroup} · ${e.equipment} · ${e.level}\n$generator';
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    return _CatalogList<Exercise>(
      title: 'Ejercicios',
      items: store.exercises,
      name: (e) => e.name,
      subtitle: _subtitle,
      onAdd: () => _edit(context),
      onEdit: (e) => _edit(context, e),
      onDelete: (e) => _delete(context, e),
    );
  }
}

class _ExerciseDialog extends StatefulWidget {
  const _ExerciseDialog({
    required this.exercise,
    required this.groups,
    required this.equipment,
    required this.newId,
  });

  final Exercise? exercise;
  final List<String> groups;
  final List<String> equipment;
  final String Function() newId;

  @override
  State<_ExerciseDialog> createState() => _ExerciseDialogState();
}

class _ExerciseDialogState extends State<_ExerciseDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.exercise?.name);
  late final _group = TextEditingController(text: widget.exercise?.muscleGroup);
  late final _equipment = TextEditingController(
    text: widget.exercise?.equipment,
  );
  late String _level = widget.exercise?.level ?? Routine.levels.first;

  // Datos para el generador de rutinas. Un ejercicio antiguo tiene el
  // patrón "otro": se deja sin elegir para obligar a escoger uno.
  late MovementPattern? _pattern =
      widget.exercise?.pattern == MovementPattern.other
      ? null
      : widget.exercise?.pattern;
  late bool _isCompound = widget.exercise?.isCompound ?? true;
  late List<String> _zones = widget.exercise?.stressedZones ?? const [];

  @override
  void dispose() {
    _name.dispose();
    _group.dispose();
    _equipment.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      Exercise(
        id: widget.exercise?.id ?? widget.newId(),
        name: _name.text.trim(),
        muscleGroup: _group.text.trim(),
        equipment: _equipment.text.trim(),
        level: _level,
        // El validador del desplegable asegura que hay patrón.
        pattern: _pattern ?? MovementPattern.other,
        isCompound: _isCompound,
        stressedZones: _zones,
      ),
    );
  }

  /// Patrón, tipo y zonas: los datos que usa el generador de rutinas.
  Widget _generatorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<MovementPattern>(
          initialValue: _pattern,
          // Ocupa el ancho del diálogo y recorta los textos largos.
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Patrón de movimiento'),
          items: [
            for (final p in MovementPattern.values)
              if (p != MovementPattern.other)
                DropdownMenuItem(value: p, child: Text(p.label)),
          ],
          validator: (p) => p == null ? 'Elige un patrón' : null,
          onChanged: (p) => setState(() => _pattern = p),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Multiarticular'),
          subtitle: Text(
            _isCompound
                ? 'Mueve varias articulaciones (p. ej. sentadilla)'
                : 'Aislamiento: una articulación (p. ej. curl)',
          ),
          value: _isCompound,
          onChanged: (v) => setState(() => _isCompound = v),
        ),
        const Text('Zonas que carga'),
        const SizedBox(height: 4),
        // Los mismos chips que las lesiones del cuestionario.
        InjuryPicker(
          selected: _zones,
          onChanged: (zones) => setState(() => _zones = zones),
        ),
      ],
    );
  }

  /// Campo de texto con sugerencias de los valores que ya existen.
  Widget _withSuggestions(
    TextEditingController c,
    String label,
    List<String> options,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: c,
          decoration: InputDecoration(labelText: label),
          validator: (v) => (v ?? '').trim().isEmpty ? 'Obligatorio' : null,
        ),
        if (options.isNotEmpty)
          Wrap(
            spacing: 6,
            children: [
              for (final o in options)
                ActionChip(
                  label: Text(o),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setState(() => c.text = o),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.exercise == null ? 'Nuevo ejercicio' : 'Editar ejercicio',
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Pon un nombre' : null,
                ),
                const SizedBox(height: 8),
                _withSuggestions(_group, 'Grupo muscular', widget.groups),
                const SizedBox(height: 8),
                _withSuggestions(_equipment, 'Material', widget.equipment),
                const SizedBox(height: 12),
                const Text('Nivel'),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: [
                    for (final l in Routine.levels)
                      ButtonSegment(value: l, label: Text(l)),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) => setState(() => _level = s.first),
                ),
                const SizedBox(height: 12),
                _generatorFields(),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

// ------------------------------------------------------------- Plantillas --

class TemplatesAdminScreen extends StatelessWidget {
  const TemplatesAdminScreen({super.key});

  Future<void> _edit(BuildContext context, [Routine? template]) async {
    final store = SessionScope.of(context);
    final result = await showRoutineEditor(
      context,
      exercises: store.exercises,
      title: template == null ? 'Nueva plantilla' : 'Editar plantilla',
      templateName: 'Plantilla',
      initial: template,
      askRecommendedDays: true,
    );
    if (result == null || !context.mounted) return;
    final toSave = template == null
        ? Routine(
            id: store.newCatalogId(CatalogCollections.templates),
            name: result.name,
            description: result.description,
            templateName: result.templateName,
            exercises: result.exercises,
            isTemplate: true,
            recommendedDays: result.recommendedDays,
          )
        : result;
    final error = await store.saveTemplate(toSave);
    if (context.mounted) _snack(context, error, 'Plantilla guardada.');
  }

  Future<void> _delete(BuildContext context, Routine template) async {
    final store = SessionScope.of(context);
    if (!await _confirmDelete(context, template.name)) return;
    final error = await store.deleteTemplate(template.id);
    if (context.mounted) _snack(context, error, 'Plantilla borrada.');
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    return _CatalogList<Routine>(
      title: 'Plantillas de rutina',
      items: store.templates,
      name: (r) => r.name,
      subtitle: (r) =>
          '${r.templateName} · ${r.exercises.length} ejercicios · '
          '${r.recommendedDays == null ? 'sin días' : '${r.recommendedDays} días/sem'}',
      onAdd: () => _edit(context),
      onEdit: (r) => _edit(context, r),
      onDelete: (r) => _delete(context, r),
    );
  }
}

// ------------------------------------------------------------------ Util --

double? _parse(String v) => double.tryParse(v.trim().replaceAll(',', '.'));

String _n(double? v) {
  if (v == null) return '';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v';
}
