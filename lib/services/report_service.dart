import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/water_provider.dart';
import '../providers/drink_provider.dart';

class ReportService {
  static Future<void> generateAndShare({
    required BuildContext context,
    required WaterProvider waterProvider,
    required DrinkProvider drinkProvider,
    required bool isTr,
  }) async {
    final doc = pw.Document();

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
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => [
        pw.Header(level: 0, child: pw.Text(
          isTr ? 'Drinkly — Haftalik Rapor' : 'Drinkly — Weekly Report',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        )),
        pw.SizedBox(height: 8),
        pw.Text(
          isTr
            ? 'Rapor Tarihi: ${now.day}.${now.month}.${now.year}'
            : 'Report Date: ${now.month}/${now.day}/${now.year}',
          style: const pw.TextStyle(fontSize: 12),
        ),
        pw.SizedBox(height: 24),
        
        // Bugünkü Su
        pw.Header(level: 1, child: pw.Text(isTr ? 'Bugun Su Tuketimi' : 'Today\'s Water Intake')),
        pw.Text('${waterProvider.currentIntake} ml / ${waterProvider.dailyGoal} ml'),
        pw.SizedBox(height: 16),
        
        // Haftalık Kafein Tablosu
        pw.Header(level: 1, child: pw.Text(isTr ? 'Haftalik Kafein (mg)' : 'Weekly Caffeine (mg)')),
        pw.TableHelper.fromTextArray(
          headers: dayLabels,
          data: [cafData.map((v) => '${v.toStringAsFixed(0)} mg').toList()],
        ),
        pw.SizedBox(height: 16),
        
        // Haftalık Şeker Tablosu
        pw.Header(level: 1, child: pw.Text(isTr ? 'Haftalik Seker (g)' : 'Weekly Sugar (g)')),
        pw.TableHelper.fromTextArray(
          headers: dayLabels,
          data: [sugData.map((v) => '${v.toStringAsFixed(1)} g').toList()],
        ),
        pw.SizedBox(height: 24),
        
        // Limitler Bilgisi
        pw.Divider(),
        pw.Text(
          isTr
            ? 'Gunluk Kafein Limiti: ${DrinkProvider.caffeineLimit.toInt()} mg | Seker Limiti: ${DrinkProvider.sugarLimit.toInt()} g'
            : 'Daily Caffeine Limit: ${DrinkProvider.caffeineLimit.toInt()} mg | Sugar Limit: ${DrinkProvider.sugarLimit.toInt()} g',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/drinkly_report_${now.millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await doc.save());

    // ignore: deprecated_member_use
    await Share.shareXFiles([XFile(file.path)], text: isTr ? 'Drinkly Raporun' : 'Your Drinkly Report');
  }
}
