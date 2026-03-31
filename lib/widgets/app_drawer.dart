import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/history_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    var user = context.watch<UserProvider>().currentUser;
    String name = user?.displayName ?? 'Misafir';

    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const accentColor = Color(0xFF0EA5E9);

    return SafeArea(
      child: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(32))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Header ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 40, bottom: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFFF0F9FF),
                      radius: 28,
                      child: Icon(Icons.person_rounded, size: 36, color: accentColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(color: primaryText, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                        const Text('Hidrasyon Yolculuğu', style: TextStyle(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // ─── Navigasyon ─────────────────────────────────────────
            _NavTile(icon: Icons.water_drop_rounded, label: 'Ana Ekran', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            }),
            _NavTile(icon: Icons.bar_chart_rounded, label: 'Analiz Merkezi', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
            }),
            _NavTile(icon: Icons.history_rounded, label: 'Geçmiş Kayıtlar', onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
            }),
            _NavTile(icon: Icons.settings_rounded, label: 'Ayarlar', onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),

            const Spacer(),

            // ─── Günlük Su İçmeler (Drawer Alt Bölüm) ───────────────
            Container(
              padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('BUGÜNKÜ İŞLEMLER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: secondaryText, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220, // Drawer listesi için alan
                    child: _DailyWaterList(user: user),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Günlük Su İçme Listesi Widget'ı ─────────────────────────────
class _DailyWaterList extends StatelessWidget {
  final UserModel? user;
  const _DailyWaterList({this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    
    var waterProvider = context.watch<WaterProvider>();
    final dateKey = waterProvider.getLogicalDateKey();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.firebaseId).collection('gunler').doc(dateKey).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(child: Text('Henüz su içmedin.\nHaydi başla! 💧', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), height: 1.5, fontWeight: FontWeight.w500)));
        }

        final data = snap.data!.data() as Map<String, dynamic>;
        final rawList = (data['suIcildi'] as List<dynamic>? ?? []).reversed.toList();

        if (rawList.isEmpty) {
          return const Center(child: Text('Henüz su içmedin.\nHaydi başla! 💧', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF94A3B8), height: 1.5, fontWeight: FontWeight.w500)));
        }

        return ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: rawList.length,
          itemBuilder: (context, index) {
            final kaydi = SuKaydi.fromMap(Map<String, dynamic>.from(rawList[index]));
            return Dismissible(
              key: Key('drawer-${kaydi.saat}-${kaydi.miktar}-$index'),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
              ),
              confirmDismiss: (_) async {
                await waterProvider.deleteWaterRecord(kaydi, dateKey);
                return false;
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.water_drop, color: Color(0xFF0EA5E9), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(kaydi.saat, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('+${kaydi.miktar}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
                    const Text(' ml', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF94A3B8))),
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

// ─── Navigasyon Menü Elemanı ──────────────────────────────────────
class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0EA5E9), size: 26),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        hoverColor: const Color(0xFFF0F9FF),
        splashColor: const Color(0xFFF0F9FF),
      ),
    );
  }
}
