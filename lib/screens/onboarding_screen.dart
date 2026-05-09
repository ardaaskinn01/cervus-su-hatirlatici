import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../providers/locale_provider.dart';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/gestures.dart';
import 'main_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 23, minute: 0);

  String? _selectedLanguage; // 'tr' veya 'en'
  bool _isPrivacyAccepted = false;
  bool _isLoading = false;

  void _nextPage() {
    // 0. Dil Seçimi Doğrulaması
    if (_currentIndex == 0 && _selectedLanguage == null) {
      _showSnackbar(context.read<LocaleProvider>().translate('onb_lang_select_error'));
      return;
    }
    // 1. Gizlilik Politikası Doğrulaması
    if (_currentIndex == 1 && !_isPrivacyAccepted) {
      _showSnackbar(context.read<LocaleProvider>().translate('onb_privacy_error'));
      return;
    }
    // 2. Sayfa Doğrulaması (İsim)
    if (_currentIndex == 2 && _nameController.text.trim().isEmpty) {
      _showSnackbar(context.read<LocaleProvider>().translate('onb_error_name'));
      return;
    }
    // 3. Sayfa Doğrulaması (Kilo/Yaş)
    if (_currentIndex == 3) {
      if (int.tryParse(_ageController.text) == null || int.tryParse(_weightController.text) == null) {
        _showSnackbar(context.read<LocaleProvider>().translate('onb_error_numbers'));
        return;
      }
    }

    if (_currentIndex < 5) {
      _pageController.nextPage(duration: const Duration(milliseconds: 600), curve: Curves.fastOutSlowIn);
    } else {
      _submitForm();
    }
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _submitForm() async {
    setState(() => _isLoading = true);

    String wakeStr = "${_wakeTime.hour.toString().padLeft(2, '0')}:${_wakeTime.minute.toString().padLeft(2, '0')}";
    String sleepStr = "${_sleepTime.hour.toString().padLeft(2, '0')}:${_sleepTime.minute.toString().padLeft(2, '0')}";

    try {
      await context.read<UserProvider>().registerUser(
            name: _nameController.text.trim(),
            age: int.parse(_ageController.text),
            weight: double.parse(_weightController.text),
            wakeUpTime: wakeStr,
            sleepTime: sleepStr,
            isPrivacyAccepted: _isPrivacyAccepted,
          );

      // 🔔 Bildirim sistemini ilk kez kur
      final ns = NotificationService();
      ns.scheduleMorningGreeting();
      ns.scheduleReEngagementNotifications();
      ns.scheduleEscalatingReminders();

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainShell()));
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = context.read<LocaleProvider>().translate('onb_error_generic');
        _showSnackbar('$errorMsg$e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickTime(bool isWake) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isWake ? _wakeTime : _sleepTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0EA5E9)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isWake) {
          _wakeTime = picked;
        } else {
          _sleepTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC), // Çok açık su mavisi arka plan
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            // Arkaplan Şık Dekorasyon
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF38BDF8).withValues(alpha: 0.4), Colors.transparent]),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [const Color(0xFF0EA5E9).withValues(alpha: 0.3), Colors.transparent]),
                ),
              ),
            ),
            
            SafeArea(
              child: Column(
                children: [
                  // Adım Göstergesi (Dots)
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentIndex == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentIndex == index ? const Color(0xFF0EA5E9) : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
  
                  // Kaydırmalı Sayfalar (Content)
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Sadece butonla geçilebilsin
                      onPageChanged: (index) => setState(() => _currentIndex = index),
                      children: [
                        _buildLanguageStep(),
                        _buildPrivacyStep(),
                        _buildNameStep(),
                        _buildBodyDataStep(),
                        _buildWakeTimeStep(),
                        _buildSleepTimeStep(),
                      ],
                    ),
                  ),
  
                  // Alt Buton Alanı
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Color(0xFF0EA5E9))
                        : SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0EA5E9),
                                elevation: 5,
                                shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                _currentIndex == 5
                                    ? context.watch<LocaleProvider>().translate('onb_btn_start')
                                    : context.watch<LocaleProvider>().translate('onb_btn_next'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ADIM -1: DİL SEÇİMİ
  Widget _buildLanguageStep() {
    final lp = context.watch<LocaleProvider>();
    return _StepContentCard(
      icon: Icons.language_rounded,
      title: "${lp.translate('onb_lang_title')} / Language",
      subtitle: "${lp.translate('onb_lang_subtitle')} / Please select your language",
      child: Column(
        children: [
          _buildLanguageOption("Türkçe", "tr", "🇹🇷"),
          const SizedBox(height: 12),
          _buildLanguageOption("English", "en", "🇺🇸"),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(String label, String code, String flag) {
    bool isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = code);
        context.read<LocaleProvider>().setLocale(Locale(code));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey.shade200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: Color(0xFF0EA5E9)),
          ],
        ),
      ),
    );
  }

  // ADIM 0: GİZLİLİK POLİTİKASI
  Widget _buildPrivacyStep() {
    final lp = context.watch<LocaleProvider>();
    final fullText = lp.translate('onb_privacy_accept');
    final String linkPart = _selectedLanguage == 'tr' ? "Gizlilik Politikası" : "Privacy Policy";
    
    final parts = fullText.split(linkPart);

    return _StepContentCard(
      icon: Icons.security_rounded,
      title: lp.translate('onb_privacy_title'),
      subtitle: "",
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              children: [
                const Icon(Icons.verified_user_rounded, color: Color(0xFF22C55E), size: 48),
                const SizedBox(height: 20),
                CheckboxListTile(
                  value: _isPrivacyAccepted,
                  onChanged: (val) => setState(() => _isPrivacyAccepted = val ?? false),
                  title: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A), height: 1.5),
                      children: [
                        if (parts.isNotEmpty) TextSpan(text: parts[0]),
                        TextSpan(
                          text: linkPart,
                          style: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () async {
                              final url = Uri.parse("https://cervusdigital.com/drinkly/privacy-policy/");
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url, mode: LaunchMode.externalApplication);
                              }
                            },
                        ),
                        if (parts.length > 1) TextSpan(text: parts[1]),
                      ],
                    ),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: const Color(0xFF0EA5E9),
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            lp.translate('onb_privacy_check_hint'),
            style: TextStyle(color: const Color(0xFF0F172A).withValues(alpha: 0.5), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ADIM 1: İSİM
  Widget _buildNameStep() {
    return _StepContentCard(
      icon: Icons.waving_hand_rounded,
      title: context.watch<LocaleProvider>().translate('onb_welcome'),
      subtitle: context.watch<LocaleProvider>().translate('onb_subtitle'),
      child: _buildTextField(controller: _nameController, hint: context.watch<LocaleProvider>().translate('onb_hint_name'), icon: Icons.person_rounded),
    );
  }

  // ADIM 2: KİLO & YAŞ
  Widget _buildBodyDataStep() {
    return _StepContentCard(
      icon: Icons.monitor_weight_rounded,
      title: context.watch<LocaleProvider>().translate('onb_title_body'),
      subtitle: "",
      child: Row(
        children: [
          Expanded(child: _buildTextField(controller: _ageController, hint: context.watch<LocaleProvider>().translate('onb_hint_age'), icon: Icons.cake, isNumber: true)),
          const SizedBox(width: 16),
          Expanded(child: _buildTextField(controller: _weightController, hint: context.watch<LocaleProvider>().translate('onb_step_weight'), icon: Icons.straighten, isNumber: true)),
        ],
      ),
    );
  }

  // ADIM 3: UYANIŞ
  Widget _buildWakeTimeStep() {
    return _StepContentCard(
      icon: Icons.wb_sunny_rounded,
      title: context.watch<LocaleProvider>().translate('onb_step_wake'),
      subtitle: "",
      child: _buildTimeBox(true, _wakeTime),
    );
  }

  // ADIM 4: UYKU
  Widget _buildSleepTimeStep() {
    return _StepContentCard(
      icon: Icons.nightlight_round,
      title: context.watch<LocaleProvider>().translate('onb_step_sleep'),
      subtitle: "",
      child: _buildTimeBox(false, _sleepTime),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, bool isNumber = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: Icon(icon, color: const Color(0xFF0EA5E9)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        ),
      ),
    );
  }

  Widget _buildTimeBox(bool isWake, TimeOfDay time) {
    return GestureDetector(
      onTap: () => _pickTime(isWake),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3), width: 2),
          boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFF0EA5E9)),
            const SizedBox(width: 12),
            Text(
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            )
          ],
        ),
      ),
    );
  }
}

// Ortak Kart Şablonu (Animasyonlu ve Şık İçerik Kutusu)
class _StepContentCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _StepContentCard({required this.icon, required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                    child: Icon(icon, size: 60, color: const Color(0xFF0EA5E9)),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                    textAlign: TextAlign.center,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 15, height: 1.5, color: Colors.black54),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 48),
                  child,
                  // Keyboard payasunu önlemek için ekstra boşluk (isteğe bağlı)
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
