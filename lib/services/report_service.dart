import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../providers/water_provider.dart';
import '../providers/drink_provider.dart';

  enum ReportPeriod { daily, weekly, monthly }

class ReportService {
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF0EA5E9);
  static const PdfColor secondaryColor = PdfColor.fromInt(0xFF64748B);
  static const PdfColor successColor = PdfColor.fromInt(0xFF22C55E);
  static const PdfColor warningColor = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);

  static Future<void> generateAndShare({
    required material.BuildContext context,
    required WaterProvider waterProvider,
    required DrinkProvider drinkProvider,
    required bool isTr,
    ReportPeriod period = ReportPeriod.weekly,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final ByteData bytes = await rootBundle.load('assets/images/app_icon.png');
    final Uint8List iconBytes = bytes.buffer.asUint8List();
    final image = pw.MemoryImage(iconBytes);

    final now = DateTime.now();
    int dayCount = period == ReportPeriod.daily ? 1 : (period == ReportPeriod.weekly ? 7 : 30);
    
    List<String> dayLabels = [];
    List<int> waterData = [];
    List<double> cafData = [];
    List<double> sugData = [];


    if (period == ReportPeriod.daily) {
      dayLabels = [(isTr ? 'Bugün' : 'Today')];
      waterData = [waterProvider.currentIntake];
      cafData = [drinkProvider.dailyCaffeine];
      sugData = [drinkProvider.dailySugar];
    } else {
      for (int i = dayCount - 1; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key = "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
        
        // Su
        final wSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(waterProvider.user?.firebaseId ?? '')
            .collection('gunler')
            .doc(key)
            .get();
        waterData.add(wSnap.exists ? (wSnap.data()!['gunlukMiktar'] as num? ?? 0).toInt() : 0);

        // İçecekler (Aylık için ayrı çekiyoruz)
        final dSnaps = await FirebaseFirestore.instance
            .collection('users')
            .doc(waterProvider.user?.firebaseId ?? '')
            .collection('drinks')
            .doc(key)
            .collection('entries')
            .get();
        
        double dCaf = 0;
        double dSug = 0;
        for (var doc in dSnaps.docs) {
          dCaf += (doc.data()['caffeineAmount'] as num? ?? 0).toDouble();
          dSug += (doc.data()['sugarAmount'] as num? ?? 0).toDouble();
        }
        cafData.add(dCaf);
        sugData.add(dSug);
        dayLabels.add('${day.day}/${day.month}');
      }
    }

    final double avgWater = waterData.reduce((a, b) => a + b) / dayCount;
    final double avgCaf = cafData.reduce((a, b) => a + b) / dayCount;
    final double avgSug = sugData.reduce((a, b) => a + b) / dayCount;

    String reportTitle = isTr ? 'Haftalık Sağlık Raporu' : 'Weekly Health Report';
    if (period == ReportPeriod.daily) reportTitle = isTr ? 'Günlük Sağlık Raporu' : 'Daily Health Report';
    if (period == ReportPeriod.monthly) reportTitle = isTr ? 'Aylık Sağlık Raporu' : 'Monthly Health Report';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      theme: pw.ThemeData.withFont(base: font, bold: fontBold),
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => [
        // 🔹 HEADER
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: const pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.all(pw.Radius.circular(12))),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Row(children: [
                pw.ClipOval(child: pw.Container(width: 45, height: 45, color: PdfColors.white, padding: const pw.EdgeInsets.all(2), child: pw.Image(image, fit: pw.BoxFit.cover))),
                pw.SizedBox(width: 15),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text('DRINKLY', style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: PdfColors.white, letterSpacing: 2)),
                  pw.Text(reportTitle, style: const pw.TextStyle(fontSize: 12, color: PdfColors.white)),
                ]),
              ]),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(isTr ? 'TARİH' : 'DATE', style: pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                pw.Text('${now.day}.${now.month}.${now.year}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ]),
            ],
          ),
        ),
        pw.SizedBox(height: 25),

        // 🔹 SUMMARY
        pw.Row(children: [
          _buildStatCard(isTr ? 'Sıvı Ort.' : 'Fluid Avg.', '${avgWater.round()} ml', primaryColor),
          pw.SizedBox(width: 15),
          _buildStatCard(isTr ? 'Kafein Ort.' : 'Caff. Avg.', '${avgCaf.round()} mg', warningColor),
          pw.SizedBox(width: 15),
          _buildStatCard(isTr ? 'Şeker Ort.' : 'Sugar Avg.', '${avgSug.toStringAsFixed(1)} g', successColor),
        ]),
        pw.SizedBox(height: 25),

        // 🔹 DATA TABLE
        _buildSectionHeader(isTr ? 'TÜKETİM DETAYLARI' : 'CONSUMPTION DETAILS'),
        _buildPeriodTable(dayLabels, waterData, cafData, sugData, isTr, period),

        pw.SizedBox(height: 30),
        
        // 🔹 WARNINGS
        pw.Container(
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(color: lightBg, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)), border: pw.Border.all(color: PdfColors.grey300)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(isTr ? 'Sağlık Notları:' : 'Health Notes:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: secondaryColor)),
            pw.SizedBox(height: 5),
            pw.Text(
              isTr 
                ? 'Günlük güvenli kafein sınırı 400mg, şeker sınırı ise 50g\'dır. Bu değerlerin aşılması uzun vadede sağlık sorunlarına yol açabilir.'
                : 'Daily safe caffeine limit is 400mg, and sugar limit is 50g. Exceeding these values can lead to health issues in the long run.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ]),
        ),
        pw.Spacer(),
        pw.Align(alignment: pw.Alignment.center, child: pw.Text(isTr ? 'Daha sağlıklı bir gelecek için...' : 'For a healthier future...', style: pw.TextStyle(fontSize: 11, fontStyle: pw.FontStyle.italic, color: secondaryColor))),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final fileName = 'drinkly_${period.name}_report_${now.millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await doc.save());
    await Share.shareXFiles([XFile(file.path)], text: isTr ? 'Drinkly Raporu' : 'Drinkly Health Report');
  }

  static pw.Widget _buildPeriodTable(List<String> labels, List<int> water, List<double> caf, List<double> sug, bool isTr, ReportPeriod period) {
    final headers = [
      isTr ? 'TARİH' : 'DATE',
      isTr ? 'SU (ml)' : 'WATER (ml)',
      isTr ? 'KAFEİN (mg)' : 'CAFF. (mg)',
      isTr ? 'ŞEKER (g)' : 'SUGAR (g)'
    ];

    List<List<String>> rows = [];
    for (int i = 0; i < labels.length; i++) {
      rows.add([
        labels[i],
        '${water[i]} ml',
        '${caf[i].toInt()} mg',
        '${sug[i].toStringAsFixed(1)} g'
      ]);
    }

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: null,
      headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: secondaryColor, borderRadius: pw.BorderRadius.vertical(top: pw.Radius.circular(6))),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.center,
      rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey100))),
      cellPadding: const pw.EdgeInsets.all(6),
    );
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

}
