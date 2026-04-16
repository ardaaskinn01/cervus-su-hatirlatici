import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum ViewMode { list, chart, calendar }

class _HistoryScreenState extends State<HistoryScreen> {
  ViewMode _viewMode = ViewMode.calendar;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    _selectedDay = _focusedDay;
  }

  // Helper method to strip time for easy map lookups
  DateTime _stripTime(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    var userProvider = context.watch<UserProvider>();
    var user = userProvider.currentUser;

    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const accentColor = Color(0xFF0EA5E9);
    const scaffoldBg = Color(0xFFF8FAFC);
    const successColor = Color(0xFF22C55E);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(context.watch<LocaleProvider>().translate('hist_title'), style: const TextStyle(color: primaryText)), centerTitle: true),
        body: Center(child: Text(context.watch<LocaleProvider>().translate('prof_user_not_found'))),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(context.watch<LocaleProvider>().translate('hist_title'), style: const TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        centerTitle: true,
        actions: [
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.tune_rounded, color: accentColor, size: 28),
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: ViewMode.calendar, child: Row(children: [const Icon(Icons.calendar_month_rounded, color: accentColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_calendar'))])),
              PopupMenuItem(value: ViewMode.list, child: Row(children: [const Icon(Icons.list_alt_rounded, color: accentColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_list'))])),
              PopupMenuItem(value: ViewMode.chart, child: Row(children: [const Icon(Icons.bar_chart_rounded, color: accentColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_chart'))])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.firebaseId)
            .collection('gunler')
            .orderBy('tarih', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text(context.read<LocaleProvider>().translate('hist_loading_error'), style: const TextStyle(color: secondaryText)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 80, color: secondaryText.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  Text(
                    context.watch<LocaleProvider>().translate('hist_no_data'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: secondaryText, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          // Prepare Map for quick calendar access (O(1) lookups)
          Map<DateTime, Map<String, dynamic>> recordsMap = {};
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final dateString = data['tarih'] as String? ?? '';
            try {
              DateTime parsed = DateTime.parse(dateString);
              recordsMap[_stripTime(parsed)] = data;
            } catch (_) {}
          }

          Widget content;
          if (_viewMode == ViewMode.calendar) {
            content = _buildCalendarView(recordsMap, accentColor, successColor, primaryText, secondaryText);
          } else if (_viewMode == ViewMode.chart) {
            content = _buildChartView(docs, accentColor, successColor, primaryText, secondaryText);
          } else {
            content = _buildListView(docs, accentColor, successColor, primaryText, secondaryText);
          }

          return Column(
            children: [
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  // 1. TAKVİM MODU ──────────────────────────────────────────
  Widget _buildCalendarView(Map<DateTime, Map<String, dynamic>> recordsMap, Color accentColor, Color successColor, Color primaryText, Color secondaryText) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 20, offset: Offset(0, 10))],
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: TableCalendar(
            locale: 'tr_TR', // Eğer cihaz dili TR ise iyi, değilse intl paketini başlatmak gerekir
            firstDay: DateTime.utc(2023, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            currentDay: DateTime.now(),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) => _focusedDay = focusedDay,
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(color: accentColor, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: accentColor.withOpacity(0.3), shape: BoxShape.circle),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final stripped = _stripTime(day);
                if (recordsMap.containsKey(stripped)) {
                  final data = recordsMap[stripped]!;
                  final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
                  final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
                  final isHit = intake >= goal;

                  return Positioned(
                    bottom: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isHit ? successColor : Colors.orangeAccent,
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Seçili Günün Detayları
        Expanded(
          child: _selectedDay == null 
              ? const SizedBox.shrink()
              : _buildDayDetails(_selectedDay!, recordsMap[_stripTime(_selectedDay!)], accentColor, successColor, primaryText, secondaryText),
        ),
      ],
    );
  }

  Widget _buildDayDetails(DateTime day, Map<String, dynamic>? data, Color accentColor, Color successColor, Color primaryText, Color secondaryText) {
    final lp = context.watch<LocaleProvider>();
    String localeStr = lp.locale.languageCode == 'tr' ? 'tr_TR' : 'en_US';
    String formattedDate = DateFormat('d MMMM yyyy, EEEE', localeStr).format(day);

    if (data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.no_drinks_rounded, size: 60, color: secondaryText.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text('$formattedDate\n${lp.translate('hist_no_entry')}', textAlign: TextAlign.center, style: TextStyle(color: secondaryText, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      );
    }

    final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
    final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
    final isHit = intake >= goal;
    final suIcildiList = data['suIcildi'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formattedDate, style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: isHit ? successColor.withOpacity(0.1) : Colors.orangeAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  isHit ? lp.translate('hist_success_badge') : lp.translate('hist_pending_badge'),
                  style: TextStyle(color: isHit ? successColor : Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              )
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('$intake', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: isHit ? successColor : accentColor, letterSpacing: -1)),
              Text(' / $goal ml', style: TextStyle(fontSize: 16, color: secondaryText, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 24),
          Text(lp.translate('hist_logs'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Expanded(
            child: suIcildiList.isEmpty 
              ? Text(lp.translate('hist_no_log_detail'), style: TextStyle(color: secondaryText))
              : ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: suIcildiList.length,
                  itemBuilder: (context, index) {
                    final ismeData = suIcildiList[index] as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.water_drop_rounded, color: accentColor, size: 20),
                          const SizedBox(width: 12),
                          Text('${ismeData['miktar']} ml', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          Text('${ismeData['saat']}', style: TextStyle(color: secondaryText, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  // 2. DETAYLI LİSTE MODU (Eski History Screen'ın Geliştirilmiş Hali) ──────────────
  Widget _buildListView(List<QueryDocumentSnapshot> docs, Color accentColor, Color successColor, Color primaryText, Color secondaryText) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final dateString = data['tarih'] as String? ?? '';
        final currentIntake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
        final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
        final isHit = currentIntake >= goal;
        final suIcildiList = data['suIcildi'] as List<dynamic>? ?? [];

        DateTime? date;
        try { date = DateTime.parse(dateString); } catch (_) {}
        String displayDate = dateString;
        if (date != null) {
          final lp = context.read<LocaleProvider>();
          String localeStr = lp.locale.languageCode == 'tr' ? 'tr_TR' : 'en_US';
          displayDate = DateFormat('d MMMM yyyy, EEEE', localeStr).format(date);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
            border: Border.all(
              color: isHit ? successColor.withOpacity(0.3) : const Color(0xFFF1F5F9),
              width: isHit ? 2 : 1.5,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isHit ? successColor.withOpacity(0.1) : const Color(0xFFF0F9FF)),
                    child: Icon(isHit ? Icons.done_all_rounded : Icons.water_drop_rounded, color: isHit ? successColor : accentColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(displayDate, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: secondaryText)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('$currentIntake', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, color: isHit ? successColor : primaryText, letterSpacing: -1)),
                            Text(' / $goal ml', style: TextStyle(fontSize: 14, color: secondaryText, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              children: [
                if (suIcildiList.isEmpty)
                   Padding(padding: const EdgeInsets.all(16), child: Text(context.read<LocaleProvider>().translate('hist_no_log_detail')))
                else
                  ...suIcildiList.map((item) {
                    final m = item as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: accentColor.withOpacity(0.5)),
                          const SizedBox(width: 12),
                          Text('${m['miktar']} ml', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${m['saat']}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  }).toList(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // 3. GRAFİK MODU ───────────────────────────────────────────
  Widget _buildChartView(List<QueryDocumentSnapshot> docs, Color accentColor, Color successColor, Color primaryText, Color secondaryText) {
    if (docs.isEmpty) return const SizedBox.shrink();

    final reversedDocs = docs.reversed.toList();
    int maxIntake = 2000;
    for (var doc in reversedDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
      if (intake > maxIntake) maxIntake = intake;
    }

    return Container(
      width: double.infinity,
      color: Colors.transparent,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(context.watch<LocaleProvider>().translate('hist_chart_title'), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryText, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reversedDocs.length,
              itemBuilder: (context, index) {
                final data = reversedDocs[index].data() as Map<String, dynamic>;
                final dateString = data['tarih'] as String? ?? '';
                final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
                final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
                final isHit = intake >= goal;

                DateTime? date;
                try { date = DateTime.parse(dateString); } catch (_) {}
                String dayFormat = date != null ? "${date.day}/${date.month}" : "";

                double ratio = maxIntake > 0 ? (intake / maxIntake).clamp(0.0, 1.0) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$intake',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isHit ? successColor : accentColor),
                      ),
                      const SizedBox(height: 8),
                      // Bar (Çubuk) Kısmı
                      Expanded(
                        child: Container(
                          width: 40,
                          alignment: Alignment.bottomCenter,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                          child: FractionallySizedBox(
                            heightFactor: ratio,
                            child: Container(
                              width: 40,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isHit ? [successColor, successColor.withOpacity(0.7)] : [accentColor, accentColor.withOpacity(0.7)],
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: (isHit ? successColor : accentColor).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                                ]
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(dayFormat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryText)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
