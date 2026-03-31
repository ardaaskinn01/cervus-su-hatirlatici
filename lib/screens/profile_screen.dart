import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  TimeOfDay? _wakeTime;
  TimeOfDay? _sleepTime;

  bool _isEditing = false;

  final primaryText = const Color(0xFF0F172A);
  final secondaryText = const Color(0xFF64748B);
  final accentColor = const Color(0xFF0EA5E9);
  final scaffoldBg = const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().currentUser;
    _ageCtrl = TextEditingController(text: user?.age.toString() ?? '');
    _weightCtrl = TextEditingController(text: user?.weight.toString() ?? '');

    if (user != null) {
      _wakeTime = _parseTime(user.wakeUpTime);
      _sleepTime = _parseTime(user.sleepTime);
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
        title: Text('Profilim', style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: Icon(Icons.edit_rounded, color: accentColor),
              onPressed: () => setState(() => _isEditing = true),
            )
        ],
      ),
      body: user == null
          ? const Center(child: Text('Kullanıcı bulunamadı.'))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Profile Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accentColor.withOpacity(0.2), width: 3)),
                            child: CircleAvatar(
                              radius: 46,
                              backgroundColor: accentColor.withOpacity(0.1),
                              child: Icon(Icons.person_rounded, size: 50, color: accentColor),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(user.displayName, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
                          const SizedBox(height: 4),
                          Text('ID: ${user.firebaseId}', style: TextStyle(fontSize: 13, color: secondaryText, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Information Forms/Cards
                    _buildSectionHeader('FİZİKSEL DETAYLAR'),
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
                            label: 'Yaş',
                            controller: _ageCtrl,
                            suffix: 'yaş',
                            isLast: false,
                          ),
                          const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 64),
                          _buildTextFieldRow(
                            icon: Icons.monitor_weight_rounded,
                            label: 'Kilo',
                            controller: _weightCtrl,
                            suffix: 'kg',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    _buildSectionHeader('UYKU DÜZENİ'),
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
                            label: 'Uyanma Zamanı',
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
                            label: 'Uyuma Zamanı',
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

                    const SizedBox(height: 48),

                    if (_isEditing)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: pr.isLoading ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          child: pr.isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Değişiklikleri Kaydet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      
                    const SizedBox(height: 24),
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

  Widget _buildTextFieldRow({required IconData icon, required String label, required TextEditingController controller, required String suffix, required bool isLast}) {
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: isLast ? 8 : 16, bottom: isLast ? 16 : 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 16),
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryText)),
          const Spacer(),
          if (!_isEditing)
            Text('${controller.text} $suffix', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: secondaryText))
          else
            SizedBox(
              width: 80,
              child: CupertinoTextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.right,
                suffix: Padding(padding: const EdgeInsets.only(right: 8), child: Text(suffix, style: const TextStyle(color: Colors.grey))),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(color: scaffoldBg, borderRadius: BorderRadius.circular(8)),
              ),
            ),
        ],
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
              decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
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
    
    bool result = await context.read<UserProvider>().updateUser(
      age: age,
      weight: weight,
      wakeUpTime: _formatTime(_wakeTime!),
      sleepTime: _formatTime(_sleepTime!),
    );

    if (result) {
      context.read<WaterProvider>().recalculateGoal();
      setState(() => _isEditing = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil başarıyla güncellendi!', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF10B981)));
    }
  }
}
