import 'package:flutter/foundation.dart' show kIsWeb;
import 'database/db_mobile.dart' if (dart.library.html) 'database/db_web.dart';

abstract class DatabaseHelper {
  static DatabaseHelper get instance => getDatabaseHelper();
  
  Future<void> initialize();
  dynamic get database;
}

DatabaseHelper getDatabaseHelper() {
  if (kIsWeb) {
    return WebDatabaseHelper.instance;
  } else {
    return MobileDatabaseHelper.instance;
  }
}