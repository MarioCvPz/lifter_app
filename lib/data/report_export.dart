import 'package:excel/excel.dart' as xl;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'client_report.dart';

/// Informe de un entrenador sobre sus usuarios, en Excel (datos en tablas)
/// o en PDF (resumen con gráficas). Se descarga con file_saver, que funciona
/// en web, Android, iOS y escritorio.
class TrainerReport {
  TrainerReport({
    required this.trainerName,
    required this.clients,
    required this.weeks,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String trainerName;
  final List<ClientReport> clients;
  final int weeks;
  final DateTime createdAt;

  String get _fileName {
    final d = createdAt;
    final date =
        '${d.year}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}';
    return 'informe_usuarios_$date';
  }

  List<DateTime> get _weekStarts =>
      clients.isEmpty ? const [] : clients.first.weekStarts;

  // ---------------------------------------------------------------- Excel --

  Uint8List buildExcel() {
    final book = xl.Excel.createExcel();
    final defaultSheet = book.getDefaultSheet()!;

    final header = xl.CellStyle(
      bold: true,
      fontColorHex: xl.ExcelColor.white,
      backgroundColorHex: xl.ExcelColor.fromHexString('#FF6B4A'),
    );

    void table(
      String name,
      List<String> headers,
      List<List<xl.CellValue?>> rows, {
      List<double>? widths,
    }) {
      final sheet = book[name];
      sheet.appendRow([for (final h in headers) xl.TextCellValue(h)]);
      for (var c = 0; c < headers.length; c++) {
        sheet
                .cell(
                  xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0),
                )
                .cellStyle =
            header;
        sheet.setColumnWidth(c, widths?[c] ?? (c == 0 ? 26 : 16));
      }
      for (final r in rows) {
        sheet.appendRow(r);
      }
    }

    xl.TextCellValue t(String v) => xl.TextCellValue(v);
    xl.IntCellValue i(int v) => xl.IntCellValue(v);
    xl.DoubleCellValue d(double v, [int decimals = 1]) =>
        xl.DoubleCellValue(double.parse(v.toStringAsFixed(decimals)));

    table(
      'Resumen',
      [
        'Usuario',
        'Correo',
        'Días/semana previstos',
        'Sesiones',
        'Sesiones/semana',
        'Cumplimiento (%)',
        'Sesiones de rutina asignada',
        'Minutos',
        'Series',
        'Volumen (kg)',
        'Último entreno',
        'Días sin entrenar',
      ],
      [
        for (final c in clients)
          [
            t(c.name),
            t(c.user.profile.email),
            i(c.daysPerWeek),
            i(c.sessions),
            d(c.sessionsPerWeek),
            d(c.adherencePct, 0),
            i(c.assignedSessions),
            i(c.minutes),
            i(c.sets),
            d(c.volumeKg, 0),
            t(c.lastWorkout == null ? '—' : longDate(c.lastWorkout!)),
            c.daysSinceLast == null ? t('—') : i(c.daysSinceLast!),
          ],
      ],
    );

    final weekHeaders = [for (final w in _weekStarts) 'Semana ${shortDate(w)}'];

    table(
      'Sesiones por semana',
      ['Usuario', ...weekHeaders, 'Objetivo/semana'],
      [
        for (final c in clients)
          [t(c.name), for (final s in c.sessionsByWeek) i(s), i(c.daysPerWeek)],
      ],
    );

    table(
      'Volumen por semana',
      ['Usuario', ...weekHeaders],
      [
        for (final c in clients)
          [t(c.name), for (final v in c.volumeByWeek) d(v, 0)],
      ],
    );

    table(
      'Entrenos',
      [
        'Usuario',
        'Fecha',
        'Sesión',
        'Minutos',
        'Ejercicios',
        'Series',
        'Volumen (kg)',
        'Rutina asignada',
      ],
      [
        for (final c in clients)
          for (final w in c.inPeriod)
            [
              t(c.name),
              t(longDate(w.date)),
              t(w.name),
              i(w.durationMin),
              i(w.exercises.length),
              i(w.exercises.fold(0, (s, e) => s + e.sets.length)),
              d(w.volumeKg, 0),
              t(c.assignedRoutineIds.contains(w.routineId) ? 'Sí' : 'No'),
            ],
      ],
    );

    table(
      'Ejercicios',
      ['Usuario', 'Ejercicio', 'Veces', 'Series', 'Peso máximo (kg)'],
      [
        for (final c in clients)
          for (final e in c.topExercises(limit: 100))
            [t(c.name), t(e.name), i(e.times), i(e.sets), d(e.bestKg)],
      ],
    );

    book.setDefaultSheet('Resumen');
    book.delete(defaultSheet);
    return Uint8List.fromList(book.encode()!);
  }

  Future<String> saveExcel() => FileSaver.instance.saveFile(
    name: _fileName,
    bytes: buildExcel(),
    fileExtension: 'xlsx',
    mimeType: MimeType.microsoftExcel,
  );

  // ------------------------------------------------------------------ PDF --

  static const _coral = PdfColor.fromInt(0xFFFF6B4A);
  static const _teal = PdfColor.fromInt(0xFF2A9D8F);
  static const _grey = PdfColor.fromInt(0xFF6B7280);

  Future<Uint8List> buildPdf() async {
    // La fuente de la app, para que salgan bien tildes y eñes.
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-400.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-700.ttf'),
    );
    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      title: 'Informe de usuarios',
      author: trainerName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (ctx) => _pageHeader(),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Página ${ctx.pageNumber} de ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: _grey),
          ),
        ),
        build: (ctx) => [
          _kpis(),
          pw.SizedBox(height: 16),
          _summaryTable(),
          if (clients.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            _title('Sesiones por usuario frente a su objetivo'),
            _sessionsVsGoalChart(),
            pw.SizedBox(height: 20),
            _title('Cumplimiento de cada usuario (%)'),
            _adherenceChart(),
            pw.SizedBox(height: 20),
            _title('Evolución semanal del grupo'),
            _groupTrendChart(),
          ],
          for (final c in clients) ..._clientSection(c),
        ],
      ),
    );
    return doc.save();
  }

  Future<String> savePdf() async => FileSaver.instance.saveFile(
    name: _fileName,
    bytes: await buildPdf(),
    fileExtension: 'pdf',
    mimeType: MimeType.pdf,
  );

  pw.Widget _pageHeader() => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 12),
    padding: const pw.EdgeInsets.only(bottom: 6),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: _coral, width: 2)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'LiFTeR+ · Informe de usuarios',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Entrenador: $trainerName',
                style: const pw.TextStyle(fontSize: 9, color: _grey),
              ),
            ],
          ),
        ),
        pw.Text(
          _weekStarts.isEmpty
              ? longDate(createdAt)
              : 'Del ${longDate(_weekStarts.first)} al ${longDate(createdAt)} '
                    '($weeks semanas)',
          style: const pw.TextStyle(fontSize: 9, color: _grey),
        ),
      ],
    ),
  );

  pw.Widget _title(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Text(
      text,
      style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
    ),
  );

  pw.Widget _kpis() {
    final sessions = clients.fold(0, (s, c) => s + c.sessions);
    final volume = clients.fold(0.0, (s, c) => s + c.volumeKg);
    final adherence = clients.isEmpty
        ? 0.0
        : clients.fold(0.0, (s, c) => s + c.adherencePct) / clients.length;
    final inactive = clients.where((c) => c.sessions == 0).length;

    pw.Widget box(String value, String label) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.symmetric(horizontal: 3),
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: _coral,
              ),
            ),
            pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
          ],
        ),
      ),
    );

    return pw.Row(
      children: [
        box('${clients.length}', 'usuarios'),
        box('$sessions', 'sesiones'),
        box('${adherence.round()} %', 'cumplimiento medio'),
        box(_kg(volume), 'volumen total'),
        box('$inactive', 'sin entrenar'),
      ],
    );
  }

  pw.Widget _summaryTable() {
    if (clients.isEmpty) {
      return pw.Text('Todavía no tienes usuarios con rutinas asignadas.');
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: _coral),
      cellStyle: const pw.TextStyle(fontSize: 8),
      cellAlignment: pw.Alignment.centerRight,
      cellAlignments: {0: pw.Alignment.centerLeft},
      oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      headers: [
        'Usuario',
        'Sesiones',
        'Objetivo',
        'Cumpl.',
        'Minutos',
        'Volumen',
        'Último',
      ],
      data: [
        for (final c in clients)
          [
            c.name,
            '${c.sessions}',
            '${c.daysPerWeek * weeks}',
            '${c.adherencePct.round()} %',
            '${c.minutes}',
            _kg(c.volumeKg),
            c.lastWorkout == null ? '—' : shortDate(c.lastWorkout!),
          ],
      ],
    );
  }

  /// Barras agrupadas: sesiones hechas (coral) y previstas (gris) por usuario.
  pw.Widget _sessionsVsGoalChart() {
    final maxY = clients
        .map(
          (c) => c.sessions > c.daysPerWeek * weeks
              ? c.sessions
              : c.daysPerWeek * weeks,
        )
        .fold(1, (a, b) => a > b ? a : b);
    return _barChart(
      labels: [for (final c in clients) _short(c.name)],
      maxY: maxY.toDouble(),
      series: [
        ('Hechas', _coral, [for (final c in clients) c.sessions.toDouble()]),
        (
          'Previstas',
          PdfColors.grey400,
          [for (final c in clients) (c.daysPerWeek * weeks).toDouble()],
        ),
      ],
    );
  }

  pw.Widget _adherenceChart() {
    final values = [for (final c in clients) c.adherencePct];
    final maxY = values.fold(100.0, (a, b) => a > b ? a : b);
    return _barChart(
      labels: [for (final c in clients) _short(c.name)],
      maxY: maxY,
      series: [('Cumplimiento %', _teal, values)],
    );
  }

  /// Líneas: sesiones totales y volumen total (en toneladas) por semana.
  pw.Widget _groupTrendChart() {
    final sessions = List<double>.filled(weeks, 0);
    final tonnes = List<double>.filled(weeks, 0);
    for (final c in clients) {
      final s = c.sessionsByWeek;
      final v = c.volumeByWeek;
      for (var i = 0; i < weeks; i++) {
        sessions[i] += s[i];
        tonnes[i] += v[i] / 1000;
      }
    }
    final maxY = [...sessions, ...tonnes].fold(1.0, (a, b) => a > b ? a : b);
    return _lineChart(
      labels: [for (final w in _weekStarts) shortDate(w)],
      maxY: maxY,
      series: [('Sesiones', _coral, sessions), ('Volumen (t)', _teal, tonnes)],
    );
  }

  List<pw.Widget> _clientSection(ClientReport c) {
    final top = c.topExercises();
    final maxSessions = [
      ...c.sessionsByWeek,
      c.daysPerWeek,
    ].fold(1, (a, b) => a > b ? a : b);
    return [
      pw.NewPage(),
      pw.Text(
        c.name,
        style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        '${c.user.profile.email} · objetivo ${c.daysPerWeek} días/semana · '
        '${c.user.profile.goal} · ${c.user.profile.experience}',
        style: const pw.TextStyle(fontSize: 9, color: _grey),
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        '${c.sessions} sesiones (${c.adherencePct.round()} % de lo previsto), '
        '${c.assignedSessions} con tu rutina asignada, ${c.minutes} min y '
        '${_kg(c.volumeKg)} de volumen. '
        '${c.daysSinceLast == null ? 'No ha registrado entrenos.' : 'Último entreno hace ${c.daysSinceLast} días.'}',
        style: const pw.TextStyle(fontSize: 10),
      ),
      pw.SizedBox(height: 14),
      _title('Sesiones por semana (la línea gris es su objetivo)'),
      _barChart(
        labels: [for (final w in c.weekStarts) shortDate(w)],
        maxY: maxSessions.toDouble(),
        series: [
          (
            'Sesiones',
            _coral,
            [for (final s in c.sessionsByWeek) s.toDouble()],
          ),
        ],
        goal: c.daysPerWeek.toDouble(),
      ),
      pw.SizedBox(height: 14),
      _title('Volumen por semana (kg)'),
      _lineChart(
        labels: [for (final w in c.weekStarts) shortDate(w)],
        maxY: c.volumeByWeek.fold(1.0, (a, b) => a > b ? a : b),
        series: [('Volumen', _teal, c.volumeByWeek)],
      ),
      if (top.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        _title('Ejercicios más hechos'),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Ejercicio', 'Veces', 'Series', 'Peso máx. (kg)'],
          data: [
            for (final e in top)
              [e.name, '${e.times}', '${e.sets}', _num(e.bestKg)],
          ],
        ),
      ],
    ];
  }

  // ------------------------------------------------------- gráficas PDF --

  pw.Widget _barChart({
    required List<String> labels,
    required double maxY,
    required List<(String, PdfColor, List<double>)> series,
    double? goal,
  }) {
    const barWidth = 12.0;
    final n = series.length;
    return pw.SizedBox(
      height: 170,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis.fromStrings(
            labels,
            marginStart: 24,
            marginEnd: 24,
            ticks: true,
            textStyle: const pw.TextStyle(fontSize: 7),
          ),
          yAxis: pw.FixedAxis(
            _ticks(maxY),
            divisions: true,
            format: _num,
            textStyle: const pw.TextStyle(fontSize: 7),
          ),
        ),
        datasets: [
          for (var s = 0; s < n; s++)
            pw.BarDataSet(
              legend: series[s].$1,
              color: series[s].$2,
              width: barWidth,
              offset: (s - (n - 1) / 2) * (barWidth + 2),
              data: [
                for (var i = 0; i < series[s].$3.length; i++)
                  pw.PointChartValue(i.toDouble(), series[s].$3[i]),
              ],
            ),
          if (goal != null)
            pw.LineDataSet(
              legend: 'Objetivo',
              color: PdfColors.grey600,
              drawPoints: false,
              lineWidth: 1,
              data: [
                for (var i = 0; i < labels.length; i++)
                  pw.PointChartValue(i.toDouble(), goal),
              ],
            ),
        ],
        bottom: n > 1 || goal != null
            ? pw.ChartLegend(
                direction: pw.Axis.horizontal,
                textStyle: const pw.TextStyle(fontSize: 7),
              )
            : null,
      ),
    );
  }

  pw.Widget _lineChart({
    required List<String> labels,
    required double maxY,
    required List<(String, PdfColor, List<double>)> series,
  }) {
    return pw.SizedBox(
      height: 150,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis.fromStrings(
            labels,
            marginStart: 24,
            marginEnd: 24,
            ticks: true,
            textStyle: const pw.TextStyle(fontSize: 7),
          ),
          yAxis: pw.FixedAxis(
            _ticks(maxY),
            divisions: true,
            format: _num,
            textStyle: const pw.TextStyle(fontSize: 7),
          ),
        ),
        datasets: [
          for (final (name, color, values) in series)
            pw.LineDataSet(
              legend: name,
              color: color,
              pointSize: 2.5,
              data: [
                for (var i = 0; i < values.length; i++)
                  pw.PointChartValue(i.toDouble(), values[i]),
              ],
            ),
        ],
        bottom: series.length > 1
            ? pw.ChartLegend(
                direction: pw.Axis.horizontal,
                textStyle: const pw.TextStyle(fontSize: 7),
              )
            : null,
      ),
    );
  }

  /// Cinco marcas "redondas" en el eje Y, de 0 a algo ≥ [max].
  static List<double> _ticks(double max) {
    if (max <= 0) max = 1;
    final raw = max / 4;
    var step = 1.0;
    while (step < raw) {
      step *= step.toString().startsWith('2') ? 2.5 : 2;
    }
    return [for (var i = 0; i <= 4; i++) step * i];
  }

  static String _num(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  static String _kg(double kg) =>
      kg >= 10000 ? '${(kg / 1000).toStringAsFixed(1)} t' : '${kg.round()} kg';

  static String _short(String name) {
    final first = name.split(' ').first;
    return first.length > 10 ? '${first.substring(0, 9)}.' : first;
  }
}
