import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/routine_generator.dart';
import '../../models/models.dart';
import '../../widgets/brand.dart';
import 'plan_view.dart';
import 'steps/activity_step.dart';
import 'steps/availability_step.dart';
import 'steps/equipment_step.dart';
import 'steps/experience_step.dart';
import 'steps/goal_step.dart';
import 'steps/injuries_step.dart';
import 'steps/personal_step.dart';
import 'steps/physical_step.dart';

/// Cuestionario inicial: una pregunta por pantalla, con barra de progreso y
/// botones "Atrás" y "Siguiente". Las respuestas se guardan en [_draft], una
/// copia del perfil, y no llegan a Firestore hasta pulsar "Empezar".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  /// Número de preguntas.
  static const _stepCount = 8;

  late UserProfile _draft;
  int _step = 0;
  bool _loaded = false;

  /// Plan generado con las respuestas al pulsar "Ver mi plan". Mientras es
  /// null se ven las preguntas; si no, "Tu plan". Es el mismo que se guarda
  /// al pulsar "Empezar", así que se guarda lo que el usuario ha visto.
  TrainingPlan? _plan;

  /// True mientras se guardan las respuestas en Firestore.
  bool _saving = false;

  /// Error del paso actual o del guardado. Se muestra encima de los
  /// botones (un SnackBar los taparía).
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    // app.dart solo abre esta pantalla con sesión, así que hay usuario.
    final user = SessionScope.of(context).user!;
    // Copia del perfil para no cambiar el del store hasta guardar.
    _draft = user.copy();
    // Los días por semana salen siempre de los días marcados.
    _draft.daysPerWeek = _draft.trainingDays.length;
    _loaded = true;
  }

  /// Error del paso actual, o null si se puede avanzar.
  String? _validateStep() => switch (_step) {
    0 => PersonalStep.validate(_draft),
    2 => PhysicalStep.validate(_draft),
    5 => AvailabilityStep.validate(_draft),
    6 => EquipmentStep.validate(_draft),
    _ => null,
  };

  void _next() {
    final error = _validateStep();
    final store = SessionScope.of(context);
    setState(() {
      _error = error;
      if (error != null) return;
      if (_step < _stepCount - 1) {
        _step++;
      } else {
        _plan = RoutineGenerator.generate(_draft, store.exercises);
      }
    });
  }

  /// "Cambiar respuestas": vuelve a la primera pregunta. Las respuestas se
  /// conservan, así que solo hay que cambiar lo que se quiera.
  void _changeAnswers() => setState(() {
    _error = null;
    _plan = null;
    _step = 0;
  });

  /// "Empezar": guarda el perfil. Si va bien, app.dart cambia solo a la
  /// pantalla principal porque el perfil ya tiene onboardingCompleted.
  Future<void> _start(TrainingPlan plan) async {
    // Se coge el store antes del await: después, el context puede no ser
    // válido.
    final store = SessionScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    _draft
      ..name = _draft.name.trim()
      ..surname = _draft.surname.trim();
    final error = await store.completeOnboarding(_draft, plan);
    // Si ha ido bien, esta pantalla ya no existe y no hay nada que hacer.
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  void _back() => setState(() {
    _error = null;
    _step--;
  });

  /// Redibuja la pantalla cuando un paso cambia una respuesta y quita el
  /// error, que ya puede no ser cierto.
  void _onChanged() => setState(() => _error = null);

  Widget _currentStep() {
    // La key hace que cada paso sea un widget nuevo: así sus campos de
    // texto se crean con los valores del borrador al volver atrás.
    final key = ValueKey(_step);
    return switch (_step) {
      0 => PersonalStep(key: key, profile: _draft, onChanged: _onChanged),
      1 => GoalStep(key: key, profile: _draft, onChanged: _onChanged),
      2 => PhysicalStep(key: key, profile: _draft, onChanged: _onChanged),
      3 => ActivityStep(key: key, profile: _draft, onChanged: _onChanged),
      4 => ExperienceStep(key: key, profile: _draft, onChanged: _onChanged),
      5 => AvailabilityStep(key: key, profile: _draft, onChanged: _onChanged),
      6 => EquipmentStep(key: key, profile: _draft, onChanged: _onChanged),
      _ => InjuriesStep(key: key, profile: _draft, onChanged: _onChanged),
    };
  }

  @override
  Widget build(BuildContext context) {
    final plan = _plan;
    return Scaffold(
      body: SafeArea(
        child: plan == null
            ? _questions()
            : PlanView(
                profile: _draft,
                plan: plan,
                saving: _saving,
                error: _error,
                onStart: () => _start(plan),
                onChangeAnswers: _changeAnswers,
              ),
      ),
    );
  }

  /// La pregunta actual con la barra de progreso y los botones.
  Widget _questions() {
    return Column(
      children: [
        _ProgressHeader(step: _step, stepCount: _stepCount),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _currentStep(),
          ),
        ),
        _NavigationButtons(
          error: _error,
          canGoBack: _step > 0,
          isLastStep: _step == _stepCount - 1,
          onBack: _back,
          onNext: _next,
        ),
      ],
    );
  }
}

/// "Paso X de N" y la barra de progreso.
class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step, required this.stepCount});

  final int step;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso ${step + 1} de $stepCount',
            style: text.labelLarge?.copyWith(color: scheme.secondary),
          ),
          const SizedBox(height: 8),
          ThinProgress(value: (step + 1) / stepCount),
        ],
      ),
    );
  }
}

/// Mensaje de error (si lo hay) y los botones "Atrás" y "Siguiente".
class _NavigationButtons extends StatelessWidget {
  const _NavigationButtons({
    required this.error,
    required this.canGoBack,
    required this.isLastStep,
    required this.onBack,
    required this.onNext,
  });

  final String? error;
  final bool canGoBack;

  /// En la última pregunta el botón dice "Ver mi plan".
  final bool isLastStep;
  final VoidCallback onBack;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final message = error;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error),
              ),
            ),
          _buttons(),
        ],
      ),
    );
  }

  Widget _buttons() {
    return Row(
      children: [
        if (canGoBack) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              child: const Text('Atrás'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: FilledButton(
            onPressed: onNext,
            child: Text(isLastStep ? 'Ver mi plan' : 'Siguiente'),
          ),
        ),
      ],
    );
  }
}
