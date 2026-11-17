import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/week_summary.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';

/// Tarjeta resumen: tres anillos con la nota en el centro, las tres filas
/// (entrenos, nutrición y pasos), la comparación con la semana anterior y
/// el consejo.
class WeekScoreCard extends StatelessWidget {
  const WeekScoreCard({
    super.key,
    required this.summary,
    required this.showChange,
  });

  final WeekSummary summary;

  /// False si la semana anterior es de antes de crear la cuenta: no tiene
  /// sentido compararse con ella.
  final bool showChange;

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.secondary;
    final rings = [
      (summary.workoutScore, AppTheme.coral),
      (summary.nutritionScore, green),
      (summary.stepsPercent / 100, AppTheme.stepsBlue),
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ScoreRings(score: summary.score, rings: rings),
                const SizedBox(width: 16),
                Expanded(
                  child: _ScoreRows(summary: summary, green: green),
                ),
              ],
            ),
            if (showChange) ...[
              const SizedBox(height: 12),
              _ScoreChange(change: summary.scoreChange),
            ],
            const SizedBox(height: 12),
            _AdviceBox(advice: summary.advice),
          ],
        ),
      ),
    );
  }
}

/// Tres anillos concéntricos (de fuera a dentro, los de [rings]) con la
/// nota en el centro.
class _ScoreRings extends StatelessWidget {
  const _ScoreRings({required this.score, required this.rings});

  final int score;

  /// Progreso (de 0 a 1) y color de cada anillo.
  final List<(double, Color)> rings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: 112,
      child: CustomPaint(
        painter: _RingsPainter(
          rings: rings,
          track: scheme.onSurface.withValues(alpha: 0.08),
        ),
        child: Center(
          child: Text(
            '$score',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({required this.rings, required this.track});

  final List<(double, Color)> rings;
  final Color track;

  static const _stroke = 9.0;
  static const _gap = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    var rect = (Offset.zero & size).deflate(_stroke / 2);
    for (final (progress, color) in rings) {
      // Primero el fondo del anillo y encima el progreso, empezando arriba
      // (−90°) y en el sentido de las agujas del reloj.
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        paint..color = color,
      );
      rect = rect.deflate(_stroke + _gap); // el siguiente, más pequeño
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      !listEquals(old.rings, rings) || old.track != track;
}

/// "NOTA DE LA SEMANA" y las filas Entrenos 3/4, Nutrición 5/7, Pasos 72 %.
class _ScoreRows extends StatelessWidget {
  const _ScoreRows({required this.summary, required this.green});

  final WeekSummary summary;
  final Color green;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTA DE LA SEMANA',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        _ScoreRow(
          color: AppTheme.coral,
          label: 'Entrenos',
          value: '${summary.doneWorkouts}/${summary.plannedWorkouts}',
        ),
        _ScoreRow(
          color: green,
          label: 'Nutrición',
          value: '${summary.nutritionDaysLogged}/${WeekSummary.daysInWeek}',
        ),
        _ScoreRow(
          color: AppTheme.stepsBlue,
          label: 'Pasos',
          value: '${summary.stepsPercent.round()} %',
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(value, style: text.titleSmall),
        ],
      ),
    );
  }
}

/// Flecha de subida, de bajada o guion si no cambia. Es un icono y no los
/// caracteres ▲ ▼, porque la fuente de la app no los tiene: el sistema los
/// dibuja con otra fuente de medidas distintas y la tarjeta se descuadra.
IconData trendIcon(num change) => change > 0
    ? Icons.arrow_drop_up
    : (change < 0 ? Icons.arrow_drop_down : Icons.remove);

/// "▲ 8 vs semana anterior" (verde), "▼ 5 …" (rojiza) o "– …" (gris).
class _ScoreChange extends StatelessWidget {
  const _ScoreChange({required this.change});

  final int change;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = change > 0
        ? scheme.secondary
        : (change < 0 ? AppTheme.danger : scheme.onSurfaceVariant);
    // En pantallas estrechas el texto se encoge en vez de salirse.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: StatusPill(
        icon: trendIcon(change),
        label: '${change.abs()} vs semana anterior',
        color: color,
      ),
    );
  }
}

class _AdviceBox extends StatelessWidget {
  const _AdviceBox({required this.advice});

  final String advice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, size: 18, color: scheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(advice, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
