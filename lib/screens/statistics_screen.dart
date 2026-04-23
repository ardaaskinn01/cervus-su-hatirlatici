import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../widgets/ad_container.dart';
import '../providers/locale_provider.dart';
import 'today_records_screen.dart';
import 'history_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late Future<List<bool>> _weeklyFuture;
  late Future<Map<String, dynamic>> _statsFuture;

  // Design System Colors
  final Color primaryText = const Color(0xFF0F172A);
  final Color secondaryText = const Color(0xFF64748B);
  final Color accentColor = const Color(0xFF0EA5E9);
  final Color scaffoldBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    final wp = context.read<WaterProvider>();
    _weeklyFuture = wp.getWeeklyConsistency();
    _statsFuture = wp.getAdvancedStats();
  }

  @override
  Widget build(BuildContext context) {
    var streak = context.watch<WaterProvider>().streakCount;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(context.watch<LocaleProvider>().translate('drawer_stats'), style: TextStyle(color: primaryText, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF0EA5E9)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayRecordsScreen())),
            tooltip: 'Bugün',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded, color: Color(0xFF64748B)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen())),
            tooltip: 'Geçmiş',
          ),
          const SizedBox(width: 8),
        ],
        centerTitle: true,
      ),
      body: RefreshIndicator(
        color: accentColor,
        onRefresh: () async {
          setState(() => _refreshData());
        },
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          children: [
            _buildStreakCard(streak),
            const SizedBox(height: 36),
            _buildHeadline(context.watch<LocaleProvider>().translate('stats_weekly')),
            FutureBuilder<List<bool>>(
              future: _weeklyFuture,
              builder: (context, snap) {
                if (!snap.hasData) return Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: accentColor)));
                return _buildWeeklyGrid(snap.data!);
              },
            ),
            const SizedBox(height: 36),
            _buildHeadline(context.watch<LocaleProvider>().translate('stats_general')),
            FutureBuilder<Map<String, dynamic>>(
              future: _statsFuture,
              builder: (context, snap) {
                if (!snap.hasData) return Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: accentColor)));
                final stats = snap.data!;
                return Column(
                  children: [
                    _buildAnalysisCard(
                      title: context.watch<LocaleProvider>().translate('stats_avg'),
                      value: "${stats['avg']} ml",
                      description: "",
                      color: const Color(0xFF0EA5E9),
                      icon: Icons.analytics_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildAnalysisCard(
                      title: context.watch<LocaleProvider>().translate('stats_rate'),
                      value: "%${stats['rate']}",
                      description: "",
                      color: const Color(0xFF22C55E),
                      icon: Icons.track_changes_rounded,
                    ),
                    const SizedBox(height: 16),
                    _buildAnalysisCard(
                      title: context.watch<LocaleProvider>().translate('stats_trend'),
                      value: context.watch<LocaleProvider>().translate(stats['status']),
                      description: "",
                      color: const Color(0xFF8B5CF6),
                      icon: Icons.health_and_safety_rounded,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primaryText, letterSpacing: -0.5)),
    );
  }

  Widget _buildStreakCard(int streak) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(100)),
                  child: Text(context.watch<LocaleProvider>().translate('home_streak').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$streak', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2)),
                    const SizedBox(width: 8),
                    Text('GÜN', style: TextStyle(fontSize: 18, color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department_rounded, size: 80, color: Colors.white.withOpacity(0.25)),
        ],
      ),
    );
  }

  Widget _buildWeeklyGrid(List<bool> consistency) {
    final days = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (index) {
          bool isHit = index < consistency.length && consistency[index];
          return Column(
            children: [
              Text(days[index], style: TextStyle(color: isHit ? primaryText : secondaryText, fontSize: 14, fontWeight: isHit ? FontWeight.bold : FontWeight.w600)),
              const SizedBox(height: 16),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isHit ? const Color(0xFF22C55E) : const Color(0xFFF8FAFC),
                  border: Border.all(color: isHit ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
                  boxShadow: isHit ? [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
                ),
                child: isHit ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildAnalysisCard({required String title, required String value, required String description, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: secondaryText)),
                const SizedBox(height: 6),
                Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(description, style: TextStyle(fontSize: 13, color: secondaryText, height: 1.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
