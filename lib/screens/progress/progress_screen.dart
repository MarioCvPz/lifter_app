import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/stats.dart';
import '../../data/week_summary.dart';
import '../../widgets/brand.dart';
import '../../widgets/coach_badge.dart';
import '../../widgets/help.dart';
import 'nutrition_week_card.dart';
import 'score_card.dart';
import 'steps_weight_cards.dart';
import 'week_selector.dart';
import 'workout_week_card.dart';

/// Pestaña Progreso ("Mi semana"), de arriba abajo: título con el selector
/// de semana, nota de la semana, entrenos, nutrición, y pasos y peso.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  /// Semana que se ve: 0 = esta, 1 = la pasada…
  int _weeksAgo = 0;

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final now = DateTime.now();
    final weeksBack = WeekSummary.weeksBackAllowed(store.accountCreatedAt, now);
    final thisMonday = WeekSummary.mondayOf(now);
    final monday = DateTime(
      thisMonday.year,
      thisMonday.month,
      thisMonday.day - 7 * _weeksAgo,
    );
    final summary = store.weekSummary(monday, today: now);

    return Scaffold(
      appBar: const BrandAppBar(title: 'Progreso', help: HelpTopic.progress),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mi semana',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              WeekSelector(
                label: WeekSummary.weekLabel(monday, now),
                onPrevious: _weeksAgo < weeksBack
                    ? () => setState(() => _weeksAgo++)
                    : null,
                onNext: _weeksAgo > 0
                    ? () => setState(() => _weeksAgo--)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          WeekScoreCard(
            summary: summary,
            // La semana anterior a la de crear la cuenta no cuenta.
            showChange: _weeksAgo < weeksBack,
          ),
          const SizedBox(height: 12),
          WorkoutWeekCard(summary: summary),
          const SizedBox(height: 12),
          NutritionWeekCard(summary: summary),
          const SizedBox(height: 12),
          StepsWeightRow(summary: summary, store: store),
          // Objetivo de pasos o calorías fijados por el entrenador.
          if (store.stepsByCoach || store.nutritionByCoach) ...[
            const SizedBox(height: 8),
            CoachBadge(
              label: store.coachLabel,
              onReset: store.hasAcceptedTrainer
                  ? null
                  : store.resetMyCoachSettings,
            ),
          ],
        ],
      ),
    );
  }
}
