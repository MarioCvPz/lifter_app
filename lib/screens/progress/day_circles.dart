import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/models.dart';

/// Tamaño de cada círculo de día.
const dayCircleSize = 32.0;

/// Tarjeta de Progreso con título, contador a la derecha ("3 de 4"), los
/// siete círculos de la semana y, opcionalmente, algo debajo (la leyenda).
/// La usan las tarjetas de Entrenos y de Nutrición.
class WeekDaysCard extends StatelessWidget {
  const WeekDaysCard({
    super.key,
    required this.title,
    required this.count,
    required this.circles,
    this.footer,
  });

  final String title;
  final String count;

  /// Siete círculos, de lunes a domingo.
  final List<Widget> circles;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final extra = footer;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: text.titleMedium)),
                Text(count, style: text.labelLarge),
              ],
            ),
            const SizedBox(height: 12),
            _WeekRow(circles: circles),
            if (extra != null) ...[const SizedBox(height: 12), extra],
          ],
        ),
      ),
    );
  }
}

/// Los siete círculos con la letra del día (L … D) debajo.
class _WeekRow extends StatelessWidget {
  const _WeekRow({required this.circles});

  final List<Widget> circles;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final (i, circle) in circles.indexed)
          Column(
            children: [
              circle,
              const SizedBox(height: 4),
              Text(ProfileOptions.weekdayLabels[i], style: style),
            ],
          ),
      ],
    );
  }
}

/// Círculo de un día: relleno ([fill]) o solo con borde ([border]), y con
/// un icono o un texto pequeño dentro.
class DayCircle extends StatelessWidget {
  const DayCircle({
    super.key,
    this.fill,
    this.border,
    this.dashed = false,
    this.child,
  });

  final Color? fill;
  final Color? border;

  /// Borde discontinuo (entreno pendiente).
  final bool dashed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final borderColor = border;
    final circle = Container(
      width: dayCircleSize,
      height: dayCircleSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: borderColor == null || dashed
            ? null
            : Border.all(color: borderColor, width: 2),
      ),
      child: child,
    );
    if (!dashed || borderColor == null) return circle;
    return CustomPaint(
      painter: _DashedCirclePainter(color: borderColor),
      child: circle,
    );
  }
}

/// Dibuja un círculo discontinuo: pequeños arcos con huecos entre ellos.
class _DashedCirclePainter extends CustomPainter {
  _DashedCirclePainter({required this.color});

  final Color color;

  static const _dashes = 10;
  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    const step = math.pi * 2 / _dashes;
    for (var i = 0; i < _dashes; i++) {
      // Cada trozo ocupa la mitad de su parte: la otra mitad es hueco.
      canvas.drawArc(rect, i * step, step / 2, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

/// Punto gris pequeño (día de descanso).
class RestDot extends StatelessWidget {
  const RestDot({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: dayCircleSize,
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }
}

/// Una entrada de la leyenda: el círculo pequeño y su texto.
class LegendItem extends StatelessWidget {
  const LegendItem({super.key, required this.circle, required this.label});

  final Widget circle;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // La leyenda usa los mismos círculos, pero a la mitad de tamaño.
        SizedBox.square(
          dimension: dayCircleSize / 2,
          child: FittedBox(child: circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
