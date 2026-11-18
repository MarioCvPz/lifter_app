import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../widgets/brand.dart';
import '../../widgets/help.dart';
import '../../widgets/mode_switch.dart';
import 'trainer_code_card.dart';

/// "Mi perfil de entrenador": nombre, el código (copiar y generar otro) y
/// el selector para volver al modo usuario.
class TrainerProfileScreen extends StatelessWidget {
  const TrainerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final user = store.user;
    final text = Theme.of(context).textTheme;
    final clients = store.myClientIds.length;
    return Scaffold(
      appBar: const BrandAppBar(
        title: 'Mi perfil de entrenador',
        help: HelpTopic.trainer,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const ModeSwitch(),
          const SizedBox(height: 20),
          Text(user?.name ?? '', style: text.headlineSmall),
          Text(
            '${user?.email ?? ''} · $clients '
            '${clients == 1 ? 'cliente' : 'clientes'}',
            style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TrainerCodeCard(store: store),
        ],
      ),
    );
  }
}
