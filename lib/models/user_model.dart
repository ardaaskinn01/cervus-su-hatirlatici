import 'package:hive/hive.dart';

// Hive veritabanına özel tipleri kaydetmek için manuel bir adaptör kullanıyoruz.
class UserModel {
  String displayName; // Ekranda görünecek saf adımız (Örn: arda)
  String firebaseId; // Firebase döküman adı (Örn: arda2)
  int age;
  double weight;
  String wakeUpTime;
  String sleepTime;

  UserModel({
    required this.displayName,
    required this.firebaseId,
    required this.age,
    required this.weight,
    required this.wakeUpTime,
    required this.sleepTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'firebaseId': firebaseId,
      'age': age,
      'weight': weight,
      'wakeUpTime': wakeUpTime,
      'sleepTime': sleepTime,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }
}

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 0;

  @override
  UserModel read(BinaryReader reader) {
    return UserModel(
      displayName: reader.readString(),
      firebaseId: reader.readString(),
      age: reader.readInt(),
      weight: reader.readDouble(),
      wakeUpTime: reader.readString(),
      sleepTime: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer.writeString(obj.displayName);
    writer.writeString(obj.firebaseId);
    writer.writeInt(obj.age);
    writer.writeDouble(obj.weight);
    writer.writeString(obj.wakeUpTime);
    writer.writeString(obj.sleepTime);
  }
}
