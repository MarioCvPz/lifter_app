import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Gráfico de línea de los pesos (del más antiguo al más reciente) en
/// coral, con un área suave debajo. Se dibuja con CustomPaint, sin
/// paquetes. Lo usan la tarjeta de Perfil y la pantalla del historial.
class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.values, this.height = 80});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WeightChartPainter(
          values: values,
          background: Theme.of(context).colorScheme.surfaceContainer,
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  _WeightChartPainter({required this.values, required this.background});

  final List<double> values;

  /// Color de la tarjeta, para el centro de los puntos.
  final Color background;

  static const _stroke = 2.5;
  static const _dotRadius = 3.5;

  /// Margen para que la línea y los puntos no se corten en los bordes.
  static const _padding = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final points = _pointsFor(size);

    // Área bajo la línea: la misma línea cerrada por abajo, con un
    // degradado de coral a transparente.
    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }
    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.coral.withValues(alpha: 0.30),
            AppTheme.coral.withValues(alpha: 0),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = AppTheme.coral
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Puntos: coral con el centro del color de la tarjeta.
    for (final p in points) {
      canvas.drawCircle(p, _dotRadius, Paint()..color = AppTheme.coral);
      canvas.drawCircle(p, _dotRadius - 1.5, Paint()..color = background);
    }
  }

  /// Posición de cada valor. El más bajo queda abajo y el más alto arriba;
  /// si todos son iguales (o solo hay uno), la línea va por el centro.
  List<Offset> _pointsFor(Size size) {
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final width = size.width - 2 * _padding;
    final height = size.height - 2 * _padding;
    return [
      for (final (i, v) in values.indexed)
        Offset(
          values.length == 1
              ? size.width / 2
              : _padding + width * i / (values.length - 1),
          range == 0
              ? size.height / 2
              : _padding + height * (1 - (v - minValue) / range),
        ),
    ];
  }

  @override
  bool shouldRepaint(_WeightChartPainter old) =>
      !listEquals(old.values, values) || old.background != background;
}
