import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/ai_coach_models.dart';

/// Mirrors the Next.js generatePlanPDF from lib/pdf-utils.ts.
/// Landscape A4, dark header, meal tables per day, workout schedule.
class PdfService {
  static final _lime = PdfColor.fromHex('CCD853');
  static final _darkBg = PdfColor.fromHex('0C0C0C');
  static final _dark2 = PdfColor.fromHex('1E1E1E');
  static final _grey = PdfColor.fromHex('B0B0B0');
  static final _lightGrey = PdfColor.fromHex('E0E0E0');
  static const _white = PdfColors.white;

  static final _mealColors = {
    'Breakfast': PdfColor.fromHex('FF8C00'),
    'Lunch': PdfColor.fromHex('00B450'),
    'Snacks': PdfColor.fromHex('0078FF'),
    'Dinner': PdfColor.fromHex('7832FF'),
  };
  static final _mealRowColors = {
    'Breakfast': PdfColor.fromHex('FFF6EB'),
    'Lunch': PdfColor.fromHex('EEFAF2'),
    'Snacks': PdfColor.fromHex('EEF4FF'),
    'Dinner': PdfColor.fromHex('F8F4FF'),
  };

  static Future<void> sharePlanPDF(FitnessPlan plan) async {
    final bytes = await _buildPDF(plan);
    final safeName = plan.name.replaceAll(RegExp(r'\s+'), '_').replaceAll(RegExp(r'[^\w_-]'), '');
    await Printing.sharePdf(bytes: bytes, filename: 'EleFit_Plan_$safeName.pdf');
  }

  static Future<Uint8List> _buildPDF(FitnessPlan plan) async {
    final doc = pw.Document();

    // Load logo from assets
    pw.ImageProvider? logo;
    try {
      logo = await imageFromAssetBundle('assets/images/elefit_logo.png');
    } catch (_) {}

    // Schedule dates
    const shortDays = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    final scheduleDates = List.generate(7, (i) {
      final date = plan.generatedDate.add(Duration(days: i));
      return _DateLabel(shortDays[date.weekday % 7], date.day.toString().padLeft(2, '0'));
    });

    final totalMealPages = 7;
    final totalWorkoutPages = ((7 + 1) / 2).ceil(); // 4 pages
    final totalPages = totalMealPages + totalWorkoutPages;
    int pageNum = 0;

    // === MEAL PLAN PAGES (one per day) ===
    for (int dayIdx = 0; dayIdx < 7; dayIdx++) {
      pageNum++;
      final dayMeals = dayIdx < plan.weeklyMeals.length
          ? plan.weeklyMeals[dayIdx]
          : DayMeals(mealsByTime: {});
      final dateLabel = scheduleDates[dayIdx];

      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(logo, dayIdx == 0, plan),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(15, 12, 15, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _dayLabel('DAY ${dayIdx + 1}: ${dateLabel.day} (${dateLabel.num})'),
                    pw.SizedBox(height: 8),
                    _mealTable(dayMeals),
                  ],
                ),
              ),
            ),
            _footer(pageNum, totalPages),
          ],
        ),
      ));
    }

    // === WORKOUT PAGES (2 days per page) ===
    for (int i = 0; i < 7; i += 2) {
      pageNum++;
      final isFirst = i == 0;
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _header(logo, false, null),
            pw.Expanded(
              child: pw.Padding(
                padding: const pw.EdgeInsets.fromLTRB(15, 12, 15, 0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (isFirst) ...[
                      pw.Text('WEEKLY WORKOUT SCHEDULE',
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 10),
                    ],
                    _workoutDay(plan, i, scheduleDates),
                    pw.SizedBox(height: 14),
                    if (i + 1 < 7) _workoutDay(plan, i + 1, scheduleDates),
                  ],
                ),
              ),
            ),
            _footer(pageNum, totalPages),
          ],
        ),
      ));
    }

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _header(pw.ImageProvider? logo, bool showSummary, FitnessPlan? plan) {
    return pw.Container(
      height: 28,
      color: _darkBg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          if (logo != null)
            pw.Image(logo, height: 16)
          else
            pw.Text('ELEFIT',
                style: pw.TextStyle(color: _lime, fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (showSummary && plan != null)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('PLAN: ${plan.goal.toUpperCase()}',
                    style: pw.TextStyle(color: _grey, fontSize: 7)),
                pw.Text(
                    'CALORIES: ${plan.dailyCalories} KCAL  |  FOCUS: ${plan.workoutFocus.toUpperCase()}',
                    style: pw.TextStyle(color: _grey, fontSize: 7)),
                pw.Text('DATE: ${_fmtDate(plan.generatedDate)}',
                    style: pw.TextStyle(color: _grey, fontSize: 7)),
              ],
            ),
        ],
      ),
    );
  }

  // ── Day label bar ─────────────────────────────────────────────────────────

  static pw.Widget _dayLabel(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _dark2,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Text(text,
          style: pw.TextStyle(color: _lime, fontSize: 12, fontWeight: pw.FontWeight.bold)),
    );
  }

  // ── Meal table ────────────────────────────────────────────────────────────

  static pw.Widget _mealTable(DayMeals dayMeals) {
    const mealOrder = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

    // Build rows: [mealLabel, foodItem, quantity, calories, mealTime (hidden)]
    final rows = <List<dynamic>>[];
    for (final time in mealOrder) {
      final items = dayMeals.mealsByTime[time] ?? [];
      for (int i = 0; i < items.length; i++) {
        rows.add([i == 0 ? time.toUpperCase() : '', items[i].name, items[i].quantity, '${items[i].calories} kcal', time]);
      }
    }

    if (rows.isEmpty) {
      return pw.Text('Rest day — no meals scheduled.',
          style: pw.TextStyle(color: _grey, fontSize: 10, fontStyle: pw.FontStyle.italic));
    }

    // Adaptive font/padding based on row count
    double fontSize = 9;
    double cellPadding = 3.5;
    if (rows.length > 22) { fontSize = 7; cellPadding = 1.2; }
    else if (rows.length > 16) { fontSize = 8; cellPadding = 2; }

    return pw.Table(
      border: pw.TableBorder.all(color: _lightGrey, width: 0.1),
      columnWidths: {
        0: const pw.FixedColumnWidth(55),
        1: const pw.FlexColumnWidth(),
        2: const pw.FixedColumnWidth(70),
        3: const pw.FixedColumnWidth(60),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: pw.BoxDecoration(color: _dark2),
          children: ['MEAL', 'FOOD ITEM', 'QUANTITY', 'CALORIES']
              .map((h) => _tableCell(h,
                  bold: true,
                  color: _white,
                  fontSize: fontSize,
                  padding: cellPadding,
                  center: true))
              .toList(),
        ),
        // Data rows
        ...rows.map((row) {
          final time = row[4] as String;
          final mealColor = _mealColors[time]!;
          final rowBg = _mealRowColors[time]!;
          return pw.TableRow(
            decoration: pw.BoxDecoration(color: rowBg),
            children: [
              _tableCell(row[0] as String,
                  bold: true,
                  color: mealColor,
                  fontSize: fontSize,
                  padding: cellPadding,
                  center: true),
              _tableCell(row[1] as String,
                  bold: true,
                  fontSize: fontSize,
                  padding: cellPadding),
              _tableCell(row[2] as String,
                  fontSize: fontSize,
                  padding: cellPadding,
                  center: true),
              _tableCell(row[3] as String,
                  fontSize: fontSize,
                  padding: cellPadding,
                  center: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(String text, {
    bool bold = false,
    PdfColor? color,
    double fontSize = 9,
    double padding = 3.5,
    bool center = false,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.all(padding),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? PdfColor.fromHex('282828'),
        ),
      ),
    );
  }

  // ── Workout section ───────────────────────────────────────────────────────

  static pw.Widget _workoutDay(FitnessPlan plan, int dayIdx, List<_DateLabel> dates) {
    final workout = dayIdx < plan.weeklyWorkouts.length
        ? plan.weeklyWorkouts[dayIdx]
        : DayWorkout(name: 'Rest Day', isRestDay: true);
    final dateLabel = dates[dayIdx];

    final durationStr = workout.duration.toLowerCase().trim();
    final isZeroDuration = RegExp(r'^0\s*(mins?|minutes?)?$').hasMatch(durationStr);
    final hasValidDuration = !workout.isRestDay && durationStr.isNotEmpty && !isZeroDuration;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('F5F5F5'),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '${dateLabel.day.toUpperCase()} — ${workout.isRestDay ? 'REST DAY' : workout.name.toUpperCase()}',
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
              if (hasValidDuration)
                pw.Text('Duration: ${workout.duration}',
                    style: pw.TextStyle(fontSize: 8, color: _grey)),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        if (!workout.isRestDay && workout.exercises.isNotEmpty)
          pw.Table(
            children: workout.exercises.map((ex) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: pw.Text('• $ex', style: pw.TextStyle(fontSize: 8.5)),
                ),
              ],
            )).toList(),
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 4),
            child: pw.Text('Take this time to recover and stay hydrated.',
                style: pw.TextStyle(fontSize: 8, color: _grey, fontStyle: pw.FontStyle.italic)),
          ),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer(int page, int total) {
    const disclaimer =
        'This plan is for educational purposes only and is not a substitute for professional medical advice. '
        'Consult a healthcare professional before starting any new diet or exercise program.';
    return pw.Container(
      color: PdfColor.fromHex('F7F7F7'),
      padding: const pw.EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('GENERATED BY ELEFIT AI COACH  •  FUEL YOUR AMBITION  •  WWW.THEELEFIT.COM',
                  style: pw.TextStyle(fontSize: 6.5, color: _grey)),
              pw.Text('PAGE $page OF $total',
                  style: pw.TextStyle(fontSize: 6.5, color: _grey)),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(disclaimer,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 5, color: _lightGrey)),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

class _DateLabel {
  final String day;
  final String num;
  const _DateLabel(this.day, this.num);
}
