import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../models/models.dart';

/// Guarda [draft] con `AppStore.saveTrainingProfile` (lo usan "Editar
/// perfil" y "Ajustes de entrenamiento"):
/// - si falla, muestra el error y la pantalla sigue abierta;
/// - si va bien y el plan ha cambiado algo, enseña los avisos en un
///   diálogo; después muestra [successMessage] y cierra la pantalla.
/// Devuelve true si se guardó.
Future<bool> saveTrainingProfileAndClose(
  BuildContext context,
  UserProfile draft, {
  required String successMessage,
}) async {
  // Se cogen antes de los await: después, el context puede no ser válido.
  final store = SessionScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);

  final result = await store.saveTrainingProfile(draft);
  final error = result.error;
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return false;
  }
  if (result.warnings.isNotEmpty && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (_) => PlanWarningsDialog(warnings: result.warnings),
    );
  }
  messenger.showSnackBar(SnackBar(content: Text(successMessage)));
  navigator.pop();
  return true;
}

/// Diálogo con los cambios que se han hecho en el plan al guardar (por
/// ejemplo, "Hemos cambiado Sentadilla búlgara por Zancadas porque ya no
/// tienes mancuernas.").
class PlanWarningsDialog extends StatelessWidget {
  const PlanWarningsDialog({super.key, required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hemos ajustado tu plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final warning in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $warning'),
              ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}
