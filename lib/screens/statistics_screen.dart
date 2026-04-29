import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/drink_provider.dart';
import '../models/drink_model.dart';
import '../providers/locale_provider.dart';
import 'today_records_screen.dart';
import 'history_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late Future<List<bool>> _weeklyFuture;
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<Map<String, dynamic>> _drinkStatsFuture;

  late TabController _tabController;

  // Design System Colors
  final Color primaryText = const Color(0xFF0F172A);
  final Color secondaryText = const Color(0xFF64748B);
  final Color accentColor = const Color(0xFF0EA5E9);
  final Color scaffoldBg = const Color(0xFFF8FAFC);
  final Color primaryOrange = const Color(0xFFE8590C);


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) setState((){});
    });
    _refreshData();
  }

  void _refreshData() {
    final wp = context.read<WaterProvider>();
    final dp = context.read<DrinkProvider>();
    _weeklyFuture = wp.getWeeklyConsistency();
    _statsFuture = wp.getAdvancedStats();
    _drinkStatsFuture = dp.getWeeklyStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
            icon: Icon(Icons.list_alt_rounded, color: _tabController.index == 0 ? const Color(0xFF0EA5E9) : primaryOrange),
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: primaryText,
          unselectedLabelColor: secondaryText,
          indicatorColor: _tabController.index == 0 ? accentColor : primaryOrange,
          indicatorWeight: 3,
          tabs: [
            Tab(text: "💧 ${context.read<LocaleProvider>().translate('drink_water_history').split(' ')[0]}"),
            Tab(text: "☕ ${context.read<LocaleProvider>().translate('drink_title').split(' ')[0]}"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWaterTab(streak),
          _buildDrinkTab(),
        ],
      ),
    );
  }

  Widget _buildWaterTab(int streak) {
    return RefreshIndicator(
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
    );
  }

  Widget _buildDrinkTab() {
    return RefreshIndicator(
      color: primaryOrange,
      onRefresh: () async {
        setState(() => _refreshData());
      },
      child: FutureBuilder<Map<String, dynamic>>(
        future: _drinkStatsFuture,
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: primaryOrange)));
          final stats = snap.data!;
          final dp = context.watch<DrinkProvider>();
          final lp = context.watch<LocaleProvider>();
          
          List<double> caffData = stats['caffeineData'];
          List<double> sugData = stats['sugarData'];
          List<bool> consistency = stats['consistency'] ?? List.filled(7, false);
          Map<DrinkType, int> types = stats['types'];

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              _buildDrinkStreakCard(dp.drinkStreakCount),
              const SizedBox(height: 36),
              
              _buildSoftDrinkHeadline(lp.translate('drink_stats_health')),
              _buildWeeklyGrid(consistency),
              const SizedBox(height: 24),
              _buildAnalysisCard(
                title: lp.translate('drink_avg_caf'),
                value: "${stats['avgCaffeine'].toStringAsFixed(0)} mg",
                description: "",
                color: primaryOrange,
                icon: Icons.coffee_rounded,
              ),
              const SizedBox(height: 16),
              _buildAnalysisCard(
                title: lp.translate('drink_avg_sug'),
                value: "${stats['avgSugar'].toStringAsFixed(1)} g",
                description: "",
                color: Colors.amber.shade700,
                icon: Icons.cake_rounded,
              ),
              const SizedBox(height: 16),
              _buildAnalysisCard(
                title: lp.translate('drink_health_score'),
                value: "%${stats['healthScore']}",
                description: "",
                color: stats['healthScore'] >= 70 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                icon: Icons.health_and_safety_rounded,
              ),
              const SizedBox(height: 36),
              
              _buildSoftDrinkHeadline(lp.translate('drink_stats_caf')),
              _buildBarChart(caffData, DrinkProvider.caffeineLimit, "mg", primaryOrange),
              const SizedBox(height: 36),

              _buildSoftDrinkHeadline(lp.translate('drink_stats_sug')),
              _buildBarChart(sugData, DrinkProvider.sugarLimit, "g", Colors.amber),
              const SizedBox(height: 36),

              _buildSoftDrinkHeadline(lp.translate('drink_stats_dist')),
              if (types.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: Text(lp.translate('drink_empty_state'), style: const TextStyle(color: Colors.grey))),
                )
              else
                _buildTypesDistribution(types, lp),

              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDrinkStreakCard(int streak) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFE8590C)], 
          begin: Alignment.topLeft, 
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE8590C).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 12)),
          BoxShadow(color: Colors.white.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(-5, -5)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100)),
                  child: Text(context.watch<LocaleProvider>().translate('drink_streak').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$streak', style: const TextStyle(fontSize: 56, color: Colors.white, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -3)),
                    const SizedBox(width: 8),
                    Text(context.watch<LocaleProvider>().translate('home_streak_days'), style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department_rounded, size: 88, color: Colors.white.withValues(alpha: 0.25)),
        ],
      ),
    );
  }

  Widget _buildSoftDrinkHeadline(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, left: 4),
      child: Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: primaryOrange, letterSpacing: -0.5)),
    );
  }

  Widget _buildBarChart(List<double> data, double limit, String unit, Color baseColor) {
    final days = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    double maxData = data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);
    double highest = maxData > limit ? maxData : limit;
    if (highest == 0) highest = 1;

    return Container(
      height: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 8))],
      ),
      child: Stack(
        children: [
          // Limit line with label
          Positioned(
            bottom: (limit / highest) * 120 + 28,
            left: 0,
            right: 0,
            child: Row(
              children: [
                Expanded(child: Container(height: 1.5, decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(1)))),
                const SizedBox(width: 8),
                Text("${limit.toInt()}$unit", style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              if (index >= data.length) return const SizedBox();
              double val = data[index];
              bool overLimit = val > limit;
              double heightRatio = val / highest;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          width: 24,
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutBack,
                          width: 24,
                          height: heightRatio * 130,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: overLimit 
                                ? [Colors.red.shade300, Colors.red.shade600] 
                                : [baseColor.withValues(alpha: 0.7), baseColor],
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              if (val > 0) BoxShadow(color: (overLimit ? Colors.red : baseColor).withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(days[index], style: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w800)),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTypesDistribution(Map<DrinkType, int> types, LocaleProvider lp) {
    int total = types.values.fold(0, (sum, val) => sum + val);

    final names = {
      DrinkType.turkishCoffee: lp.translate('drink_type_turkishCoffee'),
      DrinkType.coffee: lp.translate('drink_type_coffee'),
      DrinkType.milkCoffee: lp.translate('drink_type_milkCoffee'),
      DrinkType.tea: lp.translate('drink_type_tea'),
      DrinkType.icedTea: lp.translate('drink_type_icedTea'),
      DrinkType.fruitJuice: lp.translate('drink_type_fruitJuice'),
      DrinkType.cola: lp.translate('drink_type_cola'),
      DrinkType.fruitSoda: lp.translate('drink_type_fruitSoda'),
      DrinkType.lemonade: lp.translate('drink_type_lemonade'),
    };

    final sortedEntries = types.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        children: sortedEntries.map((e) {
          double percent = (e.value / total) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text(names[e.key] ?? "?", style: const TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                  flex: 5,
                  child: Stack(
                    children: [
                      Container(height: 12, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(6))),
                      Container(height: 12, width: (percent / 100) * 150, decoration: BoxDecoration(color: primaryOrange, borderRadius: BorderRadius.circular(6))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text("%${percent.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          );
        }).toList(),
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
        boxShadow: [BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(100)),
                  child: Text(context.watch<LocaleProvider>().translate('home_streak').toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('$streak', style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -2)),
                    const SizedBox(width: 8),
                    Text('GÜN', style: TextStyle(fontSize: 18, color: Colors.white.withValues(alpha: 0.8), fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.local_fire_department_rounded, size: 80, color: Colors.white.withValues(alpha: 0.25)),
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
                  boxShadow: isHit ? [BoxShadow(color: const Color(0xFF22C55E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
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
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
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
