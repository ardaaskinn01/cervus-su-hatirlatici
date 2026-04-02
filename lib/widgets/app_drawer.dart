import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/user_provider.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/statistics_screen.dart';
import '../screens/history_screen.dart';
import '../screens/today_records_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    var user = context.watch<UserProvider>();
    String name = user.currentUser?.displayName ?? 'Misafir';

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
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // ─── Navigasyon ─────────────────────────────────────────
            _NavTile(icon: Icons.water_drop_rounded, label: context.watch<LocaleProvider>().translate('drawer_home'), onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
            }),
            _NavTile(icon: Icons.bar_chart_rounded, label: context.watch<LocaleProvider>().translate('drawer_stats'), onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
            }),
            _NavTile(icon: Icons.settings_rounded, label: context.watch<LocaleProvider>().translate('drawer_settings'), onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),

            const Spacer(),

            // ─── Footer ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Su Hatırlatıcı v1.0.0', 
                style: TextStyle(color: secondaryText.withOpacity(0.5), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
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
