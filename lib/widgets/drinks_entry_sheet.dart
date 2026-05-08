import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../models/drink_model.dart';
import '../providers/drink_provider.dart';

class DrinksEntrySheet extends StatefulWidget {
  final DrinkType preselectedType;
  
  const DrinksEntrySheet({
    super.key,
    required this.preselectedType,
  });

  @override
  State<DrinksEntrySheet> createState() => _DrinksEntrySheetState();
}

class _DrinksEntrySheetState extends State<DrinksEntrySheet> {
  int? _selectedMl;
  double _extraSugarG = 0;

  final TextEditingController _customMlController = TextEditingController();
  static const primaryOrange = Color(0xFFE8590C);

  @override
  void initState() {
    super.initState();
    if (widget.preselectedType == DrinkType.turkishCoffee) _selectedMl = 90;
    if (widget.preselectedType == DrinkType.tea) _selectedMl = 125;
    if (widget.preselectedType == DrinkType.fruitSoda) _selectedMl = 200;
  }

  @override
  void dispose() {
    _customMlController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getAllDrinksInfo(LocaleProvider lp) {
    return [
      {'type': DrinkType.turkishCoffee, 'name': lp.translate('drink_type_turkishCoffee')},
      {'type': DrinkType.coffee, 'name': lp.translate('drink_type_coffee')},
      {'type': DrinkType.milkCoffee, 'name': lp.translate('drink_type_milkCoffee')},
      {'type': DrinkType.tea, 'name': lp.translate('drink_type_tea')},
      {'type': DrinkType.icedTea, 'name': lp.translate('drink_type_icedTea')},
      {'type': DrinkType.fruitJuice, 'name': lp.translate('drink_type_fruitJuice')},
      {'type': DrinkType.cola, 'name': lp.translate('drink_type_cola')},
      {'type': DrinkType.fruitSoda, 'name': lp.translate('drink_type_fruitSoda')},
      {'type': DrinkType.lemonade, 'name': lp.translate('drink_type_lemonade')},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DrinkProvider>();
    final lp = context.watch<LocaleProvider>();
    final drinksInfo = _getAllDrinksInfo(lp);
    
    final drinkInfo = drinksInfo.firstWhere((e) => e['type'] == widget.preselectedType, orElse: () => drinksInfo.first);
    String drinkName = drinkInfo['name'];

    int currentMl = _selectedMl ?? (int.tryParse(_customMlController.text) ?? 0);
    double previewCaff = 0;
    double previewSug = 0;

    if (currentMl > 0) {
      final dummy = DrinkEntry.fromDrinkType(widget.preselectedType, currentMl, extraSugarG: _extraSugarG);
      previewCaff = dummy.caffeineAmount;
      previewSug = dummy.sugarAmount;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFDFCFB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 40, spreadRadius: 0, offset: Offset(0, -10)),
        ],
      ),
      padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 40),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(child: Container(width: 48, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 28),
            
            // Modern Limits Header
            _buildLimitsHeader(dp, lp),
            const SizedBox(height: 32),

            Center(
              child: Text(drinkName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), letterSpacing: -0.5)),
            ),
            const SizedBox(height: 28),
            
            _buildOptionsForType(widget.preselectedType, lp),
            const SizedBox(height: 32),
            
            // Preview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFF1F5F9)),
                boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 20, offset: Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Text(lp.translate('drink_day_summary').toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey.shade400, letterSpacing: 1.5)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _previewItem(Icons.coffee_rounded, "~${previewCaff.toStringAsFixed(0)} mg", primaryOrange),
                      Container(width: 1, height: 32, color: const Color(0xFFF1F5F9)),
                      _previewItem(Icons.cake_rounded, "~${previewSug.toStringAsFixed(1)} g", Colors.amber.shade700),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: (currentMl > 0) ? () {
                final entry = DrinkEntry.fromDrinkType(widget.preselectedType, currentMl, extraSugarG: _extraSugarG);
                dp.addDrink(entry);
                Navigator.pop(context);
              } : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryOrange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: primaryOrange.withValues(alpha: 0.3),
                padding: const EdgeInsets.symmetric(vertical: 20),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(lp.translate('drink_add'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitsHeader(DrinkProvider dp, LocaleProvider lp) {
    double cafPercent = (dp.dailyCaffeine / DrinkProvider.caffeineLimit).clamp(0.0, 1.0);
    double sugPercent = (dp.dailySugar / DrinkProvider.sugarLimit).clamp(0.0, 1.0);

    return Row(
      children: [
        _limitIndicator(
          label: lp.translate('drink_caffeine'),
          current: dp.dailyCaffeine,
          max: DrinkProvider.caffeineLimit,
          unit: "mg",
          percent: cafPercent,
          color: primaryOrange,
          icon: Icons.coffee_rounded,
        ),
        const SizedBox(width: 16),
        _limitIndicator(
          label: lp.translate('drink_sugar'),
          current: dp.dailySugar,
          max: DrinkProvider.sugarLimit,
          unit: "g",
          percent: sugPercent,
          color: Colors.amber.shade700,
          icon: Icons.cake_rounded,
        ),
      ],
    );
  }

  Widget _limitIndicator({
    required String label, 
    required double current, 
    required double max, 
    required String unit, 
    required double percent, 
    required Color color, 
    required IconData icon
  }) {
    bool isWarning = percent >= 0.8;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.8))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "${current.toStringAsFixed(unit == 'g' ? 1 : 0)} / ${max.toInt()} $unit",
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 8),
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percent,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isWarning ? [Colors.red.shade400, Colors.red.shade700] : [color.withValues(alpha: 0.7), color],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          if (percent > 0.1) BoxShadow(color: (isWarning ? Colors.red : color).withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _previewItem(IconData icon, String val, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A))),
      ],
    );
  }

  Widget _buildOptionsForType(DrinkType type, LocaleProvider lp) {
    if (type == DrinkType.turkishCoffee) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${lp.translate('prof_label_daily_goal').split(' ')[0]}: 90ml (${lp.translate('stats_status_stable')})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          Text(lp.translate('drink_sugar'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sugarChip(lp.translate('drink_sugar_sade'), 0, _extraSugarG == 0),
              _sugarChip(lp.translate('drink_sugar_orta'), 4, _extraSugarG == 4),
              _sugarChip(lp.translate('drink_sugar_sekerli'), 8, _extraSugarG == 8),
            ],
          )
        ],
      );
    } 
    else if (type == DrinkType.tea) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${lp.translate('prof_label_daily_goal').split(' ')[0]}: 125ml (${lp.translate('stats_status_stable')})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          Text(lp.translate('drink_sugar'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sugarChip("0", 0, _extraSugarG == 0),
              _sugarChip("1", 4, _extraSugarG == 4),
              _sugarChip("2", 8, _extraSugarG == 8),
              _sugarChip("3", 12, _extraSugarG == 12),
            ],
          )
        ],
      );
    }
    else if (type == DrinkType.fruitSoda) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text("${lp.translate('prof_label_daily_goal').split(' ')[0]}: 200ml (${lp.translate('stats_status_stable')})\n${lp.translate('stats_status_waiting')}", textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      );
    }
    else {
      List<int> mlOptions = [];
      if (type == DrinkType.coffee) {
        mlOptions = [150, 225, 300];
      } else if (type == DrinkType.milkCoffee) {
        mlOptions = [200, 275, 350];
      } else if (type == DrinkType.icedTea || type == DrinkType.fruitJuice || type == DrinkType.cola) {
        mlOptions = [200, 250, 330];
      } else if (type == DrinkType.lemonade) {
        mlOptions = [150, 200, 250];
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lp.translate('drink_select_amount'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ...mlOptions.map((ml) => _mlChip("$ml ml", ml, _selectedMl == ml)),
              _mlChip(lp.translate('drink_custom_ml'), -1, _selectedMl == -1),
            ],
          ),
          if (_selectedMl == -1) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customMlController,
              keyboardType: TextInputType.number,
              autofocus: true,
              onChanged: (val) {
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: lp.translate('home_dialog_custom'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixText: "ml",
              ),
            ),
          ]
        ],
      );
    }
  }

  Widget _sugarChip(String label, double val, bool isSelected) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: ChoiceChip(
          label: Center(child: Text(label)),
          selected: isSelected,
          onSelected: (s) {
            if (s) setState(() => _extraSugarG = val);
          },
          selectedColor: primaryOrange,
          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
        ),
      ),
    );
  }

  Widget _mlChip(String label, int val, bool isSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (s) {
        if (s) {
          setState(() {
            _selectedMl = val;
            if (val != -1) _customMlController.clear();
          });
        }
      },
      selectedColor: primaryOrange,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }
}

