import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_app/constants/app_colors.dart';
import 'package:flutter_app/services/pdf_layout_config.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  PDF Template Screen
///  • Toggle columns / sections on the left panel (tab 1)
///  • Live preview built with PdfPreview (tab 2)
///  • "Share PDF" button at the bottom
///  • Layout is driven by [defaultPdfLayout] from pdf_layout_config.dart
/// ─────────────────────────────────────────────────────────────────────────
class PdfTemplateScreen extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  final Map<String, dynamic> historyData;
  final Map<String, dynamic>? statusData;

  const PdfTemplateScreen({
    super.key,
    required this.from,
    required this.to,
    required this.historyData,
    this.statusData,
  });

  @override
  State<PdfTemplateScreen> createState() => _PdfTemplateScreenState();
}

class _PdfTemplateScreenState extends State<PdfTemplateScreen> {
  // ── Accent colour options ──────────────────────────────────────────────
  static const _accentColors = [
    Color(0xFF6EE7B7), // green (default)
    Color(0xFF60A5FA), // blue
    Color(0xFFA78BFA), // purple
    Color(0xFFFBBF24), // amber
    Color(0xFFF87171), // red
  ];
  static const _accentPdf = [
    PdfColor.fromInt(0xFF6EE7B7),
    PdfColor.fromInt(0xFF60A5FA),
    PdfColor.fromInt(0xFFA78BFA),
    PdfColor.fromInt(0xFFFBBF24),
    PdfColor.fromInt(0xFFF87171),
  ];
  int _accentIdx = 0;

  // ── Enabled columns / sections (driven by defaultPdfLayout defaults) ───
  late final Map<String, bool> _colEnabled;
  late final Map<String, bool> _secEnabled;

  @override
  void initState() {
    super.initState();

    _colEnabled = {
      for (final c in defaultPdfLayout.columns) c.id: c.defaultEnabled,
    };
    _secEnabled = {
      for (final s in defaultPdfLayout.sections) s.id: s.defaultEnabled,
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Build the data rows from historyData + today's status.
  List<Map<String, dynamic>> _buildRows() {
    final rows = <Map<String, dynamic>>[];
    DateTime cur = DateTime(
      widget.from.year,
      widget.from.month,
      widget.from.day,
    );
    final end = DateTime(widget.to.year, widget.to.month, widget.to.day);

    while (!cur.isAfter(end)) {
      final key =
          '${cur.year}-${cur.month.toString().padLeft(2, '0')}-${cur.day.toString().padLeft(2, '0')}';

      if (_isToday(cur) && widget.statusData != null) {
        rows.add({
          'date': _fmt(cur),
          'cal': (widget.statusData!['eaten'] as num?)?.toInt() ?? 0,
          'goal': (widget.statusData!['target'] as num?)?.toInt() ?? 2000,
          'protein': (widget.statusData!['protein'] as num?)?.toInt() ?? 0,
          'fat': (widget.statusData!['fat'] as num?)?.toInt() ?? 0,
          'carbs': (widget.statusData!['carbs'] as num?)?.toInt() ?? 0,
          'water': (widget.statusData!['water'] as num?)?.toInt() ?? 0,
        });
      } else if (widget.historyData.containsKey(key)) {
        final h = widget.historyData[key];
        rows.add({
          'date': _fmt(cur),
          'cal': (h['calories'] ?? 0).toInt(),
          'goal': (widget.statusData?['target'] ?? 2000),
          'protein': (h['protein'] ?? 0).toInt(),
          'fat': (h['fat'] ?? 0).toInt(),
          'carbs': (h['carbs'] ?? 0).toInt(),
          'water': (h['water'] ?? 0).toInt(),
        });
      }
      cur = cur.add(const Duration(days: 1));
    }
    return rows;
  }

  // ── PDF generator ───────────────────────────────────────────────────────
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    // Load fonts synchronously (on the main thread) so they are guaranteed to exist.
    final regularData = await PdfGoogleFonts.robotoRegular();
    final boldData = await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(
      base: regularData,
      bold: boldData,
    ).copyWith(defaultTextStyle: const pw.TextStyle(color: PdfColors.white));

    final cfg = defaultPdfLayout.copyWithAccent(_accentPdf[_accentIdx]);
    final accent = cfg.style.accentColor;
    final rows = _buildRows();
    final dateRange = '${_fmt(widget.from)} – ${_fmt(widget.to)}';

    final doc = pw.Document();

    final activeCols = defaultPdfLayout.columns
        .where((c) => _colEnabled[c.id] == true)
        .toList();
    final activeSecs = defaultPdfLayout.sections
        .where((s) => _secEnabled[s.id] == true)
        .toList();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: theme,
          margin: const pw.EdgeInsets.all(32),
          buildBackground: (ctx) => pw.FullPage(
            ignoreMargins: true,
            child: pw.Stack(
              children: [
                pw.Container(color: const PdfColor.fromInt(0xFF141414)),
              ],
            ),
          ),
        ),
        build: (ctx) => [
          // ── Header ────────────────────────────────────────────────
          if (cfg.customHeader != null)
            cfg.customHeader!(dateRange, cfg)
          else
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(
                color: accent,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        cfg.appName,
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        cfg.reportTitle,
                        style: pw.TextStyle(
                          fontSize: cfg.style.titleFontSize,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.black,
                        ),
                      ),
                    ],
                  ),
                  pw.Text(
                    dateRange,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 16),

          // ── Table ─────────────────────────────────────────────────
          if (activeCols.isEmpty || rows.isEmpty)
            pw.Text(
              rows.isEmpty
                  ? 'Немає даних за вибраний діапазон.'
                  : 'Виберіть хоча б один стовпець.',
              style: const pw.TextStyle(color: PdfColors.grey),
            )
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                // Header row
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                    color: PdfColor(accent.red, accent.green, accent.blue, 0.3),
                  ),
                  children: activeCols
                      .map(
                        (c) => pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            c.label,
                            style: pw.TextStyle(
                              fontSize: cfg.style.bodyFontSize,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      )
                      .toList(),
                ),
                // Data rows
                ...rows.asMap().entries.map((entry) {
                  final even = entry.key.isEven;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: even
                          ? const PdfColor.fromInt(0xFF1E1E1E)
                          : const PdfColor.fromInt(0xFF252525),
                    ),
                    children: activeCols
                        .map(
                          (c) => pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 4,
                            ),
                            child: pw.Text(
                              c.getValue(entry.value),
                              style: pw.TextStyle(
                                fontSize: cfg.style.bodyFontSize,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                          ),
                        )
                        .toList(),
                  );
                }),
              ],
            ),

          // ── Extra sections ─────────────────────────────────────────
          ...activeSecs.map(
            (s) => pw.Column(
              children: [pw.SizedBox(height: 20), s.builder(rows, cfg)],
            ),
          ),

          // ── Footer ───────────────────────────────────────────────
          pw.SizedBox(height: 16),
          if (cfg.customFooter != null)
            cfg.customFooter!(cfg)
          else ...[
            pw.Divider(color: PdfColors.grey300),
            pw.Text(
              'Згенеровано ${cfg.appName} · ${_fmt(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey),
            ),
          ],
        ],
      ),
    );

    return doc.save();
  }

  // ── Open Preview ─────────────────────────────────────────────────────────
  Future<void> _openPreview() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      // Generate PDF bytes on the main thread (safely awaiting PdfGoogleFonts)
      final bytes = await _generatePdf(PdfPageFormat.a4);
      final name =
          'fiyou_report_${widget.from.toIso8601String().split('T')[0]}_${widget.to.toIso8601String().split('T')[0]}.pdf';

      if (mounted) {
        Navigator.pop(context); // close loading dialog
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: bytes,
              filename: name,
              accentColor: _accentColors[_accentIdx],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  Settings tab
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSettingsTab() {
    final accent = _accentColors[_accentIdx];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      children: [
        // ── Accent colour ────────────────────────────────────────────
        _sectionLabel('Акцентний колір'),
        const SizedBox(height: 10),
        Row(
          children: List.generate(_accentColors.length, (i) {
            final sel = i == _accentIdx;
            return GestureDetector(
              onTap: () => setState(() => _accentIdx = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(right: 10),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentColors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: _accentColors[i].withOpacity(0.5),
                            blurRadius: 10,
                          ),
                        ]
                      : [],
                ),
                child: sel
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.black,
                        size: 18,
                      )
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 24),

        // ── Columns ──────────────────────────────────────────────────
        _sectionLabel('Стовпці таблиці'),
        const SizedBox(height: 4),
        _card(
          children: defaultPdfLayout.columns.map((col) {
            return _toggleRow(
              col.label,
              _colEnabled[col.id] ?? col.defaultEnabled,
              accent,
              (v) => setState(() => _colEnabled[col.id] = v),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ── Sections ─────────────────────────────────────────────────
        if (defaultPdfLayout.sections.isNotEmpty) ...[
          _sectionLabel('Додаткові секції'),
          const SizedBox(height: 4),
          _card(
            children: defaultPdfLayout.sections.map((sec) {
              return _toggleRow(
                sec.label,
                _secEnabled[sec.id] ?? sec.defaultEnabled,
                accent,
                (v) => setState(() => _secEnabled[sec.id] = v),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  // ── Small UI helpers ──────────────────────────────────────────────────
  Widget _sectionLabel(String text) => Text(
    text,
    style: TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.4,
    ),
  );

  Widget _card({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.glassCardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.06)),
    ),
    child: Column(children: children),
  );

  Widget _toggleRow(
    String label,
    bool value,
    Color accent,
    ValueChanged<bool> onChanged,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: accent,
        ),
      ],
    ),
  );

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final accent = _accentColors[_accentIdx];

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PDF Звіт',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${_fmt(widget.from)} – ${_fmt(widget.to)}',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPreview,
        backgroundColor: accent,
        foregroundColor: Colors.black,
        elevation: 6,
        icon: const Icon(Icons.preview_rounded),
        label: const Text(
          'Перегляд та Експорт',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _buildSettingsTab(),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────
///  Screen that displays the actual PDF using printing package
/// ─────────────────────────────────────────────────────────────────────────
class PdfPreviewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String filename;
  final Color accentColor;

  const PdfPreviewScreen({
    super.key,
    required this.pdfBytes,
    required this.filename,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundDark,
        foregroundColor: Colors.white,
        title: const Text('Перегляд PDF', style: TextStyle(fontSize: 18)),
      ),
      body: Column(
        children: [
          Expanded(
            child: PdfPreview(
              build: (format) =>
                  Future.value(pdfBytes), // display pre-calculated bytes safely
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              useActions: false, // Turn off default empty app bar
              padding: EdgeInsets.zero,
              scrollViewDecoration: BoxDecoration(
                color: AppColors.backgroundDark,
              ),
              pdfPreviewPageDecoration: BoxDecoration(
                color: Colors.transparent,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(
              color: AppColors.glassCardColor,
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Printing.layoutPdf(
                      onLayout: (_) => Future.value(pdfBytes),
                    ),
                    icon: const Icon(Icons.print_rounded, color: Colors.white),
                    label: const Text(
                      'Друк',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Printing.sharePdf(bytes: pdfBytes, filename: filename),
                    icon: const Icon(Icons.share_rounded, color: Colors.black),
                    label: const Text(
                      'Поділитись',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
