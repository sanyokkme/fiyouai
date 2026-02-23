import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ═══════════════════════════════════════════════════════════════════════════
//  PDF LAYOUT CONFIG
//  ─────────────────────────────────────────────────────────────────────────
//  This file is the single place where you define the visual structure of
//  exported PDF reports. Change it here and every generated PDF updates
//  automatically — no need to touch the UI or the generation logic.
// ═══════════════════════════════════════════════════════════════════════════

// ──────────────────────────────────────────────────────────────────────────
//  Column definition
//  Each column maps a data key to a header label and a value extractor.
// ──────────────────────────────────────────────────────────────────────────
class PdfColumnDef {
  /// Unique identifier used by toggle switches in the UI.
  final String id;

  /// Header label shown in the PDF table.
  final String label;

  /// Whether this column is visible by default when the user opens the
  /// template screen.
  final bool defaultEnabled;

  /// Extracts a display string from a row map that contains:
  ///   date, cal, goal, protein, fat, carbs, water  (all int / String)
  final String Function(Map<String, dynamic> row) getValue;

  const PdfColumnDef({
    required this.id,
    required this.label,
    this.defaultEnabled = true,
    required this.getValue,
  });
}

// ──────────────────────────────────────────────────────────────────────────
//  Section definition
//  Sections are top-level blocks rendered below the main table.
// ──────────────────────────────────────────────────────────────────────────
typedef SectionBuilder =
    pw.Widget Function(List<Map<String, dynamic>> rows, PdfLayoutConfig cfg);

class PdfSectionDef {
  final String id;
  final String label;
  final bool defaultEnabled;
  final SectionBuilder builder;

  const PdfSectionDef({
    required this.id,
    required this.label,
    this.defaultEnabled = true,
    required this.builder,
  });
}

// ──────────────────────────────────────────────────────────────────────────
//  Style config
// ──────────────────────────────────────────────────────────────────────────
class PdfStyleConfig {
  /// Accent / header background colour (PdfColor).
  final PdfColor accentColor;

  /// Base font size for table body text.
  final double bodyFontSize;

  /// Font size for the report header title.
  final double titleFontSize;

  const PdfStyleConfig({
    this.accentColor = const PdfColor.fromInt(0xFF6EE7B7),
    this.bodyFontSize = 8,
    this.titleFontSize = 16,
  });

  PdfStyleConfig copyWith({PdfColor? accentColor}) => PdfStyleConfig(
    accentColor: accentColor ?? this.accentColor,
    bodyFontSize: bodyFontSize,
    titleFontSize: titleFontSize,
  );
}

// ──────────────────────────────────────────────────────────────────────────
//  Header builder — override to fully customise the header block
// ──────────────────────────────────────────────────────────────────────────
typedef HeaderBuilder =
    pw.Widget Function(String dateRangeLabel, PdfLayoutConfig cfg);

// ──────────────────────────────────────────────────────────────────────────
//  Footer builder
// ──────────────────────────────────────────────────────────────────────────
typedef FooterBuilder = pw.Widget Function(PdfLayoutConfig cfg);

// ══════════════════════════════════════════════════════════════════════════
//  MAIN CONFIG CLASS
// ══════════════════════════════════════════════════════════════════════════
class PdfLayoutConfig {
  // ── Report metadata ────────────────────────────────────────────────────
  final String appName;
  final String reportTitle;

  // ── Page settings ──────────────────────────────────────────────────────
  final PdfPageFormat pageFormat;

  // ── Style ──────────────────────────────────────────────────────────────
  final PdfStyleConfig style;

  // ── Column definitions (order matters — determines column order in PDF) ─
  final List<PdfColumnDef> columns;

  // ── Extra sections rendered below the table ────────────────────────────
  final List<PdfSectionDef> sections;

  // ── Optional custom header overriding the default ──────────────────────
  final HeaderBuilder? customHeader;

  // ── Optional custom footer overriding the default ─────────────────────
  final FooterBuilder? customFooter;

  const PdfLayoutConfig({
    this.appName = 'FiYou AI',
    this.reportTitle = 'Звіт харчування',
    this.pageFormat = PdfPageFormat.a4,
    this.style = const PdfStyleConfig(),
    required this.columns,
    this.sections = const [],
    this.customHeader,
    this.customFooter,
  });

  PdfLayoutConfig copyWithAccent(PdfColor accent) => PdfLayoutConfig(
    appName: appName,
    reportTitle: reportTitle,
    pageFormat: pageFormat,
    style: style.copyWith(accentColor: accent),
    columns: columns,
    sections: sections,
    customHeader: customHeader,
    customFooter: customFooter,
  );
}

// ══════════════════════════════════════════════════════════════════════════
//  DEFAULT LAYOUT
//  ─────────────────────────────────────────────────────────────────────────
//  ✏️  Edit this object to change the default PDF layout for the entire app.
//  You can:
//    • Reorder columns by changing the list order.
//    • Add / remove columns by modifying the list.
//    • Add custom sections (charts, notes, etc.) via PdfSectionDef.
//    • Provide a customHeader / customFooter builder for full control.
// ══════════════════════════════════════════════════════════════════════════
final PdfLayoutConfig defaultPdfLayout = PdfLayoutConfig(
  appName: 'FiYou AI',
  reportTitle: 'Звіт харчування',
  pageFormat: PdfPageFormat.a4,
  style: const PdfStyleConfig(
    accentColor: PdfColor.fromInt(0xFF6EE7B7),
    bodyFontSize: 8,
    titleFontSize: 16,
  ),

  // ── Table columns ────────────────────────────────────────────────────
  // Change order here to reorder columns in the PDF.
  columns: [
    PdfColumnDef(
      id: 'date',
      label: 'Дата',
      defaultEnabled: true,
      getValue: (r) => r['date'].toString(),
    ),
    PdfColumnDef(
      id: 'cal',
      label: 'Ккал',
      defaultEnabled: true,
      getValue: (r) => '${r['cal']}',
    ),
    PdfColumnDef(
      id: 'goal',
      label: 'Ціль',
      defaultEnabled: true,
      getValue: (r) => '${r['goal']}',
    ),
    PdfColumnDef(
      id: 'protein',
      label: 'Білки г',
      defaultEnabled: true,
      getValue: (r) => '${r['protein']}',
    ),
    PdfColumnDef(
      id: 'fat',
      label: 'Жири г',
      defaultEnabled: true,
      getValue: (r) => '${r['fat']}',
    ),
    PdfColumnDef(
      id: 'carbs',
      label: 'Вугл. г',
      defaultEnabled: true,
      getValue: (r) => '${r['carbs']}',
    ),
    PdfColumnDef(
      id: 'water',
      label: 'Вода мл',
      defaultEnabled: true,
      getValue: (r) => '${r['water']}',
    ),
  ],

  // ── Extra sections ───────────────────────────────────────────────────
  sections: [
    PdfSectionDef(
      id: 'chart',
      label: 'Графік прогресу',
      defaultEnabled: true,
      builder: (rows, cfg) {
        if (rows.length < 2) return pw.SizedBox();

        final dates = rows
            .map((r) => r['date'].toString().substring(0, 5))
            .toList();

        double maxCal = 1.0;
        for (final r in rows) {
          final cal = (r['cal'] as num).toDouble();
          if (cal > maxCal) maxCal = cal;
        }

        final yTicks = <int>[];
        final step = (maxCal / 4).ceil();
        for (int i = 0; i <= 4; i++) {
          yTicks.add(i * step);
        }

        pw.Widget buildLegend(String title, PdfColor color) {
          return pw.Row(
            children: [
              pw.Container(
                width: 6,
                height: 6,
                decoration: pw.BoxDecoration(
                  shape: pw.BoxShape.circle,
                  color: color,
                ),
              ),
              pw.SizedBox(width: 4),
              pw.Text(
                title,
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey400,
                ),
              ),
            ],
          );
        }

        return pw.Container(
          height: 160,
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF1E1E1E),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFF333333)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Прогрес (ккал та макро)',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                children: [
                  buildLegend('Ккал', cfg.style.accentColor),
                  buildLegend('Білки', PdfColors.blue300),
                  buildLegend('Жири', PdfColors.orange300),
                  buildLegend('Вуглеводи', PdfColors.green300),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Expanded(
                child: pw.Chart(
                  grid: pw.CartesianGrid(
                    xAxis: pw.FixedAxis.fromStrings(
                      dates,
                      textStyle: const pw.TextStyle(
                        fontSize: 6,
                        color: PdfColors.grey400,
                      ),
                    ),
                    yAxis: pw.FixedAxis(
                      yTicks,
                      format: (v) => v.toInt().toString(),
                      textStyle: const pw.TextStyle(
                        fontSize: 6,
                        color: PdfColors.grey400,
                      ),
                    ),
                  ),
                  datasets: [
                    pw.LineDataSet(
                      legend: 'Ккал',
                      color: cfg.style.accentColor,
                      pointColor: cfg.style.accentColor,
                      drawPoints: false,
                      lineWidth: 2,
                      data: List<pw.PointChartValue>.generate(
                        rows.length,
                        (i) => pw.PointChartValue(
                          i.toDouble(),
                          (rows[i]['cal'] as num).toDouble(),
                        ),
                      ),
                    ),
                    pw.LineDataSet(
                      legend: 'Білки',
                      color: PdfColors.blue300,
                      drawPoints: false,
                      lineWidth: 1.5,
                      data: List<pw.PointChartValue>.generate(
                        rows.length,
                        (i) => pw.PointChartValue(
                          i.toDouble(),
                          (rows[i]['protein'] as num).toDouble(),
                        ),
                      ),
                    ),
                    pw.LineDataSet(
                      legend: 'Жири',
                      color: PdfColors.orange300,
                      drawPoints: false,
                      lineWidth: 1.5,
                      data: List<pw.PointChartValue>.generate(
                        rows.length,
                        (i) => pw.PointChartValue(
                          i.toDouble(),
                          (rows[i]['fat'] as num).toDouble(),
                        ),
                      ),
                    ),
                    pw.LineDataSet(
                      legend: 'Вуглеводи',
                      color: PdfColors.green300,
                      drawPoints: false,
                      lineWidth: 1.5,
                      data: List<pw.PointChartValue>.generate(
                        rows.length,
                        (i) => pw.PointChartValue(
                          i.toDouble(),
                          (rows[i]['carbs'] as num).toDouble(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    PdfSectionDef(
      id: 'summary',
      label: 'Підсумок (середні значення)',
      defaultEnabled: true,
      builder: (rows, cfg) {
        if (rows.isEmpty) return pw.SizedBox();
        int totalCal = 0;
        double avgP = 0, avgF = 0, avgC = 0, avgW = 0;
        for (final r in rows) {
          totalCal += (r['cal'] as num).toInt();
          avgP += (r['protein'] as num).toDouble();
          avgF += (r['fat'] as num).toDouble();
          avgC += (r['carbs'] as num).toDouble();
          avgW += (r['water'] as num).toDouble();
        }
        final n = rows.length;
        avgP /= n;
        avgF /= n;
        avgC /= n;
        avgW /= n;

        cell(String label, String val) => pw.Column(
          children: [
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              val,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ],
        );

        return pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: const PdfColor.fromInt(0xFF1E1E1E),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(color: const PdfColor.fromInt(0xFF333333)),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Підсумок',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  cell('Всього ккал', '$totalCal'),
                  cell('Сер. білки', '${avgP.toStringAsFixed(1)} г'),
                  cell('Сер. жири', '${avgF.toStringAsFixed(1)} г'),
                  cell('Сер. вугл.', '${avgC.toStringAsFixed(1)} г'),
                  cell('Сер. вода', '${avgW.toStringAsFixed(0)} мл'),
                ],
              ),
            ],
          ),
        );
      },
    ),

    // ── Add more custom sections below ───────────────────────────────
    // Example: a "Notes" section
    // PdfSectionDef(
    //   id: 'notes',
    //   label: 'Нотатки',
    //   defaultEnabled: false,
    //   builder: (rows, cfg) => pw.Text('Особисті нотатки…'),
    // ),
  ],
);
