import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/app_drawer.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _showChart = false;

  @override
  Widget build(BuildContext context) {
    var userProvider = context.watch<UserProvider>();
    var user = userProvider.currentUser;

    const primaryText = Color(0xFF0F172A);
    const secondaryText = Color(0xFF64748B);
    const accentColor = Color(0xFF0EA5E9);
    const scaffoldBg = Color(0xFFF8FAFC);
    const successColor = Color(0xFF10B981);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Geçmiş', style: TextStyle(color: primaryText))),
        drawer: const AppDrawer(),
        body: const Center(child: Text('Kullanıcı bulunamadı.')),
      );
    }

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: const Text('Geçmiş Kayıtlar', style: TextStyle(fontWeight: FontWeight.w900, color: primaryText, letterSpacing: -0.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: primaryText),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _showChart ? Icons.list_alt_rounded : Icons.bar_chart_rounded,
              color: accentColor,
              size: 28,
            ),
            onPressed: () {
              setState(() {
                _showChart = !_showChart;
              });
            },
          )
        ],
      ),
      drawer: const AppDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.firebaseId)
            .collection('gunler')
            .orderBy('tarih', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: accentColor));
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Veriler yüklenirken bir hata oluştu.', style: TextStyle(color: secondaryText)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 80, color: secondaryText.withOpacity(0.2)),
                  const SizedBox(height: 16),
                  const Text(
                    'Henüz geçmiş veri bulunmuyor.\nSu içtikçe burada listelenecek! 💧',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryText, fontSize: 16, height: 1.5, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return Column(
            children: [
              if (_showChart) _buildChartView(docs, accentColor, successColor, primaryText, secondaryText),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final dateString = data['tarih'] as String? ?? '';
              final currentIntake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
              final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
              final isHit = currentIntake >= goal;

              DateTime? date;
              try { date = DateTime.parse(dateString); } catch (_) {}

              String displayDate = dateString;
              if (date != null) {
                List<String> months = ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"];
                List<String> days = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];
                displayDate = "${date.day} ${months[date.month - 1]} ${date.year}, ${days[date.weekday - 1]}";
              }

              double progress = goal > 0 ? (currentIntake / goal).clamp(0.0, 1.0) : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [BoxShadow(color: Color(0x33E2E8F0), blurRadius: 24, offset: Offset(0, 10))],
                  border: Border.all(
                    color: isHit ? successColor.withOpacity(0.3) : const Color(0xFFF1F5F9),
                    width: isHit ? 2 : 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isHit ? successColor.withOpacity(0.1) : const Color(0xFFF0F9FF),
                            ),
                          ),
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.transparent,
                              color: isHit ? successColor : accentColor,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                          Icon(
                            isHit ? Icons.done_all_rounded : Icons.water_drop_rounded,
                            color: isHit ? successColor : accentColor,
                            size: 28,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: secondaryText),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '$currentIntake',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: isHit ? successColor : primaryText,
                                  letterSpacing: -1,
                                ),
                              ),
                              Text(
                                ' / $goal ml',
                                style: const TextStyle(fontSize: 15, color: secondaryText, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isHit)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: successColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.star_rounded, color: successColor, size: 24),
                      )
                  ],
                ),
              );
            },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChartView(List<QueryDocumentSnapshot> docs, Color accentColor, Color successColor, Color primaryText, Color secondaryText) {
    if (docs.isEmpty) return const SizedBox.shrink();

    // Veri en yeniden eskiye sıralı. Grafikte soldan sağa = eskiden yeniye yapmak için listeyi tersine çevirelim.
    final reversedDocs = docs.reversed.toList();

    // Yükseklik hesaplaması için maksimum miktarı bulalım
    int maxIntake = 2000;
    for (var doc in reversedDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
      if (intake > maxIntake) maxIntake = intake;
    }

    return Container(
      height: 240,
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('Günlük Tüketim Grafiği', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryText, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: reversedDocs.length,
              // Son elemana kaydırılmış başlamak için (en yeni gün sağda)
              // Normal padding ve physics yetecektir. İleride scrollController eklenebilir.
              itemBuilder: (context, index) {
                final data = reversedDocs[index].data() as Map<String, dynamic>;
                final dateString = data['tarih'] as String? ?? '';
                final intake = (data['gunlukMiktar'] as num?)?.toInt() ?? 0;
                final goal = (data['hedef'] as num?)?.toInt() ?? 2000;
                final isHit = intake >= goal;

                DateTime? date;
                try { date = DateTime.parse(dateString); } catch (_) {}
                String dayFormat = date != null ? "${date.day}/${date.month}" : "";

                // Oran hesabı (max yüksekliğe göre 0.0 - 1.0 arası)
                double ratio = maxIntake > 0 ? (intake / maxIntake).clamp(0.0, 1.0) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '$intake',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: isHit ? successColor : accentColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Bar (Çubuk) Kısmı
                      Container(
                        height: 100, // Bar'ın alabileceği maksimum sabit yükseklik
                        width: 40,
                        alignment: Alignment.bottomCenter,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: FractionallySizedBox(
                          heightFactor: ratio,
                          child: Container(
                            width: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isHit 
                                  ? [successColor, successColor.withOpacity(0.7)]
                                  : [accentColor, accentColor.withOpacity(0.7)],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: (isHit ? successColor : accentColor).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        dayFormat,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: secondaryText),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
