import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'app.dart';
import 'database/db.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize sqflite for web
  if (kIsWeb) {
    sqfliteFfiWebInit();
  }
  
  await DatabaseHelper.instance.database;
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}