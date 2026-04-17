import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../widgets/ad_banner_widget.dart';
import 'home_screen.dart';
import 'statistics_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  // 🎯 DÜZELTME: Sayfaları 'const' yapmaktan çıkarıyoruz. 
  // Çünkü IndexedStack tüm sayfaları aynı anda init eder. 
  // Eğer sayfalardan birinde (örn: Statistics) bir Hive hatası varsa tüm uygulama kilitlenir.
  List<Widget> get _pages => [
    const HomeScreen(),
    const StatisticsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // LocaleProvider'ın hazır olduğundan emin olalım
    final lp = context.watch<LocaleProvider>();

    return Scaffold(
      // Sayfalar arası geçişte çökme riskine karşı IndexedStack'i de koruyoruz
      body: Builder(
        builder: (context) {
          try {
            return Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _pages,
                  ),
                ),
                const AdBannerWidget(),
              ],
            );
          } catch (e) {
            debugPrint("🚨 MainShell Sayfa Hatası: $e");
            return const Center(child: Text("Bir hata oluştu, lütfen uygulamayı yeniden başlatın."));
          }
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0EA5E9).withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.water_drop_rounded,
                  label: lp.translate('drawer_home'),
                  isActive: _currentIndex == 0,
                  onTap: () => setState(() => _currentIndex = 0),
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  label: lp.translate('drawer_stats'),
                  isActive: _currentIndex == 1,
                  onTap: () => setState(() => _currentIndex = 1),
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: lp.translate('nav_profile'),
                  isActive: _currentIndex == 2,
                  onTap: () => setState(() => _currentIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0EA5E9);
    const inactiveColor = Color(0xFFCBD5E1);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentColor.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isActive ? 26 : 24,
              color: isActive ? accentColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                color: isActive ? accentColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
