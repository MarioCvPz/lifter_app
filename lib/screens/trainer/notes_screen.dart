import 'package:flutter/material.dart';

import '../../data/app_store.dart';
import '../../data/client_overview.dart';
import '../../widgets/brand.dart';
import 'client_notes.dart';
import 'client_screen.dart';

/// Pestaña "Notas" del modo entrenador: las notas de todos los clientes,
/// primero las no leídas. Al tocar una se abre la pestaña Notas de la
/// ficha de ese cliente (y allí se marcan como leídas).
class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final notes = ClientNote.allOf(store.clientOverviews);
    return Scaffold(
      appBar: const BrandAppBar(title: 'Notas'),
      body: RefreshIndicator(
        onRefresh: store.loadClientOverviews,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            if (notes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Tus clientes no te han dejado notas en las últimas '
                  'semanas.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final note in notes)
              NoteTile(
                note: note,
                showClient: true,
                onTap: () => openClientScreen(
                  context,
                  note.clientId,
                  tab: ClientTab.notes,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
