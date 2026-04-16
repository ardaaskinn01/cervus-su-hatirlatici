import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/water_wave_progress.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var waterProvider = context.watch<WaterProvider>();
    var userProvider = context.watch<UserProvider>();
    final lp = context.watch<LocaleProvider>();
    
    String displayName = userProvider.currentUser?.displayName ?? 'Kullanıcı';
    double progress = waterProvider.dailyGoal > 0 ? (waterProvider.currentIntake / waterProvider.dailyGoal).clamp(0.0, 99.0) : 0.0;
    
    // Design System Colors
    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const primaryColor = Color(0xFF0EA5E9);
    const accentColor = Color(0xFF22C55E);
    const scaffoldBg = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                // ─── Özel Header ─────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '${context.watch<LocaleProvider>().translate('onb_welcome')}, $displayName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 28, height: 1.2, fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.watch<LocaleProvider>().translate('home_mot_mid'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: secondaryText, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // ─── Su Göstergesi (Sürahi Formu) ────────────────────
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arkaplan yumuşak parıltı (Sürahiye uyumlu)
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.rectangle,
                          borderRadius: BorderRadius.circular(150),
                          boxShadow: [
                            BoxShadow(color: primaryColor.withOpacity(0.08), blurRadius: 60, spreadRadius: 20),
                          ],
                        ),
                      ),
                      WaterWaveProgress(progress: progress, size: 280),
                      // Yazıları sürahi gövdesine ortalamak için hafif aşağı kaydırıyoruz
                      Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${waterProvider.currentIntake}',
                              style: const TextStyle(
                                fontSize: 60, fontWeight: FontWeight.w900, color: primaryText,
                                letterSpacing: -2,
                              ),
                            ),
                            Text(
                              '/ ${waterProvider.dailyGoal} ml',
                              style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold, color: secondaryText.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // ─── Hedef Banner ─────────────────────────────────────
                if (progress >= 1.0)
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 32),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: const Color(0xFF22C55E).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(context.watch<LocaleProvider>().translate('home_mot_done').split('!')[0] + '!', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                              const SizedBox(height: 4),
                              Text(context.watch<LocaleProvider>().translate('home_mot_done'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Su Ekleme Butonları (Kategori Bazlı) ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWaterCard(
                      context, 
                      icon: Icons.local_drink_rounded, 
                      label: lp.translate('home_container_glass'), 
                      amount: null, 
                      onTap: () => _showContainerSelection(context, isGlass: true)
                    ),
                    _buildWaterCard(
                      context, 
                      icon: Icons.liquor_rounded, 
                      label: lp.translate('home_container_bottle'), 
                      amount: null, 
                      onTap: () => _showContainerSelection(context, isGlass: false)
                    ),
                    _buildWaterCard(
                      context, 
                      icon: Icons.add_rounded, 
                      label: lp.translate('home_btn_add'), 
                      amount: null, 
                      isFeatured: true, 
                      onTap: () => _showCustomAmountDialog(context)
                    ),
                  ],
                ),

                const SizedBox(height: 48),

                // ─── Son 5 İçme Listesi ────────────────────────────────
                _buildLastFiveSection(context, waterProvider),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLastFiveSection(BuildContext context, WaterProvider waterProvider) {
    final records = waterProvider.lastFiveRecords;
    if (records.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.watch<LocaleProvider>().translate('home_recent'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        ...records.map((kaydi) => Dismissible(
          key: Key(kaydi.uid),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
            child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
          ),
          confirmDismiss: (_) async {
            await context.read<WaterProvider>().deleteWaterRecord(kaydi);
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
                  decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0EA5E9), size: 24),
                ),
                const SizedBox(width: 16),
                Text(context.watch<LocaleProvider>().translate('home_consumed'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('+${kaydi.miktar} ml', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0EA5E9))),
                    const SizedBox(height: 4),
                    Text(kaydi.saat, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildWaterCard(BuildContext context, {required IconData icon, required String label, required int? amount, bool isFeatured = false, required VoidCallback onTap}) {
    const primaryColor = Color(0xFF0EA5E9);
    const accentColor = Color(0xFF22C55E);
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
                color: isFeatured ? accentColor : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isFeatured ? accentColor : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isFeatured 
                        ? accentColor.withOpacity(0.25) 
                        : const Color(0xFFE2E8F0).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFeatured 
                          ? Colors.white.withOpacity(0.2) 
                          : primaryColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon, 
                      size: 24, 
                      color: isFeatured ? Colors.white : primaryColor
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    label, // Asıl başlık burası (Bardak, Şişe, Özel) ✅🎯
                    style: TextStyle(
                      fontWeight: FontWeight.w900, 
                      fontSize: 18, 
                      color: isFeatured ? Colors.white : primaryText,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    amount != null ? '$amount ML' : 'ML', // Alt miktar ✅🎯
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.w800, 
                      color: isFeatured ? Colors.white70 : const Color(0xFF94A3B8),
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
    final options = isGlass 
      ? [
          {'label': lp.translate('home_size_small'), 'ml': 100, 'icon': Icons.water_drop_outlined},
          {'label': lp.translate('home_size_medium'), 'ml': 200, 'icon': Icons.opacity},
          {'label': lp.translate('home_size_large'), 'ml': 300, 'icon': Icons.water_drop_rounded},
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
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Text(
              isGlass ? lp.translate('home_container_glass') : lp.translate('home_container_bottle'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 12),
            Text(lp.translate('home_dialog_subtitle'), style: const TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 32),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.4),
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final opt = options[index];
                  return Material(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () {
                        context.read<WaterProvider>().addWater(opt['ml'] as int);
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(border: Border.all(color: const Color(0xFFF1F5F9)), borderRadius: BorderRadius.circular(24)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(opt['icon'] as IconData, color: const Color(0xFF0EA5E9)),
                            const SizedBox(height: 8),
                            Text(opt['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            Text('${opt['ml']} ml', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
      builder: (dialogContext) => BackdropFilter( // Cam bulanıklığı efekti
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          title: Text(context.read<LocaleProvider>().translate('home_dialog_custom'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 22)),
          content: Container(
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: TextField(
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0EA5E9)),
              decoration: const InputDecoration(
                hintText: '250',
                hintStyle: TextStyle(color: Color(0xFFCBD5E1)),
                suffixText: 'ml ',
                constraints: BoxConstraints(minHeight: 70),
                suffixStyle: TextStyle(fontSize: 18, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 20),
              ),
              onChanged: (val) => customAmount = int.tryParse(val) ?? 0,
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          contentPadding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 8),
          actionsPadding: const EdgeInsets.only(bottom: 24, left: 24, right: 24, top: 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext), 
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    child: Text(context.read<LocaleProvider>().translate('home_dialog_cancel'), style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (customAmount > 0) context.read<WaterProvider>().addWater(customAmount);
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(context.read<LocaleProvider>().translate('home_dialog_add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
