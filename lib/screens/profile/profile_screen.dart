import 'package:flutter/material.dart';

import '../../data/achievements.dart';
import '../../data/app_store.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import '../admin/admin_screen.dart';
import '../trainer/trainer_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final user = store.user!;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final achievements = achievementsFor(store);
    final unlocked = achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: const BrandAppBar(title: 'Perfil', help: HelpTopic.profile),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // --- Cabecera: foto, nombre y correo ---
          Center(
            child: _Avatar(name: user.name, photoUrl: store.photoUrl),
          ),
          const SizedBox(height: 12),
          Text(
            user.name.isEmpty ? 'Sin nombre' : user.name,
            textAlign: TextAlign.center,
            style: text.headlineMedium,
          ),
          if (user.username.isNotEmpty)
            Text(
              '@${user.username}',
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: scheme.secondary),
            ),
          const SizedBox(height: 2),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (user.role != UserRole.user) ...[
            const SizedBox(height: 8),
            Center(
              child: StatusPill(
                label: user.role.label,
                color: scheme.tertiary,
                icon: user.role == UserRole.admin
                    ? Icons.admin_panel_settings
                    : Icons.sports,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: () => _push(context, const EditProfileScreen()),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Editar perfil'),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(user: user),

          // --- Insignias ---
          const SizedBox(height: 28),
          SectionHeader(
            'Insignias',
            trailing: StatusPill(
              label: '$unlocked / ${achievements.length}',
              color: scheme.secondary,
            ),
          ),
          _StreakBanner(current: store.streakDays(), best: store.bestStreak()),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 0.85,
            children: [for (final a in achievements) _BadgeTile(a)],
          ),

          // --- Estadísticas ---
          const SizedBox(height: 28),
          const SectionHeader('Estadísticas'),
          _StatsGrid(store: store),
          const SizedBox(height: 12),
          _WeeklyChart(counts: store.workoutsPerWeek()),

          // --- Paneles y sesión ---
          const SizedBox(height: 28),
          if (store.isTrainer) ...[
            FilledButton.tonalIcon(
              onPressed: () => _push(context, const TrainerScreen()),
              icon: const Icon(Icons.sports),
              label: const Text('Panel de entrenador'),
            ),
            const SizedBox(height: 8),
          ],
          if (store.isAdmin) ...[
            FilledButton.tonalIcon(
              onPressed: () => _push(context, const AdminScreen()),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Administración'),
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: store.logout,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }
}

/// Foto de Google si la hay; si no, la inicial sobre un degradado coral.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = Text(
      name.isEmpty ? '?' : name[0].toUpperCase(),
      style: const TextStyle(
        fontSize: 44,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    return Container(
      width: 112,
      height: 112,
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.coral, Color(0xFF83DC4B)],
        ),
      ),
      child: ClipOval(
        child: Container(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: photoUrl == null
              ? initial
              : Image.network(
                  photoUrl!,
                  width: 106,
                  height: 106,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => initial,
                ),
        ),
      ),
    );
  }
}

/// Datos rápidos del perfil: altura, peso, objetivo y días.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('${user.heightCm.toStringAsFixed(0)} cm', 'Altura'),
      ('${_kg(user.weightKg)} kg', 'Peso'),
      (user.goal, 'Objetivo'),
      ('${user.daysPerWeek} días', 'Por semana'),
    ];
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          children: [
            for (final (value, label) in items)
              Expanded(
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: text.titleMedium),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: text.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _kg(double kg) => kg == kg.roundToDouble()
      ? kg.toStringAsFixed(0)
      : kg.toStringAsFixed(1).replaceAll('.', ',');
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.current, required this.best});

  final int current;
  final int best;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        gradient: LinearGradient(
          colors: [
            AppTheme.coral.withValues(alpha: 0.35),
            scheme.surfaceContainer,
          ],
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_fire_department,
            size: 40,
            color: AppTheme.coral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$current ${current == 1 ? 'día' : 'días'} de racha',
                  style: text.titleLarge,
                ),
                Text(
                  current == 0
                      ? 'Entrena hoy para empezar una racha nueva.'
                      : '¡Sigue así! Entrena hoy para no perderla.',
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text('$best', style: text.titleLarge),
              Text(
                'Mejor',
                style: text.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile(this.a);

  final Achievement a;

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(a.icon, size: 40, color: a.unlocked ? AppTheme.coral : null),
        title: Text(a.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(a.description, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ThinProgress(value: a.progress),
            const SizedBox(height: 6),
            Text(
              a.unlocked
                  ? '¡Conseguida!'
                  : '${_fmt(a.current)} / ${_fmt(a.target)} ${a.unit}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static String _fmt(num n) {
    // Separador de miles con punto: 10000 → 10.000.
    final s = n.round().toString();
    return s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = a.unlocked ? AppTheme.coral : scheme.outline;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: a.unlocked ? 0.18 : 0.08),
                  border: Border.all(
                    color: color.withValues(alpha: a.unlocked ? 1 : 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  a.unlocked ? a.icon : Icons.lock_outline,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                a.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: a.unlocked
                      ? scheme.onSurface
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              if (!a.unlocked)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: LinearProgressIndicator(
                    value: a.progress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = store.totalMinutes();
    final volume = store.totalVolume();
    final stats = [
      (
        Icons.fitness_center,
        '${store.workouts.length}',
        'Entrenos',
        scheme.secondary,
      ),
      (Icons.timer_outlined, _hours(minutes), 'Tiempo total', scheme.tertiary),
      (
        Icons.bar_chart,
        '${_BadgeTile._fmt(volume)} kg',
        'Volumen total',
        AppTheme.coral,
      ),
      (Icons.repeat, '${store.totalSets()}', 'Series', scheme.primaryFixed),
      (
        Icons.whatshot,
        '${store.bestStreak()} días',
        'Mejor racha',
        AppTheme.coral,
      ),
      (
        Icons.restaurant,
        '${store.nutritionDaysLogged()}',
        'Días con comidas',
        scheme.secondary,
      ),
    ];
    final favorite = store.favoriteExercise();

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: [
            for (final (icon, value, label, color) in stats)
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (favorite != null) ...[
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.star, color: Color(0xFFF5BF2D)),
              title: const Text('Ejercicio favorito'),
              subtitle: Text(favorite),
            ),
          ),
        ],
      ],
    );
  }

  static String _hours(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}

/// Barras con los entrenos de las últimas 8 semanas.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.counts});

  final List<int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxCount = counts.fold(1, (m, c) => c > m ? c : m);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entrenos por semana', style: text.titleMedium),
            Text(
              'Últimas ${counts.length} semanas',
              style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < counts.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${counts[i]}', style: text.labelSmall),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 80 * counts[i] / maxCount + 4,
                              decoration: BoxDecoration(
                                color: i == counts.length - 1
                                    ? AppTheme.coral
                                    : scheme.secondary.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              i == counts.length - 1
                                  ? 'Esta'
                                  : '-${counts.length - 1 - i}s',
                              style: text.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
