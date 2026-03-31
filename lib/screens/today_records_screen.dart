import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/user_provider.dart';
import '../providers/water_provider.dart';
import '../widgets/app_drawer.dart';

class TodayRecordsScreen extends StatelessWidget {
  const TodayRecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    var user = context.watch<UserProvider>().currentUser;
    var waterProvider = context.watch<WaterProvider>();
    final dateKey = waterProvider.getLogicalDateKey();

    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const accentColor = Color(0xFF0EA5E9);
    const scaffoldBg = Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Bugünkü Kayıtlar', style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        centerTitle: true,
      ),
      drawer: const AppDrawer(),
      body: user == null
          ? const Center(child: Text('Kullanıcı bulunamadı.'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.firebaseId)
                  .collection('gunler')
                  .doc(dateKey)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: accentColor));
                }
                if (!snap.hasData || !snap.data!.exists) {
                  return _buildEmptyState(secondaryText);
                }

                final data = snap.data!.data() as Map<String, dynamic>;
                final rawList = (data['suIcildi'] as List<dynamic>? ?? []).reversed.toList();

                if (rawList.isEmpty) {
                  return _buildEmptyState(secondaryText);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: rawList.length,
                  itemBuilder: (context, index) {
                    final kaydi = SuKaydi.fromMap(Map<String, dynamic>.from(rawList[index]));
                    return Dismissible(
                      key: Key(kaydi.uid),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444), size: 28),
                      ),
                      confirmDismiss: (_) async {
                        await waterProvider.deleteWaterRecord(kaydi, dateKey);
                        return false;
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 20, offset: Offset(0, 8))],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(16)),
                              child: const Icon(Icons.water_drop_rounded, color: Color(0xFF0EA5E9), size: 24),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Su İçildi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryText)),
                                Text(kaydi.saat, style: const TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const Spacer(),
                            Text('+${kaydi.miktar} ml', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: accentColor)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(Color secondaryText) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.opacity_rounded, size: 80, color: secondaryText.withOpacity(0.1)),
          const SizedBox(height: 16),
          Text(
            'Henüz su içmedin.\nBugünün ilk bardağını içmeye ne dersin? 💧',
            textAlign: TextAlign.center,
            style: TextStyle(color: secondaryText, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
