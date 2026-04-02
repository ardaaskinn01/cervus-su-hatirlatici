import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final InAppReview _inAppReview = InAppReview.instance;
  bool _notificationsEnabled = true;

  final primaryText = const Color(0xFF0F172A);
  final secondaryText = const Color(0xFF64748B);
  final accentColor = const Color(0xFF0EA5E9);
  final scaffoldBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    var box = Hive.box('settings');
    setState(() {
      _notificationsEnabled = box.get('notificationsEnabled', defaultValue: true);
    });
  }

  void _toggleNotifications(bool value) {
    setState(() => _notificationsEnabled = value);
    Hive.box('settings').put('notificationsEnabled', value);
  }

  Future<void> _rateApp() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
      } else {
        await _inAppReview.openStoreListing(appStoreId: 'XXX'); // appStoreId eklenecek
      }
    } catch (e) {
      debugPrint('Rate app trigger failed: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(context.watch<LocaleProvider>().translate('settings_title'), style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            _buildSectionHeader(context.watch<LocaleProvider>().translate('drawer_settings').toUpperCase()),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.notifications_active_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: context.watch<LocaleProvider>().translate('settings_notif'),
                    subtitle: "",
                    trailing: CupertinoSwitch(
                      activeColor: const Color(0xFF10B981),
                      value: _notificationsEnabled,
                      onChanged: _toggleNotifications,
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  _buildSettingRow(
                    icon: Icons.language_rounded,
                    iconColor: Colors.blueAccent,
                    title: context.watch<LocaleProvider>().translate('settings_lang'),
                    subtitle: context.watch<LocaleProvider>().locale.languageCode == 'tr' ? 'Türkçe' : 'English',
                    onTap: () {
                      final lp = context.read<LocaleProvider>();
                      lp.setLocale(lp.locale.languageCode == 'tr' ? const Locale('en') : const Locale('tr'));
                    },
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        context.watch<LocaleProvider>().locale.languageCode.toUpperCase(),
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildSectionHeader('DESTEK VE HAKKINDA'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.star_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Bizi Değerlendir',
                    subtitle: 'Uygulamayı mağazada puanla',
                    onTap: _rateApp,
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),

            Text('Su Hatırlatıcı v1.0.0', style: TextStyle(color: secondaryText.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: secondaryText, letterSpacing: 1.5)),
      ),
    );
  }

  Widget _buildSettingRow({required IconData icon, required Color iconColor, required String title, required String subtitle, Widget? trailing, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}
