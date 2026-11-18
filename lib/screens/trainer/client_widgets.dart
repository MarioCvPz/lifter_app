import 'package:flutter/material.dart';

import '../../data/client_overview.dart';

/// Color de la nota de la semana según su nivel: verde (≥ 70), ámbar
/// (50–69) o rojizo (< 50). Son colores del tema, así que cambian con el
/// tema claro y el oscuro.
Color scoreColor(BuildContext context, int score) {
  final scheme = Theme.of(context).colorScheme;
  return switch (ScoreLevel.of(score)) {
    ScoreLevel.good => scheme.secondary,
    ScoreLevel.fair => scheme.tertiary,
    ScoreLevel.low => scheme.error,
  };
}

/// La nota de la semana dentro de un círculo de su color.
class ScoreCircle extends StatelessWidget {
  const ScoreCircle({super.key, required this.score, this.size = 44});

  final int score;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = scoreColor(context, score);
    return Semantics(
      label: 'Nota de la semana $score',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: FittedBox(
            child: Text(
              '$score',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo con las iniciales del cliente.
class ClientAvatar extends StatelessWidget {
  const ClientAvatar(this.client, {super.key, this.radius = 20});

  final ClientOverview client;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      child: Text(client.initials),
    );
  }
}

/// Un aviso del cliente con su icono, en el color de error del tema
/// (notas sin leer, en el color principal: no es algo malo).
class AlertLine extends StatelessWidget {
  const AlertLine(this.alert, {super.key});

  final ClientAlert alert;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (alert.kind) {
      ClientAlertKind.noTraining => (Icons.warning_amber_rounded, scheme.error),
      ClientAlertKind.noFood => (Icons.no_meals_outlined, scheme.error),
      ClientAlertKind.unreadNotes => (
        Icons.chat_bubble_outline,
        scheme.primary,
      ),
    };
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            alert.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
