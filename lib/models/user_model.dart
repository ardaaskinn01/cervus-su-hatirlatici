import 'package:hive/hive.dart';

class UserModel {
  String displayName; 
  String firebaseId; 
  int age;
  double weight;
  String wakeUpTime;
  String sleepTime;
  int? customGoal; // 🎯 Kullanıcının belirlediği manuel hedef (Boşsa otomatik hesaplanır)
  bool isPrivacyAccepted; // 🛡️ Gizlilik politikası kabul edildi mi?

  UserModel({
    required this.displayName,
    required this.firebaseId,
    required this.age,
    required this.weight,
    required this.wakeUpTime,
    required this.sleepTime,
    this.customGoal,
    this.isPrivacyAccepted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'firebaseId': firebaseId,
      'age': age,
      'weight': weight,
      'wakeUpTime': wakeUpTime,
      'sleepTime': sleepTime,
      'customGoal': customGoal,
      'isPrivacyAccepted': isPrivacyAccepted,
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
      customGoal: reader.read() as int?,
      isPrivacyAccepted: reader.readBool(),
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
    writer.write(obj.customGoal);
    writer.writeBool(obj.isPrivacyAccepted);
  }
}
