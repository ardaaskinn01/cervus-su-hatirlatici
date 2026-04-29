import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../providers/user_provider.dart';
import '../providers/drink_provider.dart';
import '../models/drink_model.dart';
import '../providers/locale_provider.dart';
import 'package:intl/date_symbol_data_local.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

enum ViewMode { list, chart, calendar }
enum HistoryMode { water, softDrink }

class _HistoryScreenState extends State<HistoryScreen> {
  ViewMode _viewMode = ViewMode.calendar;
  HistoryMode _historyMode = HistoryMode.water;
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
    const primaryColor = Color(0xFF0EA5E9);
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
          PopupMenuButton<HistoryMode>(
            icon: Icon(Icons.filter_alt_rounded, color: _historyMode == HistoryMode.water ? primaryColor : const Color(0xFFE8590C), size: 28),
            onSelected: (mode) => setState(() => _historyMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: HistoryMode.water, child: Row(children: [const Icon(Icons.water_drop, color: Color(0xFF0EA5E9)), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('drink_water_history'))])),
              PopupMenuItem(value: HistoryMode.softDrink, child: Row(children: [const Icon(Icons.local_cafe, color: Color(0xFFE8590C)), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('drink_history'))])),
            ],
          ),
          PopupMenuButton<ViewMode>(
            icon: const Icon(Icons.tune_rounded, color: primaryColor, size: 28),
            onSelected: (mode) => setState(() => _viewMode = mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: ViewMode.calendar, child: Row(children: [const Icon(Icons.calendar_month_rounded, color: primaryColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_calendar'))])),
              PopupMenuItem(value: ViewMode.list, child: Row(children: [const Icon(Icons.list_alt_rounded, color: primaryColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_list'))])),
              if (_historyMode == HistoryMode.water) PopupMenuItem(value: ViewMode.chart, child: Row(children: [const Icon(Icons.bar_chart_rounded, color: primaryColor), const SizedBox(width: 8), Text(context.read<LocaleProvider>().translate('hist_view_chart'))])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _historyMode == HistoryMode.water 
          ? StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.firebaseId)
            .collection('gunler')
            .orderBy('tarih', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text(context.read<LocaleProvider>().translate('hist_loading_error'), style: const TextStyle(color: secondaryText)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 80, color: secondaryText.withValues(alpha: 0.2)),
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
            content = _buildCalendarView(recordsMap, primaryColor, successColor, primaryText, secondaryText);
          } else if (_viewMode == ViewMode.chart) {
            content = _buildChartView(docs, primaryColor, successColor, primaryText, secondaryText);
          } else {
            content = _buildListView(docs, primaryColor, successColor, primaryText, secondaryText);
          }

          return Column(
            children: [
              Expanded(child: content),
            ],
          );
        },
      ) : FutureBuilder<Set<DateTime>>(
        future: context.read<DrinkProvider>().getDrinkDays(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFE8590C)));
          }
          final drinkDays = snapshot.data ?? {};
          Widget content;
          if (_viewMode == ViewMode.calendar) {
            content = _buildDrinkCalendarView(drinkDays, const Color(0xFFE8590C), primaryText, secondaryText);
          } else {
            content = _buildDrinkListView();
          }
          return Column(children: [Expanded(child: content)]);
        }
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
            locale: 'tr_TR',
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
              selectedDecoration: BoxDecoration(color: _historyMode == HistoryMode.water ? accentColor : const Color(0xFFE8590C), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: (_historyMode == HistoryMode.water ? accentColor : const Color(0xFFE8590C)).withValues(alpha: 0.3), shape: BoxShape.circle),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final stripped = _stripTime(day);
                if (_historyMode == HistoryMode.water && recordsMap.containsKey(stripped)) {
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

  Widget _buildDrinkCalendarView(Set<DateTime> drinkDays, Color accentColor, Color primaryText, Color secondaryText) {
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
            locale: 'tr_TR',
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
              todayDecoration: BoxDecoration(color: accentColor.withValues(alpha: 0.3), shape: BoxShape.circle),
              markersMaxCount: 1,
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                final stripped = _stripTime(day);
                if (drinkDays.contains(stripped)) {
                  return Positioned(
                    bottom: 6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFE8590C),
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
              : _buildDrinkDayDetails(_selectedDay!),
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
            Icon(Icons.no_drinks_rounded, size: 60, color: secondaryText.withValues(alpha: 0.3)),
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
                decoration: BoxDecoration(color: isHit ? successColor.withValues(alpha: 0.1) : Colors.orangeAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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

  Widget _buildDrinkDayDetails(DateTime day) {
    var user = context.read<UserProvider>().currentUser;
    if (user == null) return const SizedBox();

    String dateKey = "${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(user.firebaseId)
          .collection('drinks')
          .doc(dateKey)
          .collection('entries')
          .get(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFE8590C)));
        
        final lp = context.watch<LocaleProvider>();
        String localeStr = lp.locale.languageCode == 'tr' ? 'tr_TR' : 'en_US';
        String formattedDate = DateFormat('d MMMM yyyy, EEEE', localeStr).format(day);

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_cafe_outlined, size: 60, color: Colors.grey),
                const SizedBox(height: 16),
                Text('$formattedDate\n${lp.translate('drink_no_record')}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          );
        }

        final docs = snap.data!.docs;
        double totalCaf = 0;
        double totalSug = 0;
        List<DrinkEntry> entries = [];
        for (var doc in docs) {
          final entry = DrinkEntry.fromMap(doc.data() as Map<String, dynamic>);
          entries.add(entry);
          totalCaf += entry.caffeineAmount;
          totalSug += entry.sugarAmount;
        }

        entries.sort((a,b) => b.saat.compareTo(a.saat)); // En yeni en üstte

        bool isOver = totalCaf > DrinkProvider.caffeineLimit || totalSug > DrinkProvider.sugarLimit;
        Color cardColor = isOver ? Colors.red.shade50 : const Color(0xFFFFF3EE);
        Color textColor = isOver ? Colors.red : const Color(0xFFE8590C);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 16)),
              const SizedBox(height: 16),
              
              // Premium Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOver ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)] : [const Color(0xFFFF6B35), const Color(0xFFE8590C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: (isOver ? const Color(0xFFEF4444) : const Color(0xFFE8590C)).withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                      child: Icon(isOver ? Icons.warning_amber_rounded : Icons.local_cafe_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lp.translate('drink_day_summary').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            "${totalCaf.toStringAsFixed(0)}mg ${lp.translate('drink_caffeine')} · ${totalSug.toStringAsFixed(1)}g ${lp.translate('drink_sugar')}", 
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: -0.5)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text(lp.translate('drink_records'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              
              // Kayıt Listesi
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: const Color(0xFFFFF3EE), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.coffee_rounded, color: Color(0xFFE8590C), size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${entry.ml} ml', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text('${entry.caffeineAmount.toStringAsFixed(0)}mg ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                    const Icon(Icons.coffee, size: 10, color: Color(0xFF64748B)),
                                    const Text(' · ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    Text('${entry.sugarAmount.toStringAsFixed(1)}g ', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                    const Icon(Icons.cake, size: 10, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Text(entry.saat, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              showCupertinoDialog(
                                context: context,
                                builder: (ctx) => CupertinoAlertDialog(
                                  title: Text(lp.translate('drink_delete_title')),
                                  content: Text(lp.translate('drink_delete_msg')),
                                  actions: [
                                    CupertinoDialogAction(
                                      child: Text(lp.translate('prof_btn_cancel')),
                                      onPressed: () => Navigator.pop(ctx),
                                    ),
                                    CupertinoDialogAction(
                                      isDestructiveAction: true,
                                      child: Text(lp.translate('drink_delete_confirm')),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.firebaseId)
                                            .collection('drinks')
                                            .doc(dateKey)
                                            .collection('entries')
                                            .doc(entry.uid)
                                            .delete();
                                        
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 2. DETAYLI LİSTE MODU ──────────────────────────────
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
              color: isHit ? successColor.withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: isHit ? successColor.withValues(alpha: 0.1) : const Color(0xFFF0F9FF)),
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
                          Icon(Icons.circle, size: 8, color: accentColor.withValues(alpha: 0.5)),
                          const SizedBox(width: 12),
                          Text('${m['miktar']} ml', style: const TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('${m['saat']}', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    );
                  }),
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
                                  colors: isHit ? [successColor, successColor.withValues(alpha: 0.7)] : [accentColor, accentColor.withValues(alpha: 0.7)],
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: (isHit ? successColor : accentColor).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
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

  Future<List<DrinkEntry>> _fetchRecentDrinks() async {
    final dp = context.read<DrinkProvider>();
    final days = await dp.getDrinkDays();
    List<DrinkEntry> all = [];
    for (var date in days) {
      final dateKey = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      final entries = await dp.getDrinkEntriesForDay(dateKey);
      all.addAll(entries);
    }
    all.sort((a, b) => b.uid.compareTo(a.uid));
    return all.take(50).toList();
  }

  Widget _buildDrinkListView() {
    return FutureBuilder<List<DrinkEntry>>(
      future: _fetchRecentDrinks(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE8590C)));
        final list = snap.data!;
        if (list.isEmpty) {
          return Center(child: Text(context.watch<LocaleProvider>().translate('hist_no_data'), style: const TextStyle(color: Color(0xFF64748B))));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final entry = list[index];
            DateTime date = DateTime.fromMillisecondsSinceEpoch(int.parse(entry.uid));
            final lp = context.watch<LocaleProvider>();
            String loc = lp.locale.languageCode == 'tr' ? 'tr_TR' : 'en_US';
            String dateFormatted = DateFormat('dd MMM', loc).format(date);
            
            return Dismissible(
              key: Key(entry.uid),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
                child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
              ),
              confirmDismiss: (_) async {
                await context.read<DrinkProvider>().deleteDrink(entry);
                setState(() {});
                return true;
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                  boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3EE), borderRadius: BorderRadius.circular(18)),
                      child: const Icon(Icons.local_cafe_rounded, color: Color(0xFFE8590C), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(lp.translate('drink_type_${entry.drinkType.name}'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: -0.5)),
                              Text('+${entry.ml} ml', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFFE8590C))),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text("${entry.caffeineAmount.toStringAsFixed(0)}mg ", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w800)),
                              const Icon(Icons.coffee, size: 12, color: Color(0xFF64748B)),
                              const Text(" · ", style: TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w800)),
                              Text("${entry.sugarAmount.toStringAsFixed(1)}g ", style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w800)),
                              const Icon(Icons.cake, size: 12, color: Color(0xFF64748B)),
                              const Spacer(),
                              Text("$dateFormatted, ${entry.saat}", style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

