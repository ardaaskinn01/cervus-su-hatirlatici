import 'dart:io';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../providers/water_provider.dart';
import '../providers/drink_provider.dart';

class ReportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0EA5E9);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor successColor = PdfColor.fromInt(0xFF22C55E);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor dangerColor = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);

  static Future<void> generateAndShare({
    required material.BuildContext context,
    required WaterProvider waterProvider,
    required DrinkProvider drinkProvider,
    required bool isTr,
  }) async {
    final doc = pw.Document();

    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final ByteData bytes = await rootBundle.load('assets/images/app_icon.png');
    final Uint8List iconBytes = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(iconBytes);

    final weeklyStats = await drinkProvider.getWeeklyStats();
    final List<double> cafData = List<double>.from(weeklyStats['caffeineData'] ?? []);
    final List<double> sugData = List<double>.from(weeklyStats['sugarData'] ?? []);

    final now = DateTime.now();
    final dayLabels = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return '${d.day}/${d.month}';
    });

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => [
        // 🔹 HEADER BANNER
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: const pw.BoxDecoration(
            color: primaryColor,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(
                children: [
                pw.ClipOval(
                  child: pw.Container(
                    width: 45,
                    height: 45,
                    color: PdfColors.white,
                    padding: const pw.EdgeInsets.all(2),
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  ),
                ),
                  pw.SizedBox(width: 15),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DRINKLY', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
                      pw.Text(isTr ? 'Haftalık Sağlık Raporu' : 'Weekly Health Report', style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(isTr ? 'TARİH' : 'DATE', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                  pw.Text('${now.day}.${now.month}.${now.year}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 30),

        // 🔹 SUMMARY CARDS
        pw.Row(
          children: [
            _buildStatCard(isTr ? 'Günlük Su' : 'Daily Water', '${waterProvider.currentIntake} / ${waterProvider.dailyGoal} ml', primaryColor),
            pw.SizedBox(width: 15),
            _buildStatCard(isTr ? 'Ort. Kafein' : 'Avg. Caffeine', '${(cafData.reduce((a, b) => a + b) / 7).toStringAsFixed(0)} mg', warningColor),
            pw.SizedBox(width: 15),
            _buildStatCard(isTr ? 'Ort. Şeker' : 'Avg. Sugar', '${(sugData.reduce((a, b) => a + b) / 7).toStringAsFixed(1)} g', successColor),
          ],
        ),
        pw.SizedBox(height: 30),

        // 🔹 TABLES
        _buildSectionHeader(isTr ? 'KAFEİN TÜKETİM DETAYI (mg)' : 'CAFFEINE INTAKE DETAILS (mg)'),
        _buildStyledTable(dayLabels, cafData.map((v) => '${v.toInt()} mg').toList(), warningColor),
        
        pw.SizedBox(height: 30),
        _buildSectionHeader(isTr ? 'ŞEKER TÜKETİM DETAYI (g)' : 'SUGAR INTAKE DETAILS (g)'),
        _buildStyledTable(dayLabels, sugData.map((v) => '${v.toStringAsFixed(1)} g').toList(), successColor),

        pw.SizedBox(height: 40),
        
        // 🔹 LIMITS & DISCLAIMER
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            color: lightBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(isTr ? 'Önemli Notlar:' : 'Important Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: secondaryColor)),
              pw.SizedBox(height: 6),
              pw.Text(
                isTr 
                  ? 'Günlük Kafein Limiti: ${DrinkProvider.caffeineLimit.toInt()} mg | Şeker Limiti: ${DrinkProvider.sugarLimit.toInt()} g. Bu rapor Drinkly tarafından istatistiklerinizi takip etmeniz için oluşturulmuştur.'
                  : 'Daily Caffeine Limit: ${DrinkProvider.caffeineLimit.toInt()} mg | Sugar Limit: ${DrinkProvider.sugarLimit.toInt()} g. This report is generated by Drinkly to help you track your habits.',
                style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
        
        pw.Spacer(),
        pw.Align(
          alignment: pw.Alignment.center,
          child: pw.Text(
            isTr ? 'Sağlıklı günler dileriz!' : 'Stay healthy, stay hydrated!',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
          ),
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/drinkly_report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());

    await Share.shareXFiles([XFile(file.path)], text: isTr ? 'Drinkly Sağlık Raporu' : 'Your Drinkly Health Report');
  }

  static pw.Widget _buildStatCard(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          color: lightBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          border: pw.Border.all(color: color),
        ),
        child: pw.Column(
          children: [
            pw.Text(title.toUpperCase(), style: pw.TextStyle(fontSize: 8, color: secondaryColor, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: secondaryColor),
      ),
    );
  }

  static pw.Widget _buildStyledTable(List<String> headers, List<String> data, PdfColor accent) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: [data],
      border: null,
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10),
      headerDecoration: pw.BoxDecoration(color: accent, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(6))),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.center,
      rowDecoration: pw.BoxDecoration(color: lightBg, border: const pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100))),
      cellPadding: const pw.EdgeInsets.all(8),
    );
  }
}
