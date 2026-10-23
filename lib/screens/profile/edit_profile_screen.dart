import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

/// Formulario para editar los datos del perfil.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  static const goals = [
    'Hipertrofia',
    'Fuerza',
    'Pérdida de grasa',
    'Salud general',
  ];
  static const sexes = ['Hombre', 'Mujer', 'Otro'];
  static const equipmentOptions = [
    'Barra',
    'Mancuernas',
    'Máquinas',
    'Polea',
    'Peso corporal',
    'Kettlebell',
    'Bandas elásticas',
  ];

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  late String _goal;
  late String _experience;
  late String _sex;
  late int _days;
  late Set<String> _equipment;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final user = SessionScope.of(context).user!;
    _name.text = user.name;
    _username.text = user.username;
    _height.text = user.heightCm.toStringAsFixed(0);
    _weight.text = user.weightKg.toStringAsFixed(1);
    _goal = EditProfileScreen.goals.contains(user.goal)
        ? user.goal
        : EditProfileScreen.goals.first;
    _experience = Routine.levels.contains(user.experience)
        ? user.experience
        : Routine.levels[1];
    _sex = EditProfileScreen.sexes.contains(user.sex)
        ? user.sex
        : EditProfileScreen.sexes.last;
    _days = user.daysPerWeek.clamp(2, 6);
    _equipment = {...user.equipment};
    _loaded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _save() {
    final store = SessionScope.of(context);
    final current = store.user!;
    final height = double.tryParse(_height.text.replaceAll(',', '.'));
    final weight = double.tryParse(_weight.text.replaceAll(',', '.'));

    String? error;
    if (_name.text.trim().isEmpty) {
      error = 'El nombre no puede estar vacío.';
    } else if (height == null || height < 100 || height > 250) {
      error = 'Escribe una altura entre 100 y 250 cm.';
    } else if (weight == null || weight < 30 || weight > 300) {
      error = 'Escribe un peso entre 30 y 300 kg.';
    }
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    store.updateProfile(
      UserProfile(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: current.email,
        role: current.role,
        sex: _sex,
        heightCm: height!,
        weightKg: weight!,
        experience: _experience,
        goal: _goal,
        daysPerWeek: _days,
        equipment: [
          for (final e in EditProfileScreen.equipmentOptions)
            if (_equipment.contains(e)) e,
        ],
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar perfil'),
        actions: [TextButton(onPressed: _save, child: const Text('Guardar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Datos personales', style: text.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(
              labelText: 'Nombre de usuario',
              prefixText: '@',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sex,
            decoration: const InputDecoration(labelText: 'Sexo'),
            items: [
              for (final s in EditProfileScreen.sexes)
                DropdownMenuItem(value: s, child: Text(s)),
            ],
            onChanged: (v) => setState(() => _sex = v ?? _sex),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _height,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Altura',
                    suffixText: 'cm',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso',
                    suffixText: 'kg',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Entrenamiento', style: text.titleMedium),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Objetivo'),
            items: [
              for (final g in EditProfileScreen.goals)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _goal = v ?? _goal),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _experience,
            decoration: const InputDecoration(labelText: 'Experiencia'),
            items: [
              for (final l in Routine.levels)
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => setState(() => _experience = v ?? _experience),
          ),
          const SizedBox(height: 16),
          Text('Días disponibles por semana: $_days'),
          Slider(
            value: _days.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            label: '$_days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          const SizedBox(height: 8),
          Text('Material disponible', style: text.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in EditProfileScreen.equipmentOptions)
                FilterChip(
                  label: Text(e),
                  selected: _equipment.contains(e),
                  onSelected: (on) => setState(() {
                    on ? _equipment.add(e) : _equipment.remove(e);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Guardar cambios')),
        ],
      ),
    );
  }
}
