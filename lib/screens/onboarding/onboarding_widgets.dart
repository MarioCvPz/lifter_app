import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Título y explicación corta que encabezan cada pregunta del cuestionario.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final sub = subtitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineSmall),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lista de opciones de las que se elige una sola (objetivo, actividad,
/// experiencia…). Es genérica (`<T>`), como un `List<T>` de Java: sirve
/// igual para un enum que para un texto.
class ChoiceList<T> extends StatelessWidget {
  const ChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.label,
    required this.onSelected,
    this.description,
  });

  final List<T> options;
  final T selected;

  /// Texto que se muestra para cada opción.
  final String Function(T option) label;

  /// Frase opcional debajo de cada opción.
  final String Function(T option)? description;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final describe = description;
    return Column(
      children: [
        for (final option in options)
          _ChoiceTile(
            title: label(option),
            subtitle: describe?.call(option),
            selected: option == selected,
            onTap: () => onSelected(option),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sub = subtitle;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        side: selected
            ? BorderSide(color: scheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        title: Text(title),
        subtitle: sub == null ? null : Text(sub),
        trailing: selected
            ? Icon(Icons.check_circle, color: scheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }
}
