enum DrinkType {
  turkishCoffee,
  coffee,
  milkCoffee,
  tea,
  icedTea,
  fruitJuice,
  cola,
  fruitSoda,
  lemonade,
}

class DrinkEntry {
  final String uid;
  final DrinkType drinkType;
  final int ml;
  final String saat;
  final double caffeineAmount;
  final double sugarAmount;

  DrinkEntry({
    required this.uid,
    required this.drinkType,
    required this.ml,
    required this.saat,
    required this.caffeineAmount,
    required this.sugarAmount,
  });

  static const Map<DrinkType, Map<String, double>> nutritionPer100ml = {
    DrinkType.turkishCoffee: {'kafein': 72.0, 'seker': 0.0},
    DrinkType.coffee: {'kafein': 45.0, 'seker': 0.0},
    DrinkType.milkCoffee: {'kafein': 30.0, 'seker': 5.0},
    DrinkType.tea: {'kafein': 30.0, 'seker': 0.0},
    DrinkType.icedTea: {'kafein': 22.0, 'seker': 8.0},
    DrinkType.fruitJuice: {'kafein': 0.0, 'seker': 10.0},
    DrinkType.cola: {'kafein': 10.0, 'seker': 11.0},
    DrinkType.fruitSoda: {'kafein': 0.0, 'seker': 10.0},
    DrinkType.lemonade: {'kafein': 0.0, 'seker': 9.0},
  };

  factory DrinkEntry.fromDrinkType(DrinkType type, int ml, {double extraSugarG = 0}) {
    final now = DateTime.now();
    final uid = now.millisecondsSinceEpoch.toString();
    final saat = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final nutrition = nutritionPer100ml[type]!;
    final baseCaffeine = nutrition['kafein']!;
    final baseSugar = nutrition['seker']!;

    final calculatedCaffeine = (baseCaffeine * ml) / 100.0;
    final calculatedSugar = ((baseSugar * ml) / 100.0) + extraSugarG;

    return DrinkEntry(
      uid: uid,
      drinkType: type,
      ml: ml,
      saat: saat,
      caffeineAmount: calculatedCaffeine,
      sugarAmount: calculatedSugar,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'drinkType': drinkType.name,
      'ml': ml,
      'saat': saat,
      'caffeineAmount': caffeineAmount,
      'sugarAmount': sugarAmount,
    };
  }

  factory DrinkEntry.fromMap(Map<String, dynamic> map) {
    return DrinkEntry(
      uid: map['uid'] as String? ?? "${map['saat']}_${map['ml']}",
      drinkType: DrinkType.values.firstWhere(
        (e) => e.name == map['drinkType'],
        orElse: () => DrinkType.tea,
      ),
      ml: (map['ml'] as num?)?.toInt() ?? 0,
      saat: map['saat'] as String? ?? '',
      caffeineAmount: (map['caffeineAmount'] as num?)?.toDouble() ?? 0.0,
      sugarAmount: (map['sugarAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
