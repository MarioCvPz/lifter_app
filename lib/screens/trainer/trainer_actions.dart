import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_report.dart';
import '../../data/report_export.dart';
import '../../models/models.dart';
import '../routines/routine_widgets.dart';
import 'assign_day_sheet.dart';

// Acciones del entrenador que se usan desde varias pantallas (el panel
// antiguo y el modo entrenador). Son funciones sueltas porque no guardan
// estado: en Java serían métodos estáticos de una clase de utilidades.

/// "Asignar rutina" a [client]: elige el día de su plan, crea la rutina y
/// la asigna. Avisa si no se puede (sin plan o sin conexión).
Future<void> assignRoutineTo(BuildContext context, AppUser client) async {
  final store = SessionScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final name = client.profile.name;

  // La rutina va en un día concreto de su plan, así que hace falta el plan.
  final TrainingPlan? clientPlan;
  try {
    clientPlan = await store.fetchPlanOf(client.uid);
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text('No se pudo cargar el plan de $name: $e')),
    );
    return;
  }
  if (!context.mounted) return;
  if (clientPlan == null || clientPlan.days.isEmpty) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '$name todavía no tiene plan de entreno. Cuando lo cree podrás '
          'asignarle rutinas para cada día.',
        ),
      ),
    );
    return;
  }

  final dayNumber = await showAssignDayPicker(
    context,
    clientName: name,
    plan: clientPlan,
    assigned: [
      for (final a in store.assignedByMe)
        if (a.userId == client.uid) a,
    ],
  );
  if (dayNumber == null || !context.mounted) return;

  final routine = await showRoutineEditor(
    context,
    exercises: store.exercises,
    title: 'Día $dayNumber de $name',
    templateName: 'Entrenador',
  );
  if (routine == null) return;

  store.assignRoutine(client, routine, dayNumber: dayNumber);
  messenger.showSnackBar(
    SnackBar(content: Text('Rutina asignada al día $dayNumber de $name.')),
  );
}

/// Genera el informe de [reports] en PDF o Excel y avisa de cómo ha ido.
Future<void> exportReport(
  BuildContext context,
  List<ClientReport> reports, {
  required bool pdf,
  required int weeks,
}) async {
  final store = SessionScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  if (reports.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Todavía no tienes clientes vinculados.')),
    );
    return;
  }
  messenger.showSnackBar(
    SnackBar(content: Text('Generando ${pdf ? 'PDF' : 'Excel'}…')),
  );
  final report = TrainerReport(
    trainerName: store.user?.name ?? 'Entrenador',
    clients: reports,
    weeks: weeks,
  );
  try {
    final path = await (pdf ? report.savePdf() : report.saveExcel());
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            path.isEmpty ? 'Informe descargado.' : 'Informe guardado en $path',
          ),
        ),
      );
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('No se pudo generar: $e')));
  }
}

/// Botón con el menú "Excel / PDF" del informe. [onSelected] recibe true
/// si se elige PDF.
class ExportReportButton extends StatelessWidget {
  const ExportReportButton({
    super.key,
    required this.onSelected,
    this.enabled = true,
  });

  final ValueChanged<bool> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Exportar informe',
      icon: const Icon(Icons.download),
      enabled: enabled,
      onSelected: onSelected,
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: false,
          child: ListTile(
            leading: Icon(Icons.table_chart_outlined),
            title: Text('Excel (.xlsx)'),
            subtitle: Text('Datos en tablas'),
          ),
        ),
        PopupMenuItem(
          value: true,
          child: ListTile(
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('PDF'),
            subtitle: Text('Resumen con gráficas'),
          ),
        ),
      ],
    );
  }
}
