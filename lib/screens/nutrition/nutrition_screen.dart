import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../models/models.dart';
import '../../widgets/brand.dart';
import '../../widgets/coach_badge.dart';
import '../../widgets/help.dart';
import 'food_catalog_screen.dart';
import 'food_category_icon.dart';
import 'macro_summary_card.dart';

/// Pantalla de Nutrición: día elegido, resumen de calorías y macros, y lo
/// que se ha comido ese día. Los alimentos se añaden desde el catálogo
/// ([FoodCatalogScreen]), que se abre con el botón "Añadir alimento".
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  DateTime _day = DateTime.now();

  bool get _isToday => DateUtils.isSameDay(_day, DateTime.now());

  void _moveDay(int delta) {
    setState(() => _day = _day.add(Duration(days: delta)));
  }

  String _dayLabel() {
    final now = DateTime.now();
    if (_isToday) return 'Hoy';
    if (DateUtils.isSameDay(_day, now.subtract(const Duration(days: 1)))) {
      return 'Ayer';
    }
    return '${_day.day.toString().padLeft(2, '0')}/'
        '${_day.month.toString().padLeft(2, '0')}/${_day.year}';
  }

  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FoodCatalogScreen(day: _day, dayLabel: _dayLabel()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final logs = store.nutritionFor(_day);

    return Scaffold(
      appBar: const BrandAppBar(title: 'Nutrición', help: HelpTopic.nutrition),
      floatingActionButton: FloatingActionButton.extended(
        // Sin animación Hero: las pestañas viven a la vez en un IndexedStack
        // y Entrenos ya tiene otro botón flotante con la etiqueta por defecto.
        // Dos Hero con la misma etiqueta dan error al abrir otra pantalla.
        heroTag: null,
        onPressed: _openCatalog,
        icon: const Icon(Icons.add),
        label: const Text('Añadir alimento'),
      ),
      body: ListView(
        // Abajo deja sitio para que el botón no tape el último registro.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          _DaySelector(
            label: _dayLabel(),
            onPrevious: () => _moveDay(-1),
            onNext: _isToday ? null : () => _moveDay(1),
          ),
          const SizedBox(height: 8),
          MacroSummaryCard(
            macros: store.macrosFor(_day),
            targets: store.macroTargets(),
          ),
          if (store.nutritionByCoach) ...[
            const SizedBox(height: 8),
            CoachBadge(
              label: store.coachLabel,
              // Sin entrenador, el usuario puede volver a sus cálculos.
              onReset: store.hasAcceptedTrainer
                  ? null
                  : store.resetMyCoachSettings,
            ),
          ],
          const SizedBox(height: 20),
          _LogsHeader(isToday: _isToday, count: logs.length),
          const SizedBox(height: 8),
          if (logs.isEmpty) const _NoLogs(),
          for (final e in logs)
            _EntryTile(entry: e, onRemove: () => store.removeNutrition(e.id)),
        ],
      ),
    );
  }
}

/// Flechas para cambiar de día y el día en el centro.
class _DaySelector extends StatelessWidget {
  const _DaySelector({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;

  /// Null cuando ya se está viendo hoy (no se puede ir al futuro).
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Día anterior',
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_today, size: 18),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Día siguiente',
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _LogsHeader extends StatelessWidget {
  const _LogsHeader({required this.isToday, required this.count});

  final bool isToday;
  final int count;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        const Icon(Icons.restaurant_menu, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isToday ? 'Registros de hoy' : 'Registros del día',
            style: text.titleMedium,
          ),
        ),
        if (count > 0) Text('$count', style: text.labelMedium),
      ],
    );
  }
}

class _NoLogs extends StatelessWidget {
  const _NoLogs();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.no_food_outlined, size: 40, color: scheme.outline),
            const SizedBox(height: 8),
            const Text(
              'No hay alimentos registrados este día.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Un alimento apuntado: icono de su categoría, gramos, calorías y macros.
class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.onRemove});

  final NutritionEntry entry;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return Card(
      child: ListTile(
        leading: FoodAvatar(e.food.category),
        title: Text(e.food.name),
        subtitle: Text(
          '${e.grams.toStringAsFixed(0)} g · ${e.kcal.toStringAsFixed(0)} kcal'
          ' · P ${e.protein.toStringAsFixed(0)} · '
          'H ${e.carbs.toStringAsFixed(0)} · G ${e.fat.toStringAsFixed(0)}',
        ),
        trailing: IconButton(
          tooltip: 'Quitar',
          icon: const Icon(Icons.delete_outline),
          onPressed: onRemove,
        ),
      ),
    );
  }
}
