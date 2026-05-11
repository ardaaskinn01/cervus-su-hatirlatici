import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';
import '../widgets/water_wave_progress.dart';
import '../widgets/drinks_entry_sheet.dart';
import '../providers/drink_provider.dart';
import '../services/rewarded_ad_service.dart';
import '../models/drink_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _drinkUnlocked = false;

  static const Map<DrinkType, Color> drinkColors = {
    DrinkType.turkishCoffee: Color(0xFF6F4E37),
    DrinkType.coffee: Color(0xFF8B5E3C),
    DrinkType.milkCoffee: Color(0xFFD2A679),
    DrinkType.tea: Color(0xFFB5451B),
    DrinkType.icedTea: Color(0xFFD4A017),
    DrinkType.fruitJuice: Color(0xFFFF8C00),
    DrinkType.cola: Color(0xFF1A0000),
    DrinkType.fruitSoda: Color(0xFFFF69B4),
    DrinkType.lemonade: Color(0xFFFFD700),
  };

  static const Map<DrinkType, int> drinkMaxMl = {
    DrinkType.turkishCoffee: 300,
    DrinkType.coffee: 400,
    DrinkType.milkCoffee: 400,
    DrinkType.tea: 500,
    DrinkType.icedTea: 600,
    DrinkType.fruitJuice: 400,
    DrinkType.cola: 700,
    DrinkType.fruitSoda: 600,
    DrinkType.lemonade: 500,
  };

  @override
  Widget build(BuildContext context) {
    var waterProvider = context.watch<WaterProvider>();
    var userProvider = context.watch<UserProvider>();
    var dp = context.watch<DrinkProvider>();
    final lp = context.watch<LocaleProvider>();

    String displayName = userProvider.currentUser?.displayName ?? lp.translate('home_default_user');
    double progress =
        waterProvider.dailyGoal > 0
            ? (waterProvider.currentIntake / waterProvider.dailyGoal).clamp(
              0.0,
              99.0,
            )
            : 0.0;

    // Group drinks by type to calculate ml fillings
    Map<DrinkType, int> drinkTotals = {};
    for (var drink in dp.todayDrinks) {
      drinkTotals[drink.drinkType] =
          (drinkTotals[drink.drinkType] ?? 0) + drink.ml;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(
            top: 8,
            left: 24,
            right: 24,
            bottom: 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Text
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${lp.translate('onb_welcome')}, $displayName',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lp.translate('home_mot_mid'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left Cup (Caffeine)
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        ClipPath(
                          clipper: _CupClipper(),
                          child: Container(
                            height: 80,
                            color: const Color(0xFFE2E8F0),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                FractionallySizedBox(
                                  heightFactor: (dp.dailyCaffeine / DrinkProvider.caffeineLimit).clamp(0.0, 1.0),
                                  widthFactor: 1.0,
                                  child: Container(color: const Color(0xFFE8590C)),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${dp.dailyCaffeine.round()} mg', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 16)),
                                      Text('/ ${DrinkProvider.caffeineLimit.toInt()} mg', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(lp.translate('drink_caffeine'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle Cup (Water)
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipPath(
                              clipper: _CupClipper(),
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: 160,
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  WaterWaveProgress(progress: progress, size: 160),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('${waterProvider.currentIntake}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -1)),
                                Text('/ ${waterProvider.dailyGoal} ml', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF64748B).withValues(alpha: 0.7))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(lp.translate('nav_water'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right Cup (Sugar)
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        ClipPath(
                          clipper: _CupClipper(),
                          child: Container(
                            height: 80,
                            color: const Color(0xFFE2E8F0),
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                FractionallySizedBox(
                                  heightFactor: (dp.dailySugar / DrinkProvider.sugarLimit).clamp(0.0, 1.0),
                                  widthFactor: 1.0,
                                  child: Container(color: Colors.amber.shade700),
                                ),
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('${dp.dailySugar.round()} g', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87, fontSize: 16)),
                                      Text('/ ${DrinkProvider.sugarLimit.toInt()} g', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(lp.translate('drink_sugar'), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.local_drink_rounded,
                      label: lp.translate('home_container_glass'),
                      amount: null,
                      themeColor: const Color(0xFF0EA5E9),
                      onTap: () => _showContainerSelection(context, isGlass: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.liquor_rounded,
                      label: lp.translate('home_container_bottle'),
                      amount: null,
                      themeColor: const Color(0xFF0EA5E9),
                      onTap: () => _showContainerSelection(context, isGlass: false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionCard(
                      context,
                      icon: Icons.add_rounded,
                      label: lp.translate('home_btn_add'),
                      amount: null,
                      themeColor: const Color(0xFF0EA5E9),
                      isFeatured: true,
                      onTap: () => _showCustomAmountDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Small Drinks Cups
              if (drinkTotals.isNotEmpty) ...[
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children:
                      drinkTotals.entries.map((entry) {
                        final type = entry.key;
                        final totalMl = entry.value;
                        final maxMl = drinkMaxMl[type] ?? 500;
                        final color = drinkColors[type] ?? Colors.brown;
                        final fillRatio = (totalMl / maxMl).clamp(0.0, 1.0);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  FractionallySizedBox(
                                    heightFactor: fillRatio,
                                    widthFactor: 1.0,
                                    child: Container(color: color),
                                  ),
                                  Center(
                                    child: Text(
                                      '$totalMl',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        shadows: [Shadow(color: Colors.black45, blurRadius: 2)],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lp.translate('drink_type_${type.name}'),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                            ),
                          ],
                        );
                      }).toList(),
                ),
                const SizedBox(height: 40),
              ],

              _buildSoftDrinkSelector(
                context,
                userProvider.isPremium,
                lp,
              ),
              const SizedBox(height: 40),

              _buildLastFiveSection(context, waterProvider, lp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftDrinkSelector(
    BuildContext context,
    bool isPremium,
    LocaleProvider lp,
  ) {
    final types = DrinkType.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isPremium && !_drinkUnlocked) ...[
          ElevatedButton.icon(
            onPressed: () async {
              bool success = await RewardedAdService.show(context);
              if (success) {
                setState(() {
                  _drinkUnlocked = true;
                });
              }
            },
            icon: const Icon(Icons.movie_creation_rounded),
            label: Text(lp.translate('home_watch_ad_btn')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE8590C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                lp.translate('pro_or_ad'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.9,
          children: types.map((type) {
            final color = drinkColors[type] ?? Colors.brown;
            final name = lp.translate('drink_type_${type.name}');
            final isPremium = context.watch<UserProvider>().isPremium;
            final isLocked = !isPremium && !_drinkUnlocked;

            return Opacity(
              opacity: isLocked ? 0.4 : 1.0,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap:
                      isLocked
                          ? null
                          : () async {
                            await showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder:
                                  (context) =>
                                      DrinksEntrySheet(preselectedType: type),
                            );
                            if (_drinkUnlocked) {
                              setState(() {
                                _drinkUnlocked = false; // Lock immediately after one use
                              });
                            }
                          },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFF1F5F9)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_cafe_rounded,
                          color: color,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          name,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLastFiveSection(
    BuildContext context,
    WaterProvider waterProvider,
    LocaleProvider lp,
  ) {
    final waterRecords = waterProvider.todayRecords;
    final drinkEntries = context.watch<DrinkProvider>().todayDrinks;

    final combined = [
      ...waterRecords.map((r) => {'type': 'water', 'data': r, 'time': r.saat}),
      ...drinkEntries.map((d) => {'type': 'drink', 'data': d, 'time': d.saat}),
    ];
    
    combined.sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
    final lastFive = combined.take(5).toList();

    if (lastFive.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lp.translate('home_recent'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5),
        ),
        const SizedBox(height: 16),
        ...lastFive.map((item) {
          final isWater = item['type'] == 'water';
          final String title;
          final IconData icon;
          final Color iconColor;
          final int amount;
          final String time = item['time'] as String;

          if (isWater) {
            final r = item['data'] as SuKaydi;
            title = lp.translate('nav_water');
            icon = Icons.water_drop_rounded;
            iconColor = const Color(0xFF0EA5E9);
            amount = r.miktar;
          } else {
            final d = item['data'] as DrinkEntry;
            title = lp.translate('drink_type_${d.drinkType.name}');
            icon = Icons.local_cafe_rounded;
            iconColor = drinkColors[d.drinkType] ?? Colors.brown;
            amount = d.ml;
          }

          return Dismissible(
            key: Key(isWater ? (item['data'] as SuKaydi).uid : (item['data'] as DrinkEntry).uid),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
            ),
            confirmDismiss: (_) async {
              if (isWater) {
                await context.read<WaterProvider>().deleteWaterRecord(item['data'] as SuKaydi);
              } else {
                await context.read<DrinkProvider>().deleteDrink(item['data'] as DrinkEntry);
              }
              return false;
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '+$amount ml',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: iconColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        time,
                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int? amount,
    bool isFeatured = false,
    Color themeColor = const Color(0xFF0EA5E9),
    required VoidCallback onTap,
  }) {
    const primaryText = Color(0xFF0F172A);

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: isFeatured ? themeColor : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isFeatured ? themeColor : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isFeatured
                            ? themeColor.withValues(alpha: 0.25)
                            : const Color(0xFFE2E8F0).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          isFeatured
                              ? Colors.white.withValues(alpha: 0.2)
                              : themeColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 24,
                      color: isFeatured ? Colors.white : themeColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: isFeatured ? Colors.white : primaryText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    amount != null ? '$amount ML' : 'ML',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color:
                          isFeatured ? Colors.white70 : const Color(0xFF94A3B8),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showContainerSelection(BuildContext context, {required bool isGlass}) {
    final lp = context.read<LocaleProvider>();
    final options =
        isGlass
            ? [
              {
                'label': lp.translate('home_size_small'),
                'ml': 100,
                'icon': Icons.water_drop_outlined,
              },
              {
                'label': lp.translate('home_size_medium'),
                'ml': 200,
                'icon': Icons.opacity,
              },
              {
                'label': lp.translate('home_size_large'),
                'ml': 300,
                'icon': Icons.water_drop_rounded,
              },
            ]
            : [
              {'label': '33 cl', 'ml': 330, 'icon': Icons.wine_bar_rounded},
              {'label': '50 cl', 'ml': 500, 'icon': Icons.liquor_rounded},
              {'label': '1 L', 'ml': 1000, 'icon': Icons.waves_rounded},
              {'label': '1.5 L', 'ml': 1500, 'icon': Icons.water_rounded},
            ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isGlass
                      ? lp.translate('home_container_glass')
                      : lp.translate('home_container_bottle'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  lp.translate('home_dialog_subtitle'),
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 32),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.4,
                        ),
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final opt = options[index];
                      return Material(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(24),
                        child: InkWell(
                          onTap: () {
                            context.read<WaterProvider>().addWater(
                              opt['ml'] as int,
                            );
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  opt['icon'] as IconData,
                                  color: const Color(0xFF0EA5E9),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  opt['label'] as String,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                Text(
                                  '${opt['ml']} ml',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }

  void _showCustomAmountDialog(BuildContext context) {
    int customAmount = 0;
    showDialog(
      context: context,
      builder:
          (dialogContext) => BackdropFilter(
            // Cam bulanıklığı efekti
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(32),
              ),
              title: Text(
                context.read<LocaleProvider>().translate('home_dialog_custom'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontSize: 22,
                ),
              ),
              content: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0EA5E9),
                  ),
                  decoration: const InputDecoration(
                    hintText: '250',
                    hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                    suffixText: 'ml ',
                    constraints: BoxConstraints(minHeight: 70),
                    suffixStyle: TextStyle(
                      fontSize: 18,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 20),
                  ),
                  onChanged: (val) => customAmount = int.tryParse(val) ?? 0,
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              contentPadding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 8,
              ),
              actionsPadding: const EdgeInsets.only(
                bottom: 24,
                left: 24,
                right: 24,
                top: 16,
              ),
              actions: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.read<LocaleProvider>().translate(
                            'home_dialog_cancel',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (customAmount > 0) {
                            context.read<WaterProvider>().addWater(
                              customAmount,
                            );
                          }
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22C55E),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.read<LocaleProvider>().translate(
                            'home_dialog_add',
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}

class _CupClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    ));
    return path;
  }

  @override
  bool shouldReclip(_CupClipper oldClipper) => false;
}
