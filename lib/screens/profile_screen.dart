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
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _ageCtrl = TextEditingController(text: user?.age.toString() ?? '');
    _weightCtrl = TextEditingController(text: user?.weight.toString() ?? '');
    _goalCtrl = TextEditingController(text: user?.customGoal?.toString() ?? '');

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

  @override
  Widget build(BuildContext context) {
    var pr = context.watch<UserProvider>();
    final user = pr.currentUser;

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text(context.watch<LocaleProvider>().translate('nav_profile'), style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isEditing) ...[
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accentColor),
              onPressed: () => setState(() => _isEditing = true),
            ),
          ]
        ],
      ),
      body: user == null
          ? Center(child: Text(context.watch<LocaleProvider>().translate('prof_user_not_found')))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // 1. KİMLİK BÖLGESİ
                    _buildSectionHeader(context.watch<LocaleProvider>().translate('prof_section_identity')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: _buildTextFieldRow(
                        icon: Icons.badge_rounded,
                        label: context.watch<LocaleProvider>().translate('prof_label_name'),
                        controller: _nameCtrl,
                        suffix: '',
                        isLast: true,
                        isNumeric: false,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 2. FİZİKSEL BİLGİLER
                    _buildSectionHeader(context.watch<LocaleProvider>().translate('prof_section_physical')),
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
                            label: context.watch<LocaleProvider>().translate('prof_label_age'),
                            controller: _ageCtrl,
                            suffix: context.watch<LocaleProvider>().translate('prof_suffix_age'),
                            isLast: false,
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64),
                          _buildTextFieldRow(
                            icon: Icons.monitor_weight_rounded,
                            label: context.watch<LocaleProvider>().translate('prof_label_weight'),
                            controller: _weightCtrl,
                            suffix: context.watch<LocaleProvider>().translate('prof_suffix_kg'),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 3. HEDEF
                    _buildSectionHeader(context.watch<LocaleProvider>().translate('prof_section_goal')),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: _buildTextFieldRow(
                        icon: Icons.track_changes_rounded,
                        label: context.watch<LocaleProvider>().translate('prof_label_daily_goal'),
                        controller: _goalCtrl,
                        suffix: context.watch<LocaleProvider>().translate('prof_suffix_ml'),
                        isLast: true,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // 4. UYKU DÜZENİ
                    _buildSectionHeader(context.watch<LocaleProvider>().translate('prof_section_sleep')),
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
                            label: context.watch<LocaleProvider>().translate('prof_label_wake'),
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
                            label: context.watch<LocaleProvider>().translate('prof_label_sleep'),
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
                    _buildSectionHeader(context.watch<LocaleProvider>().translate('drawer_settings').toUpperCase()),
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
                            icon: Icons.notifications_active_rounded,
                            iconColor: const Color(0xFFF59E0B),
                            title: context.watch<LocaleProvider>().translate('settings_notif'),
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
                                      Text(context.watch<LocaleProvider>().translate('sett_notif_freq'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
                                      Text(context.watch<LocaleProvider>().translate('sett_notif_freq_desc'), style: TextStyle(fontSize: 12, color: secondaryText, fontWeight: FontWeight.w500)),
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
                                            context.watch<LocaleProvider>().translate(opt['labelKey']!),
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
                            title: context.watch<LocaleProvider>().translate('sett_btn_rate'),
                            subtitle: context.watch<LocaleProvider>().translate('sett_subtitle_rate'),
                            onTap: _rateApp,
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 70),
                          _buildSettingRow(
                            icon: Icons.apps_rounded,
                            iconColor: Colors.purple,
                            title: context.watch<LocaleProvider>().translate('sett_btn_other_apps'),
                            subtitle: context.watch<LocaleProvider>().translate('sett_subtitle_other_apps'),
                            onTap: _openOtherApps,
                            trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
                          ),
                        ],
                      ),
                    ),

                    if (_isEditing)
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => setState(() => _isEditing = false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: Text(context.watch<LocaleProvider>().translate('prof_btn_cancel'), style: TextStyle(color: secondaryText, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: pr.isLoading ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentColor,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: pr.isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : Text(context.watch<LocaleProvider>().translate('prof_btn_save'), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              ),
                            ),
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

  Widget _buildTextFieldRow({required IconData icon, required String label, required TextEditingController controller, required String suffix, required bool isLast, bool isNumeric = true}) {
    return Padding(
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
          if (!_isEditing)
            Text('${controller.text} $suffix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: secondaryText))
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
