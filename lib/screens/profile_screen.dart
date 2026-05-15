import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';
import '../providers/locale_provider.dart';
import '../services/notification_service.dart';
import 'package:hive/hive.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/revenuecat_service.dart';
import '../services/report_service.dart';
import '../providers/drink_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _goalCtrl;
  TimeOfDay? _wakeTime;
  TimeOfDay? _sleepTime;

  bool _isEditing = false;
  bool _notificationsEnabled = true;

  final InAppReview _inAppReview = InAppReview.instance;
  String _intervalPreset = '2h';

  static const List<Map<String, String>> _presetOptions = [
    {'key': 'half', 'labelKey': 'sett_preset_half'},
    {'key': '1h',   'labelKey': 'sett_preset_1h'},
    {'key': '2h',   'labelKey': 'sett_preset_2h'},
    {'key': '3h',   'labelKey': 'sett_preset_3h'},
    {'key': '4h',   'labelKey': 'sett_preset_4h'},
  ];

  final primaryText = const Color(0xFF0F172A);
  final secondaryText = const Color(0xFF64748B);
  final accentColor = const Color(0xFF0EA5E9);
  final scaffoldBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    final autoGoal = context.read<WaterProvider>().dailyGoal;

    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _ageCtrl = TextEditingController(text: user?.age.toString() ?? '');
    _weightCtrl = TextEditingController(text: user?.weight.toString() ?? '');
    
    _goalCtrl = TextEditingController(
      text: user?.customGoal != null && user!.customGoal! > 0
          ? user.customGoal.toString()
          : autoGoal.toString(),
    );

    if (user != null) {
      _wakeTime = _parseTime(user.wakeUpTime);
      _sleepTime = _parseTime(user.sleepTime);
    }
    _loadSettings();
  }

  void _loadSettings() {
    var box = Hive.box('settings');
    setState(() {
      _notificationsEnabled = box.get('notificationsEnabled', defaultValue: true);
      _intervalPreset = box.get('notifIntervalPreset', defaultValue: '2h') as String;
    });
  }

  void _toggleNotifications(bool value) {
    setState(() => _notificationsEnabled = value);
    Hive.box('settings').put('notificationsEnabled', value);
    if (value) {
      NotificationService().scheduleEscalatingReminders();
      NotificationService().scheduleMorningGreeting();
    } else {
      NotificationService().cancelAllReminders();
    }
  }

  Future<void> _changeIntervalPreset(String newPreset) async {
    setState(() => _intervalPreset = newPreset);
    await Hive.box('settings').put('notifIntervalPreset', newPreset);
    await NotificationService().scheduleEscalatingReminders();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _rateApp() async {
    const String appStoreId = '6761442203';

    try {
      // Doğrudan mağaza sayfasını açar (En güvenilir yöntem)
      await _inAppReview.openStoreListing(appStoreId: appStoreId);
    } catch (e) {
      debugPrint('Rate app failed: $e');
      // Yedek plan: Tarayıcı üzerinden açmayı dene
      final Uri appStoreUri = Uri.parse('https://apps.apple.com/app/id$appStoreId?action=write-review');
      final Uri playStoreUri = Uri.parse('https://play.google.com/store/apps/details?id=com.cervus.suhatirlatici');
      
      try {
        final Uri url = Platform.isIOS ? appStoreUri : playStoreUri;
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      } catch (e2) {
        debugPrint('Manual store launch failed: $e2');
      }
    }
  }

  Future<void> _openOtherApps() async {
    const String iosDevUrl = 'https://apps.apple.com/tr/developer/cervus-digital/id1889669486';
    const String androidDevUrl = 'https://play.google.com/store/apps/developer?id=Cervus+App+Studio';
    
    final Uri url = Uri.parse(Platform.isIOS ? iosDevUrl : androidDevUrl);
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Launch other apps failed: $e');
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    if (timeStr.isEmpty) return const TimeOfDay(hour: 8, minute: 0);
    List<String> parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showPremiumDialog() {
    final lp = context.read<LocaleProvider>();
    final isTr = lp.locale.languageCode == 'tr';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, size: 60, color: accentColor),
                const SizedBox(height: 12),
                Text(lp.translate('premium_popup_title'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: primaryText)),
                const SizedBox(height: 20),
                _buildPremiumFeatureRow(Icons.local_cafe_rounded, lp.translate('premium_popup_feature_1')),
                _buildPremiumFeatureRow(Icons.analytics_rounded, lp.translate('premium_popup_feature_2')),
                _buildPremiumFeatureRow(Icons.block, lp.translate('premium_popup_feature_3')),
                const SizedBox(height: 24),

                // RevenueCat paketler
                FutureBuilder<Offerings?>(
                  future: RevenueCatService.getOfferings(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return Text(isTr ? "Paketler yüklenemedi." : "Packages could not be loaded.", style: TextStyle(color: secondaryText));
                    }
                    final packages = snapshot.data!.current?.availablePackages ?? [];
                    final monthly  = packages.where((p) => p.packageType == PackageType.monthly).firstOrNull 
                                     ?? packages.where((p) => p.identifier.toLowerCase().contains('monthly')).firstOrNull;
                    final yearly   = packages.where((p) => p.packageType == PackageType.annual).firstOrNull 
                                     ?? packages.where((p) => p.identifier.toLowerCase().contains('year') || p.identifier.toLowerCase().contains('ann')).firstOrNull;
                    final lifetime = packages.where((p) => p.packageType == PackageType.lifetime).firstOrNull 
                                     ?? packages.where((p) => p.identifier.toLowerCase().contains('life') || p.identifier.toLowerCase().contains('pro2')).firstOrNull;
                    return Column(children: [
                      if (monthly  != null) 
                        _buildSubCard(
                          package: monthly,
                          title: isTr ? "Aylık" : "Monthly",
                          price: monthly.storeProduct.priceString,
                          subtitle: isTr ? "1 Aylık Abonelik" : "1 Month Subscription",
                          isPopular: false,
                          isTr: isTr,
                        ),
                      if (yearly   != null) 
                        _buildSubCard(
                          package: yearly,
                          title: isTr ? "Yıllık" : "Yearly",
                          price: yearly.storeProduct.priceString,
                          subtitle: isTr ? "1 Yıllık Abonelik" : "1 Year Subscription",
                          isPopular: true,
                          originalPrice: yearly.storeProduct.currencyCode == 'TRY' ? "599.99 ₺" : "\$35.99",
                          isTr: isTr,
                        ),
                      if (lifetime != null) 
                        _buildSubCard(
                          package: lifetime,
                          title: isTr ? "Ömür Boyu" : "Lifetime",
                          price: lifetime.storeProduct.priceString,
                          subtitle: isTr ? "Tek seferlik ödeme" : "One-time payment",
                          isPopular: false,
                          isSpecialOffer: true,
                          isTr: isTr,
                        ),
                    ]);
                  },
                ),

                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse("https://cervusdigital.com/drinkly/privacy-policy/")),
                    child: Text(isTr ? "Gizlilik Politikası" : "Privacy Policy", style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  const Text(" • ", style: TextStyle(color: Color(0x4D64748B))),
                  TextButton(
                    onPressed: () => launchUrl(Uri.parse("https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")),
                    child: Text(isTr ? "Kullanım Koşulları (EULA)" : "Terms of Use (EULA)", style: TextStyle(color: accentColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  isTr 
                    ? "Ödeme, satın alma onayının ardından Apple ID hesabınızdan tahsil edilecektir. Abonelik, mevcut dönemin bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir. Yenileme ücreti mevcut dönemin bitiminden 24 saat önce hesabınızdan tahsil edilecektir. Aboneliklerinizi App Store hesap ayarlarınızdan yönetebilir ve iptal edebilirsiniz." 
                    : "Payment will be charged to your Apple ID account at the confirmation of purchase. The subscription automatically renews unless it is canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage and cancel your subscriptions by going to your App Store account settings after purchase.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondaryText.withValues(alpha: 0.6), fontSize: 11),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async { 
                    Navigator.pop(ctx); 
                    await RevenueCatService.restorePurchases(context); 
                  },
                  child: Text(lp.translate('premium_popup_restore'), style: TextStyle(color: secondaryText)),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx), 
                  child: Text(lp.translate('premium_popup_cancel'), style: TextStyle(color: secondaryText.withValues(alpha: 0.6)))
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubCard({
    required Package package,
    required String title,
    required String price,
    required String subtitle,
    required bool isPopular,
    String? originalPrice,
    bool isSpecialOffer = false,
    required bool isTr,
  }) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        await RevenueCatService.purchasePackage(context, package);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isPopular ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          border: Border.all(color: isPopular ? accentColor : Colors.grey.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.bold)),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: accentColor, borderRadius: BorderRadius.circular(6)),
                          child: Text(isTr ? "POPÜLER" : "POPULAR", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (isSpecialOffer) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.orange.shade700, borderRadius: BorderRadius.circular(6)),
                          child: Text(isTr ? "ÖZEL TEKLİF" : "SPECIAL OFFER", style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: secondaryText, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (originalPrice != null)
                  Text(
                    originalPrice,
                    style: TextStyle(
                      color: secondaryText.withValues(alpha: 0.6),
                      fontSize: 13,
                      decoration: TextDecoration.lineThrough,
                      decorationColor: Colors.redAccent,
                      decorationThickness: 2.0,
                    ),
                  ),
                Text(
                  price,
                  style: TextStyle(color: accentColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final lp = context.watch<LocaleProvider>();
    final isPremium = userProvider.isPremium;
    var user = userProvider.currentUser;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(lp.translate('nav_profile'), style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: _isEditing ? IconButton(
          icon: Icon(Icons.close_rounded, color: primaryText),
          onPressed: () => setState(() => _isEditing = false),
        ) : null,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accentColor),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: userProvider.isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.check_rounded, color: accentColor),
              onPressed: userProvider.isLoading ? null : _saveProfile,
            ),
        ],
      ),
      body: user == null
          ? Center(child: Text(lp.translate('prof_user_not_found')))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Premium Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: isPremium
                            ? const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)])
                            : const LinearGradient(colors: [Color(0xFF64748B), Color(0xFF475569)]),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: (isPremium ? const Color(0xFFF59E0B) : const Color(0xFF64748B)).withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(isPremium ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.white, size: 32),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isPremium ? lp.translate('premium_title_pro') : lp.translate('premium_title_free'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                                Text(isPremium ? lp.translate('premium_active_desc') : lp.translate('premium_upgrade_desc'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          if (!isPremium)
                            ElevatedButton(
                              onPressed: _showPremiumDialog,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.grey.shade700),
                              child: Text(lp.translate('premium_btn_upgrade')),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 1. KİMLİK BÖLGESİ
                    _buildSectionHeader(lp.translate('prof_section_identity')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: _buildTextFieldRow(
                        icon: Icons.badge_rounded,
                        label: lp.translate('prof_label_name'),
                        controller: _nameCtrl,
                        suffix: '',
                        isLast: true,
                        isNumeric: false,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 2. FİZİKSEL BİLGİLER
                    _buildSectionHeader(lp.translate('prof_section_physical')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          _buildTextFieldRow(
                            icon: Icons.cake_rounded,
                            label: lp.translate('prof_label_age'),
                            controller: _ageCtrl,
                            suffix: lp.translate('prof_suffix_age'),
                            isLast: false,
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64),
                          _buildTextFieldRow(
                            icon: Icons.monitor_weight_rounded,
                            label: lp.translate('prof_label_weight'),
                            controller: _weightCtrl,
                            suffix: lp.translate('prof_suffix_kg'),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 3. HEDEF
                    _buildSectionHeader(lp.translate('prof_section_goal')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: _buildTextFieldRow(
                        icon: Icons.track_changes_rounded,
                        label: lp.translate('prof_label_daily_goal'),
                        controller: _goalCtrl,
                        suffix: lp.translate('prof_suffix_ml'),
                        isLast: true,
                        subHint: lp.translate('prof_goal_hint'),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 4. UYKU DÜZENİ
                    _buildSectionHeader(lp.translate('prof_section_sleep')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          _buildTimeSelectionRow(
                            icon: Icons.wb_sunny_rounded,
                            label: lp.translate('prof_label_wake'),
                            time: _wakeTime,
                            isLast: false,
                            onTap: () async {
                              if (!_isEditing) return;
                              final t = await showTimePicker(context: context, initialTime: _wakeTime!);
                              if (t != null) setState(() => _wakeTime = t);
                            },
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64),
                          _buildTimeSelectionRow(
                            icon: Icons.nights_stay_rounded,
                            label: lp.translate('prof_label_sleep'),
                            time: _sleepTime,
                            isLast: true,
                            onTap: () async {
                              if (!_isEditing) return;
                              final t = await showTimePicker(context: context, initialTime: _sleepTime!);
                              if (t != null) setState(() => _sleepTime = t);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 5. AYARLAR (BİLDİRİM & LİSAN)
                    _buildSectionHeader(lp.translate('drawer_settings').toUpperCase()),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: Column(
                        children: [
                          _buildSettingRow(
                            icon: Icons.workspace_premium_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: lp.translate('premium_popup_title'),
                            subtitle: lp.translate('premium_popup_feature_3'),
                            onTap: _showPremiumDialog,
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text("PRO", style: TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w900, fontSize: 10)),
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          _buildSettingRow(
                            icon: Icons.notifications_active_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: lp.translate('settings_notif'),
                            subtitle: '',
                            trailing: CupertinoSwitch(
                              activeTrackColor: const Color(0xFF22C55E),
                              value: _notificationsEnabled,
                              onChanged: _toggleNotifications,
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          // Hatırlatma Sıklığı
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.timer_outlined, color: accentColor, size: 22),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(lp.translate('sett_notif_freq'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
                                      Text(lp.translate('sett_notif_freq_desc'), style: TextStyle(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: accentColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _intervalPreset,
                                      isDense: true,
                                      icon: Icon(Icons.expand_more_rounded, color: accentColor, size: 18),
                                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontSize: 13),
                                      dropdownColor: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      items: _presetOptions.map((opt) {
                                        return DropdownMenuItem<String>(
                                          value: opt['key'],
                                          child: Text(
                                            lp.translate(opt['labelKey']!),
                                            style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: _notificationsEnabled ? (val) { if (val != null) _changeIntervalPreset(val); } : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          _buildLanguageToggle(),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          _buildSettingRow(
                            icon: Icons.star_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: lp.translate('sett_btn_rate'),
                            subtitle: lp.translate('sett_subtitle_rate'),
                            onTap: _rateApp,
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          _buildSettingRow(
                            icon: Icons.apps_rounded,
                            iconColor: Colors.purple,
                            title: lp.translate('sett_btn_other_apps'),
                            subtitle: lp.translate('sett_subtitle_other_apps'),
                            onTap: _openOtherApps,
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                          ),
                          if (isPremium) ...[
                            const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                            _buildSettingRow(
                              icon: Icons.picture_as_pdf_rounded,
                              iconColor: Colors.redAccent,
                              title: lp.translate('report_btn_title'),
                              subtitle: lp.translate('report_btn_subtitle'),
                              onTap: () {
                                final isTr = lp.locale.languageCode == 'tr';
                                ReportService.generateAndShare(
                                  context: context,
                                  waterProvider: context.read<WaterProvider>(),
                                  drinkProvider: context.read<DrinkProvider>(),
                                  isTr: isTr,
                                );
                              },
                              trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 48),
                  ],
                ),
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

  Widget _buildTextFieldRow({required IconData icon, required String label, required TextEditingController controller, required String suffix, required bool isLast, bool isNumeric = true, String? subHint}) {
    String displayValue = controller.text.trim().isEmpty ? '—' : '${controller.text} $suffix';

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: isLast ? 8 : 16, bottom: isLast ? 16 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
              const Spacer(),
              if (!_isEditing)
                Text(displayValue, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: secondaryText))
              else
                SizedBox(
                  width: isNumeric ? 80 : 140,
                  child: CupertinoTextField(
                    controller: controller,
                    keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
                    textAlign: TextAlign.right,
                    suffix: suffix.isNotEmpty ? Padding(padding: const EdgeInsets.only(right: 8), child: Text(suffix, style: const TextStyle(color: Colors.grey))) : null,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    decoration: BoxDecoration(color: scaffoldBg, borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          if (_isEditing && subHint != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 48),
              child: Text(subHint, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({required IconData icon, required Color iconColor, required String title, required String subtitle, required Widget trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
                  if (subtitle.isNotEmpty) 
                    Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageToggle() {
    final lp = context.read<LocaleProvider>();
    bool isTr = lp.locale.languageCode == 'tr';
    return _buildSettingRow(
      icon: Icons.language_rounded,
      iconColor: Colors.blueAccent,
      title: context.watch<LocaleProvider>().translate('settings_lang'),
      subtitle: isTr ? 'Türkçe' : 'English',
      onTap: () {
        lp.setLocale(isTr ? const Locale('en') : const Locale('tr'));
      },
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.blueAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          lp.locale.languageCode.toUpperCase(),
          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildTimeSelectionRow({required IconData icon, required String label, required TimeOfDay? time, required bool isLast, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(24)) : const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: isLast ? 8 : 16, bottom: isLast ? 16 : 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 16),
            Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isEditing ? scaffoldBg : Colors.transparent, 
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                time != null ? _formatTime(time) : '--:--',
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w600, 
                  color: _isEditing ? primaryText : secondaryText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    int age = int.tryParse(_ageCtrl.text) ?? 25;
    double weight = double.tryParse(_weightCtrl.text) ?? 70.0;
    int? customGoal = int.tryParse(_goalCtrl.text);
    
    bool result = await context.read<UserProvider>().updateUser(
      displayName: _nameCtrl.text,
      age: age,
      weight: weight,
      wakeUpTime: _formatTime(_wakeTime!),
      sleepTime: _formatTime(_sleepTime!),
      customGoal: customGoal,
    );

    if (result && mounted) {
      context.read<WaterProvider>().recalculateGoal();
      setState(() => _isEditing = false);
      NotificationService().scheduleMorningGreeting();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.read<LocaleProvider>().translate('prof_success'), style: const TextStyle(color: Colors.white)), backgroundColor: const Color(0xFF22C55E)));
    }
  }
}
