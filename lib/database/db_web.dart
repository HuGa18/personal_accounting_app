class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  
  DatabaseHelper._internal();

  Future<void> initialize() async {
    // Web platform - no SQLite support
  }

  dynamic get database => null;
}
