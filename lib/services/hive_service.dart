import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  static const String boxName = 'transactions';

  static Future init() async {
    await Hive.initFlutter();
    await Hive.openBox(boxName);
  }

  static Box getBox() {
    return Hive.box(boxName);
  }
}
