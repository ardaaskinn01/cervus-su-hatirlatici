import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/water_provider.dart';
import '../providers/user_provider.dart';
import '../widgets/water_wave_progress.dart';
import '../widgets/app_drawer.dart';
import 'profile_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var waterProvider = context.watch<WaterProvider>();
    var userProvider = context.watch<UserProvider>();
    
    String displayName = userProvider.currentUser?.displayName ?? 'Kullanıcı';
    double progress = waterProvider.dailyGoal > 0 ? (waterProvider.currentIntake / waterProvider.dailyGoal).clamp(0.0, 99.0) : 0.0;
    
    // Design System Colors
    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const accentColor = Color(0xFF0EA5E9);
    const scaffoldBg = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
                ),
                child: const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person_outline_rounded, size: 20, color: accentColor),
                ),
              ),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
            ),
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // ─── Karşılama ───────────────────────────────────
                Text(
                  'Merhaba,\n$displayName',
                  style: const TextStyle(fontSize: 32, height: 1.1, fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bugünkü su hedefine ulaşmak için içmeye devam et 💧',
                  style: TextStyle(fontSize: 15, color: secondaryText, fontWeight: FontWeight.w500),
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
                            BoxShadow(color: accentColor.withOpacity(0.08), blurRadius: 60, spreadRadius: 20),
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
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Muazzam İrade!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
                              SizedBox(height: 4),
                              Text('Günlük hedefine başarıyla ulaştın.', style: TextStyle(color: Colors.white70, fontSize: 14)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // ─── Su Ekleme Butonları ───────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildWaterCard(context, icon: Icons.local_drink_outlined, label: 'Yarım', amount: 100, onTap: () => context.read<WaterProvider>().addWater(100)),
                    _buildWaterCard(context, icon: Icons.local_drink_rounded, label: 'Tam Bardak', amount: 200, isFeatured: true, onTap: () => context.read<WaterProvider>().addWater(200)),
                    _buildWaterCard(context, icon: Icons.add_circle_outline_rounded, label: 'Özel', amount: null, onTap: () => _showCustomAmountDialog(context)),
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
        const Text('Son İşlemler', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -0.5)),
        const SizedBox(height: 16),
        ...records.map((kaydi) => Dismissible(
          key: Key('${kaydi.saat}-${kaydi.miktar}'),
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
                const Text('Su İçildi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
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
    Color bgColor = isFeatured ? const Color(0xFF0EA5E9) : Colors.white;
    Color iconColor = isFeatured ? Colors.white : const Color(0xFF0EA5E9);
    Color textColor = isFeatured ? Colors.white : const Color(0xFF0F172A);
    Color subTextColor = isFeatured ? Colors.white.withOpacity(0.8) : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        splashColor: const Color(0xFF0EA5E9).withOpacity(0.1),
        highlightColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.26,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isFeatured ? Colors.transparent : const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: isFeatured 
              ? [BoxShadow(color: const Color(0xFF0EA5E9).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))] 
              : [const BoxShadow(color: Color(0x33E2E8F0), blurRadius: 15, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: iconColor),
              const SizedBox(height: 12),
              Text(amount != null ? '+$amount ml' : 'Özel İşlem', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: textColor, letterSpacing: -0.5)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w600)),
            ],
          ),
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
          title: const Text('Özel Miktar 💧', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A), fontSize: 22)),
          content: Container(
            decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
            child: TextField(
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0EA5E9)),
              decoration: const InputDecoration(
                hintText: '330',
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
                    child: const Text('İptal', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontSize: 16)),
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
                      backgroundColor: const Color(0xFF0EA5E9),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Ekle', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
