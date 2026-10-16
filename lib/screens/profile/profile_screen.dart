import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _username;
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late String _goal;
  late String _experience;
  late int _days;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final user = SessionScope.of(context).user!;
    _name = TextEditingController(text: user.name);
    _username = TextEditingController(text: user.username);
    _height = TextEditingController(text: user.heightCm.toStringAsFixed(0));
    _weight = TextEditingController(text: user.weightKg.toStringAsFixed(1));
    _goal = user.goal;
    _experience = user.experience;
    _days = user.daysPerWeek;
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
    store.updateProfile(
      UserProfile(
        name: _name.text.trim(),
        username: _username.text.trim(),
        email: current.email,
        sex: current.sex,
        heightCm: double.tryParse(_height.text) ?? current.heightCm,
        weightKg: double.tryParse(_weight.text.replaceAll(',', '.')) ??
            current.weightKg,
        experience: _experience,
        goal: _goal,
        daysPerWeek: _days,
        equipment: current.equipment,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil actualizado (solo en esta sesión).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final user = store.user!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
            ),
            title: Text(user.email),
            subtitle: const Text('Cuenta local de demostración'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _username,
            decoration: const InputDecoration(labelText: 'Nombre de usuario'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _height,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Altura (cm)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Peso (kg)'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Objetivo'),
            items: const [
              DropdownMenuItem(value: 'Hipertrofia', child: Text('Hipertrofia')),
              DropdownMenuItem(value: 'Fuerza', child: Text('Fuerza')),
              DropdownMenuItem(
                value: 'Pérdida de grasa',
                child: Text('Pérdida de grasa'),
              ),
              DropdownMenuItem(
                value: 'Salud general',
                child: Text('Salud general'),
              ),
            ],
            onChanged: (v) => setState(() => _goal = v ?? _goal),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _experience,
            decoration: const InputDecoration(labelText: 'Experiencia'),
            items: const [
              DropdownMenuItem(
                value: 'Principiante',
                child: Text('Principiante'),
              ),
              DropdownMenuItem(value: 'Intermedio', child: Text('Intermedio')),
              DropdownMenuItem(value: 'Avanzado', child: Text('Avanzado')),
            ],
            onChanged: (v) => setState(() => _experience = v ?? _experience),
          ),
          const SizedBox(height: 12),
          Text('Días disponibles: $_days'),
          Slider(
            value: _days.toDouble(),
            min: 2,
            max: 6,
            divisions: 4,
            label: '$_days',
            onChanged: (v) => setState(() => _days = v.round()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [for (final e in user.equipment) Chip(label: Text(e))],
          ),
          const SizedBox(height: 24),
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
